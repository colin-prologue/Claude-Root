"""Integration tests for sync operations against a real LanceDB instance.

Requires Ollama running with nomic-embed-text model:
    ollama serve
    ollama pull nomic-embed-text

Run without Ollama: pytest -m "not integration"
Run integration only: pytest -m integration tests/integration/
"""
import pytest
import time
from pathlib import Path

from speckit_memory.index import init_table, load_manifest
from speckit_memory.sync import _ollama_embed, _l2_normalize, run_sync


OLLAMA_BASE_URL = "http://localhost:11434"
OLLAMA_MODEL = "nomic-embed-text"


def embed_fn(text: str) -> list[float]:
    raw = _ollama_embed(text, OLLAMA_BASE_URL, OLLAMA_MODEL)
    return _l2_normalize(raw)


@pytest.fixture
def tmp_repo(tmp_path):
    """Minimal fake repo with one ADR file."""
    memory_dir = tmp_path / ".specify" / "memory"
    memory_dir.mkdir(parents=True)
    adr = memory_dir / "ADR_001_test.md"
    adr.write_text("# Decision\n\nWe chose LanceDB as the vector backend for its daemonless architecture.\n\n# Consequences\n\nThe index is volatile and must be regenerated from source.")
    return tmp_path


@pytest.fixture
def tmp_index(tmp_path):
    idx = tmp_path / ".index"
    idx.mkdir()
    return idx


@pytest.mark.integration
def test_new_file_becomes_queryable(tmp_repo, tmp_index):
    """A new ADR file is indexed and its content is returnable by recall."""
    from speckit_memory.index import vector_search

    result = run_sync(
        index_dir=tmp_index,
        repo_root=tmp_repo,
        embed_fn=embed_fn,
        model_name=OLLAMA_MODEL,
    )
    assert result["indexed"] >= 1

    table = init_table(tmp_index)
    query_vec = embed_fn("daemonless vector backend")
    results = vector_search(table, query_vec, top_k=5, min_score=0.3)
    assert len(results) >= 1
    assert any("LanceDB" in r["content"] or "vector" in r["content"].lower() for r in results)


@pytest.mark.integration
def test_deleted_file_purges_chunks(tmp_repo, tmp_index):
    """Deleting a source file causes its chunks to be removed on next sync."""
    from speckit_memory.index import vector_search

    # First sync — index the ADR
    run_sync(tmp_index, tmp_repo, embed_fn, OLLAMA_MODEL)

    # Delete the file
    adr = tmp_repo / ".specify" / "memory" / "ADR_001_test.md"
    adr.unlink()

    # Second sync — file should be purged
    result = run_sync(tmp_index, tmp_repo, embed_fn, OLLAMA_MODEL)
    assert result["deleted"] >= 1

    table = init_table(tmp_index)
    rows = table.to_pandas()
    adr_chunks = rows[rows["source_file"].str.contains("ADR_001_test")]
    assert len(adr_chunks) == 0


@pytest.mark.integration
def test_no_headings_produces_single_chunk(tmp_repo, tmp_index):
    """A file with no headings is indexed as a single chunk."""
    flat_file = tmp_repo / ".specify" / "memory" / "ADR_002_flat.md"
    flat_file.write_text("This is a flat file with no headings. It contains important information about the system design that should be retrievable as a single chunk.")

    run_sync(tmp_index, tmp_repo, embed_fn, OLLAMA_MODEL)

    table = init_table(tmp_index)
    rows = table.to_pandas()
    flat_chunks = rows[rows["source_file"].str.contains("ADR_002_flat")]
    assert len(flat_chunks) == 1
    assert flat_chunks.iloc[0]["section"] == "ADR_002_flat"


@pytest.mark.integration
def test_unchanged_file_skipped(tmp_repo, tmp_index):
    """An unchanged file is skipped on the second sync."""
    run_sync(tmp_index, tmp_repo, embed_fn, OLLAMA_MODEL)
    result2 = run_sync(tmp_index, tmp_repo, embed_fn, OLLAMA_MODEL)
    assert result2["skipped"] >= 1
    assert result2["indexed"] == 0


@pytest.mark.integration
def test_unchanged_file_sync_under_500ms(tmp_repo, tmp_index):
    """Sync with no changed files completes in under 500ms (SC-002)."""
    run_sync(tmp_index, tmp_repo, embed_fn, OLLAMA_MODEL)
    result = run_sync(tmp_index, tmp_repo, embed_fn, OLLAMA_MODEL)
    assert result["duration_ms"] < 500, (
        f"Clean sync took {result['duration_ms']}ms, expected < 500ms"
    )
