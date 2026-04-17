"""Integration tests for fault scenarios.

These tests do NOT require Ollama — they test error paths with controlled conditions.
Marked @pytest.mark.integration because they manipulate filesystem state
(manifest/DB presence) and may leave temp state if interrupted.
"""
import json
import pytest
from pathlib import Path
from unittest.mock import patch

from speckit_memory.index import load_manifest, save_manifest
from speckit_memory.sync import run_sync, _l2_normalize


def fake_embed(text: str) -> list[float]:
    return [0.0] * 768


@pytest.fixture
def tmp_repo(tmp_path):
    memory_dir = tmp_path / ".specify" / "memory"
    memory_dir.mkdir(parents=True)
    adr = memory_dir / "ADR_001_test.md"
    adr.write_text("# Decision\n\nWe chose something important for the system design and architecture.")
    return tmp_path


@pytest.fixture
def tmp_index(tmp_path):
    idx = tmp_path / ".index"
    idx.mkdir()
    return idx


@pytest.mark.integration
def test_model_mismatch_errors_clearly(tmp_repo, tmp_index):
    """When manifest records a different model, MODEL_MISMATCH error is returned."""
    # Write a v2 manifest that records a different model
    manifest = {
        "version": "2",
        "embedding_model": "old-model-name",
        "embedding_dimension": 768,
        "similarity_metric": "cosine",
        "entries": {"some_file.md": {"hash": "abc123", "chunk_ids": []}},
    }
    save_manifest(tmp_index, manifest)

    result = run_sync(
        index_dir=tmp_index,
        repo_root=tmp_repo,
        embed_fn=fake_embed,
        model_name="nomic-embed-text",
        full=False,
    )

    assert "error" in result
    assert result["error"]["code"] == "MODEL_MISMATCH"
    assert result["error"]["recoverable"] is False
    assert "nomic-embed-text" in result["error"]["message"] or "old-model-name" in result["error"]["message"]


@pytest.mark.integration
def test_api_unavailable_raises_tool_error(tmp_repo, tmp_index):
    """When Ollama HTTP is unreachable, memory_sync raises ToolError (ADR-033)."""
    from speckit_memory import server as srv
    from fastmcp.exceptions import ToolError

    def bad_embed(text: str) -> list[float]:
        raise ConnectionRefusedError("Connection refused")

    with patch("speckit_memory.server._embed_text", side_effect=bad_embed), \
         patch("speckit_memory.server._index_dir", return_value=tmp_index), \
         patch("speckit_memory.server._first_call_done", True):
        with pytest.raises(ToolError, match="EMBEDDING_UNAVAILABLE"):
            srv.memory_sync()


@pytest.mark.integration
def test_summary_only_returns_results_without_ollama(tmp_repo, tmp_index):
    """T011: memory_recall(summary_only=True) returns results even when Ollama is down (US1)."""
    from speckit_memory.server import memory_recall
    from speckit_memory.index import init_table, insert_chunks_batch
    import uuid

    # Seed the index directly — no Ollama needed
    table = init_table(tmp_index)
    insert_chunks_batch(table, [
        {
            "id": str(uuid.uuid4()),
            "content": "Decision about vector storage backend.",
            "vector": [0.0] * 768,
            "source_file": ".specify/memory/ADR_001_test.md",
            "section": "Decision",
            "type": "adr",
            "feature": "002",
            "date": "2026-04-14",
            "tags": [],
            "synthetic": False,
        }
    ])

    def bad_embed(text: str) -> list[float]:
        raise ConnectionError("Ollama is down")

    with patch("speckit_memory.server._embed_text", side_effect=bad_embed), \
         patch("speckit_memory.server._index_dir", return_value=tmp_index):
        result = memory_recall(query="vector storage", summary_only=True)

    assert "error" not in result, f"summary_only must not error with Ollama down: {result}"
    assert result["total"] >= 1, "Expected at least 1 result from populated index"
    for entry in result["results"]:
        assert "source_file" in entry
        assert "section" in entry
        assert "content" not in entry


@pytest.mark.integration
def test_semantic_recall_falls_back_when_ollama_down(tmp_repo, tmp_index):
    """T012 (007): memory_recall returns degraded:true on ConnectionError — no ToolError raised."""
    from speckit_memory.server import memory_recall

    def bad_embed(text: str) -> list[float]:
        raise ConnectionError("Ollama is down")

    with patch("speckit_memory.server._embed_text", side_effect=bad_embed), \
         patch("speckit_memory.server._index_dir", return_value=tmp_index), \
         patch("speckit_memory.server._first_call_done", True):
        result = memory_recall(query="test query")

    assert "error" not in result, "ConnectionError must trigger BM25 fallback, not ToolError"
    assert result.get("degraded") is True


@pytest.mark.integration
def test_memory_store_raises_tool_error_when_ollama_down(tmp_repo, tmp_index):
    """T017: memory_store with Ollama not running raises ToolError with EMBEDDING_UNAVAILABLE and Hint."""
    from speckit_memory.server import memory_store
    from fastmcp.exceptions import ToolError

    def bad_embed(text: str) -> list[float]:
        raise ConnectionError("Ollama not running")

    with patch("speckit_memory.server._embed_text", side_effect=bad_embed), \
         patch("speckit_memory.server._index_dir", return_value=tmp_index), \
         patch("speckit_memory.server._first_call_done", True):
        with pytest.raises(ToolError) as exc_info:
            memory_store(
                content="Test summary content.",
                metadata={"source_file": "synthetic", "section": "S",
                          "type": "synthetic", "feature": "006",
                          "date": "2026-04-14", "tags": []},
            )

    error_msg = str(exc_info.value)
    assert "EMBEDDING_UNAVAILABLE" in error_msg
    assert "Hint:" in error_msg


