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
    # Write a manifest that records a different model
    manifest = {
        "version": "1",
        "embedding_model": "old-model-name",
        "embedding_dimension": 768,
        "similarity_metric": "cosine",
        "entries": {"some_file.md": {"mtime": "2026-01-01T00:00:00+00:00", "chunk_ids": []}},
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
def test_api_unavailable_returns_recoverable_error(tmp_repo, tmp_index):
    """When Ollama HTTP is unreachable, API_UNAVAILABLE error with recoverable=True."""
    from speckit_memory import server as srv

    def bad_embed(text: str) -> list[float]:
        raise ConnectionRefusedError("Connection refused")

    with patch("speckit_memory.server._embed_text", side_effect=bad_embed), \
         patch("speckit_memory.server._index_dir", return_value=tmp_index), \
         patch("speckit_memory.server._first_call_done", True):
        result = srv.memory_sync()

    assert "error" in result
    assert result["error"]["code"] == "API_UNAVAILABLE"
    assert result["error"]["recoverable"] is True


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