@pytest.mark.integration
def test_memory_store_raises_model_error_for_bad_model(tmp_repo, tmp_index):
    """T018: memory_store with a missing model raises ToolError with EMBEDDING_MODEL_ERROR."""
    import ollama as ollama_sdk
    from speckit_memory.server import memory_store
    from fastmcp.exceptions import ToolError

    def bad_embed(text: str) -> list[float]:
        raise ollama_sdk.ResponseError("model not found", 404)

    with patch("speckit_memory.server._embed_text", side_effect=bad_embed), \
         patch("speckit_memory.server._index_dir", return_value=tmp_index), \
         patch("speckit_memory.server._first_call_done", True):
        with pytest.raises(ToolError) as exc_info:
            memory_store(
                content="Test summary.",
                metadata={"source_file": "synthetic", "section": "S",
                          "type": "synthetic", "feature": "006",
                          "date": "2026-04-14", "tags": []},
            )

    error_msg = str(exc_info.value)
    assert "EMBEDDING_MODEL_ERROR" in error_msg


@pytest.mark.integration
def test_partial_sync_does_not_write_manifest_on_embed_failure(tmp_path):
    """T018b: manifest.json is not updated when embedding fails mid-sync (FR-007, SC-004)."""
    from speckit_memory.server import memory_sync
    from speckit_memory.index import load_manifest
    from fastmcp.exceptions import ToolError

    memory_dir = tmp_path / ".specify" / "memory"
    memory_dir.mkdir(parents=True)
    adr = memory_dir / "ADR_001_test.md"
    adr.write_text("# Decision\n\nContent that will fail to embed.")
    index_dir = tmp_path / ".index"
    index_dir.mkdir()

    def always_fails(text: str) -> list[float]:
        raise ConnectionError("Ollama down")

    with patch("speckit_memory.server._embed_text", side_effect=always_fails), \
         patch("speckit_memory.server._index_dir", return_value=index_dir), \
         patch("speckit_memory.server._repo_root", return_value=tmp_path), \
         patch("speckit_memory.server._first_call_done", True):
        with pytest.raises(ToolError):
            memory_sync()

    manifest = load_manifest(index_dir)
    rel = str(adr.relative_to(tmp_path))
    assert rel not in manifest["entries"], (
        "Manifest must not contain entries for files that failed to embed"
    )


@pytest.mark.integration
def test_manifest_without_db_triggers_full_reindex(tmp_repo, tmp_index):
    """If manifest exists but LanceDB directory is missing, full re-index is triggered."""
    # Write a manifest claiming a file is indexed
    adr_rel = ".specify/memory/ADR_001_test.md"
    manifest = {
        "version": "1",
        "embedding_model": "nomic-embed-text",
        "embedding_dimension": 768,
        "similarity_metric": "cosine",
        "entries": {
            adr_rel: {"mtime": "2020-01-01T00:00:00+00:00", "chunk_ids": ["some-uuid"]},
        },
    }
    save_manifest(tmp_index, manifest)
    # Note: chunks.lance/ does NOT exist — only manifest.json

    result = run_sync(
        index_dir=tmp_index,
        repo_root=tmp_repo,
        embed_fn=fake_embed,
        model_name="nomic-embed-text",
        full=False,
    )

    # Should have performed full re-index without error
    assert "error" not in result
    assert result["indexed"] >= 1

    # Manifest should reflect current model
    updated = load_manifest(tmp_index)
    assert updated["embedding_model"] == "nomic-embed-text"


@pytest.mark.integration
def test_empty_db_with_manifest_triggers_full_reindex(tmp_repo, tmp_index):
    """If LanceDB table exists but is empty while manifest claims files are indexed,
    run_sync must detect the divergence and force a full re-index (not return 0/22/skipped).

    This covers the deletion scenario: user deletes chunks.lance/ files but leaves the
    directory stub, or the DB is recreated fresh after a partial .index/ deletion.
    """
    from speckit_memory.index import init_table, insert_chunks_batch

    # Create a valid manifest claiming a file is indexed.
    adr_rel = ".specify/memory/ADR_001_test.md"
    import hashlib
    content = (tmp_repo / adr_rel).read_bytes()
    content_hash = hashlib.sha256(content).hexdigest()
    manifest = {
        "version": "2",
        "embedding_model": "nomic-embed-text",
        "embedding_dimension": 768,
        "similarity_metric": "cosine",
        "entries": {
            adr_rel: {"hash": content_hash, "chunk_ids": ["some-uuid"]},
        },
    }
    save_manifest(tmp_index, manifest)

    # Create an empty LanceDB table (simulates DB cleared while manifest survives).
    init_table(tmp_index)  # creates empty chunks table — 0 rows

    result = run_sync(
        index_dir=tmp_index,
        repo_root=tmp_repo,
        embed_fn=fake_embed,
        model_name="nomic-embed-text",
        full=False,
    )

    # Must not return 0 indexed, 1 skipped — that would mean the empty DB went undetected.
    assert "error" not in result
    assert result["indexed"] >= 1, (
        f"Expected ≥1 file re-indexed after DB/manifest divergence, got {result}"
    )
