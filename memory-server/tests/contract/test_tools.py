"""Contract tests for all four MCP tools.

Tests are written against the tool function interfaces directly (not over MCP transport)
to keep them fast and runnable without a running MCP server.

These tests use the fake_embedder fixture from conftest.py — no live Ollama required.
"""
from __future__ import annotations

import uuid
import pytest
from pathlib import Path
from unittest.mock import patch, MagicMock

from speckit_memory.server import (
    memory_recall,
    memory_store,
    memory_sync,
    memory_delete,
)


# ---------------------------------------------------------------------------
# memory_recall contract tests (T012)
# ---------------------------------------------------------------------------

class TestMemoryRecall:
    def test_recall_returns_ranked_results(self, tmp_index, fake_embedder):
        """memory_recall returns ranked results list with correct shape."""
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            seed_chunks(tmp_index, fake_embedder, count=3)
            result = memory_recall(query="panel composition")
        assert "results" in result
        assert "total" in result
        assert isinstance(result["results"], list)

    def test_recall_empty_on_no_match(self, tmp_index, fake_embedder):
        """Returns empty results (not an error) when no match meets min_score."""
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            # Use high min_score with a fake embedder that returns all-zeros
            result = memory_recall(query="irrelevant", min_score=0.999)
        assert result["results"] == []
        assert result["total"] == 0

    def test_recall_filter_type_narrows_results(self, tmp_index, fake_embedder):
        """Metadata filter {type: 'adr'} returns only adr chunks."""
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            seed_chunks(tmp_index, fake_embedder, count=2, chunk_type="adr")
            seed_chunks(tmp_index, fake_embedder, count=2, chunk_type="log", idx_start=2)
            result = memory_recall(query="anything", filters={"type": "adr"}, min_score=0.0)
        types = {r["type"] for r in result["results"]}
        assert types == {"adr"}

    def test_recall_below_threshold_returns_empty(self, tmp_index, fake_embedder):
        """Empty index returns empty results regardless of min_score."""
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            # No chunks seeded — any query should return empty
            result = memory_recall(query="test", min_score=0.5)
        assert result["results"] == []
        assert result["total"] == 0

    def test_recall_near_duplicate_chunks_from_different_files_both_stored(self, tmp_index, fake_embedder):
        """Near-duplicate chunks from different files are both retrievable."""
        from speckit_memory.index import init_table, insert_chunks_batch
        table = init_table(tmp_index)
        for i, src in enumerate(["file_a.md", "file_b.md"]):
            insert_chunks_batch(table, [{
                "id": str(uuid.uuid4()),
                "content": "Nearly identical content about panel composition.",
                "vector": fake_embedder("panel composition"),
                "source_file": src,
                "section": "Intro",
                "type": "adr",
                "feature": "001",
                "date": "2026-04-07",
                "tags": [],
                "synthetic": False,
            }])
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            result = memory_recall(query="panel composition", top_k=10, min_score=0.0)
        source_files = {r["source_file"] for r in result["results"]}
        assert "file_a.md" in source_files
        assert "file_b.md" in source_files

    # --- US2: Caller-Controlled Token Budget ---

    def test_recall_max_chars_caps_total_content(self, tmp_index, fake_embedder):
        """T007: memory_recall with max_chars=100 returns total content ≤ 100 chars and budget_exhausted."""
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            # Seed chunks with content larger than max_chars
            seed_chunks(tmp_index, fake_embedder, count=5)
            result = memory_recall(query="content", max_chars=100, min_score=0.0)
        assert "budget_exhausted" in result
        total = sum(len(r["content"]) for r in result["results"])
        assert total <= 100

    def test_recall_max_chars_smaller_than_single_chunk_truncates(self, tmp_index, fake_embedder):
        """T008: max_chars smaller than the single highest-ranked chunk truncates with truncated: true."""
        from speckit_memory.index import init_table, insert_chunks_batch
        table = init_table(tmp_index)
        content = "X" * 500  # 500 chars
        insert_chunks_batch(table, [{
            "id": str(uuid.uuid4()),
            "content": content,
            "vector": fake_embedder("query text"),
            "source_file": "file_a.md",
            "section": "S",
            "type": "adr",
            "feature": "001",
            "date": "2026-04-07",
            "tags": [],
            "synthetic": False,
        }])
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            result = memory_recall(query="query text", max_chars=50, min_score=0.0)
        assert len(result["results"]) == 1
        assert len(result["results"][0]["content"]) <= 50
        assert result["results"][0].get("truncated") is True
        assert result.get("budget_exhausted") is True

    def test_recall_without_max_chars_returns_token_estimate(self, tmp_index, fake_embedder):
        """T009: memory_recall without max_chars returns token_estimate as positive int, no budget_exhausted."""
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            seed_chunks(tmp_index, fake_embedder, count=3)
            result = memory_recall(query="content", min_score=0.0)
        assert "token_estimate" in result
        assert isinstance(result["token_estimate"], int)
        assert result["token_estimate"] > 0
        assert "budget_exhausted" not in result

    def test_recall_max_chars_zero_returns_invalid_input(self, tmp_index, fake_embedder):
        """T010: memory_recall with max_chars=0 returns INVALID_INPUT error."""
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            result = memory_recall(query="anything", max_chars=0)
        assert "error" in result
        assert result["error"]["code"] == "INVALID_INPUT"

    def test_recall_max_chars_large_enough_returns_all_chunks(self, tmp_index, fake_embedder):
        """T011: max_chars large enough returns budget_exhausted: false and all chunks."""
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            seed_chunks(tmp_index, fake_embedder, count=3)
            result = memory_recall(query="content", max_chars=100_000, min_score=0.0)
        assert result.get("budget_exhausted") is False
        assert result["total"] == 3

    def test_recall_stop_at_first_overflow(self, tmp_index, fake_embedder):
        """T011b: Stop-at-first-overflow semantics — chunk B overflows, chunk C (smaller) is never considered."""
        from speckit_memory.index import init_table, insert_chunks_batch
        table = init_table(tmp_index)
        query = "architecture decisions"
        # A: score=high (identical to query), 200 chars
        # B: score=mid, 500 chars (overflows max_chars=250)
        # C: score=low, 50 chars (small, but never reached after B overflows)
        insert_chunks_batch(table, [
            {
                "id": str(uuid.uuid4()),
                "content": "A" * 200,
                "vector": fake_embedder(query),          # highest score
                "source_file": "a.md",
                "section": "A",
                "type": "adr",
                "feature": "001",
                "date": "2026-04-07",
                "tags": [],
                "synthetic": False,
            },
            {
                "id": str(uuid.uuid4()),
                "content": "B" * 500,
                "vector": fake_embedder("somewhat related"),  # mid score
                "source_file": "b.md",
                "section": "B",
                "type": "adr",
                "feature": "001",
                "date": "2026-04-07",
                "tags": [],
                "synthetic": False,
            },
            {
                "id": str(uuid.uuid4()),
                "content": "C" * 50,
                "vector": fake_embedder("unrelated xyz abc"),  # lowest score
                "source_file": "c.md",
                "section": "C",
                "type": "adr",
                "feature": "001",
                "date": "2026-04-07",
                "tags": [],
                "synthetic": False,
            },
        ])
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            result = memory_recall(query=query, max_chars=250, min_score=0.0)
        source_files = [r["source_file"] for r in result["results"]]
        assert "a.md" in source_files, "chunk A (200 chars) must be included"
        assert "b.md" not in source_files, "chunk B (500 chars) must overflow and stop"
        assert "c.md" not in source_files, "chunk C must be skipped (stop after first overflow)"
        assert result.get("budget_exhausted") is True

    def test_recall_results_sorted_by_score_descending(self, tmp_index, fake_embedder):
        """Results are ordered by score descending (highest similarity first)."""
        from speckit_memory.index import init_table, insert_chunks_batch
        table = init_table(tmp_index)
        query_text = "vector search score ranking"
        # Chunk A: embedded with the same text as the query → highest cosine similarity.
        # Chunk B: embedded with unrelated text → lower cosine similarity.
        # The hash-based fake_embedder produces distinct unit vectors per unique input,
        # so A should score higher than B when queried with query_text.
        insert_chunks_batch(table, [
            {
                "id": str(uuid.uuid4()),
                "content": "High-similarity chunk.",
                "vector": fake_embedder(query_text),
                "source_file": "high.md",
                "section": "S",
                "type": "adr",
                "feature": "001",
                "date": "2026-04-07",
                "tags": [],
                "synthetic": False,
            },
            {
                "id": str(uuid.uuid4()),
                "content": "Low-similarity chunk.",
                "vector": fake_embedder("completely unrelated content xyz"),
                "source_file": "low.md",
                "section": "S",
                "type": "adr",
                "feature": "001",
                "date": "2026-04-07",
                "tags": [],
                "synthetic": False,
            },
        ])
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            result = memory_recall(query=query_text, top_k=10, min_score=0.0)
        scores = [r["score"] for r in result["results"]]
        assert scores == sorted(scores, reverse=True), f"Results not sorted descending: {scores}"
        # The identical-embedding chunk must outscore the unrelated chunk.
        source_order = [r["source_file"] for r in result["results"]]
        assert source_order[0] == "high.md", f"Expected high.md first, got {source_order}"


# ---------------------------------------------------------------------------
# memory_store contract tests (T027) — US3
# ---------------------------------------------------------------------------

class TestMemoryStore:
    def test_store_returns_id_and_stored_status(self, tmp_index, fake_embedder):
        """memory_store returns {id, status: 'stored'}."""
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            result = memory_store(
                content="A test summary.",
                metadata={
                    "source_file": "synthetic",
                    "section": "Summary",
                    "type": "synthetic",
                    "feature": "002",
                    "date": "2026-04-07",
                    "tags": [],
                },
            )
        assert result["status"] == "stored"
        assert "id" in result
        # UUID format check
        uuid.UUID(result["id"])

    def test_store_nonexistent_source_sets_synthetic_flag(self, tmp_index, fake_embedder, tmp_path):
        """T002: memory_store with non-synthetic source_file is rejected with INVALID_SOURCE_FILE."""
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            result = memory_store(
                content="Synthetic content.",
                metadata={
                    "source_file": "nonexistent/file.md",
                    "section": "Summary",
                    "type": "synthetic",
                    "feature": "002",
                    "date": "2026-04-07",
                    "tags": [],
                },
            )
        assert "error" in result, f"Expected error, got: {result}"
        assert result["error"]["code"] == "INVALID_SOURCE_FILE"

    def test_store_rejects_non_synthetic_source_file(self, tmp_index, fake_embedder):
        """T001: memory_store with source_file != 'synthetic' returns INVALID_SOURCE_FILE error."""
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            result = memory_store(
                content="A test summary.",
                metadata={
                    "source_file": "nonexistent/file.md",
                    "section": "Summary",
                    "type": "synthetic",
                    "feature": "002",
                    "date": "2026-04-07",
                    "tags": [],
                },
            )
        assert "error" in result
        assert result["error"]["code"] == "INVALID_SOURCE_FILE"

    def test_stored_chunk_is_queryable(self, tmp_index, fake_embedder):
        """A stored chunk is retrievable in the same session."""
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            store_result = memory_store(
                content="Unique synthetic content for recall test.",
                metadata={
                    "source_file": "synthetic",
                    "section": "Recall test",
                    "type": "synthetic",
                    "feature": "002",
                    "date": "2026-04-07",
                    "tags": [],
                },
            )
            recall_result = memory_recall(query="synthetic content", min_score=0.0, top_k=10)
        ids = [r["id"] for r in recall_result["results"]]
        assert store_result["id"] in ids


# ---------------------------------------------------------------------------
# memory_delete contract tests (T028) — US3
# ---------------------------------------------------------------------------

class TestMemoryDelete:
    def test_delete_by_source_file_removes_all_chunks(self, tmp_index, fake_embedder):
        """Delete by source_file removes all chunks for that file."""
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            seed_chunks(tmp_index, fake_embedder, count=3, source_file="remove_me.md")
            result = memory_delete(source_file="remove_me.md")
        assert result["deleted_chunks"] == 3
        assert result["source_file"] == "remove_me.md"

    def test_delete_by_id_removes_exactly_one(self, tmp_index, fake_embedder):
        """Delete by id removes exactly one chunk."""
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            store_r = memory_store(
                content="Chunk to delete by id.",
                metadata={
                    "source_file": "synthetic",
                    "section": "Test",
                    "type": "synthetic",
                    "feature": "002",
                    "date": "2026-04-07",
                    "tags": [],
                },
            )
            result = memory_delete(id=store_r["id"])
        assert result["deleted_chunks"] == 1

    def test_delete_protected_source_file_returns_error(self, tmp_index, fake_embedder, tmp_path):
        """T003: memory_delete with source_file pointing to existing file returns PROTECTED_SOURCE_FILE."""
        real_file = tmp_path / "real_file.md"
        real_file.write_text("# Real file")
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            with patch("speckit_memory.server._repo_root", return_value=tmp_path):
                result = memory_delete(source_file="real_file.md")
        assert "error" in result
        assert result["error"]["code"] == "PROTECTED_SOURCE_FILE"

    def test_delete_nonexistent_source_file_proceeds(self, tmp_index, fake_embedder, tmp_path):
        """T004: memory_delete with source_file of a deleted path proceeds with deleted_chunks: 0."""
        ephemeral = tmp_path / "gone.md"
        ephemeral.write_text("temp")
        ephemeral.unlink()
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            with patch("speckit_memory.server._repo_root", return_value=tmp_path):
                result = memory_delete(source_file="gone.md")
        assert "error" not in result
        assert result["deleted_chunks"] == 0

    def test_delete_both_or_neither_returns_invalid_input(self, tmp_index, fake_embedder):
        """Providing both source_file and id, or neither, returns INVALID_INPUT."""
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            r_both = memory_delete(source_file="foo.md", id="some-uuid")
            r_none = memory_delete()
        assert r_both["error"]["code"] == "INVALID_INPUT"
        assert r_none["error"]["code"] == "INVALID_INPUT"

    def test_delete_missing_file_returns_zero(self, tmp_index, fake_embedder):
        """Deleting a file with no indexed chunks returns deleted_chunks: 0."""
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            result = memory_delete(source_file="nonexistent.md")
        assert result["deleted_chunks"] == 0


# ---------------------------------------------------------------------------
# memory_sync contract tests (T020) — US2
# ---------------------------------------------------------------------------

class TestMemorySyncContract:
    def test_sync_returns_stats_envelope(self, tmp_index, fake_embedder):
        """memory_sync returns {indexed, skipped, deleted, duration_ms, model}."""
        with patched_embed(fake_embedder), patched_index_dir(tmp_index), patched_crawl([]):
            result = memory_sync()
        for key in ["indexed", "skipped", "deleted", "duration_ms", "model"]:
            assert key in result, f"Missing key: {key}"

    def test_sync_model_mismatch_error_format(self, tmp_index, fake_embedder):
        """MODEL_MISMATCH error includes code and recoverable=false."""
        from speckit_memory.index import load_manifest, save_manifest
        manifest = load_manifest(tmp_index)
        manifest["embedding_model"] = "different-model"
        manifest["embedding_dimension"] = 768
        save_manifest(tmp_index, manifest)
        with patched_embed(fake_embedder), patched_index_dir(tmp_index), patched_crawl([]):
            result = memory_sync()
        assert "error" in result
        assert result["error"]["code"] == "MODEL_MISMATCH"
        assert result["error"]["recoverable"] is False

    def test_sync_paths_limits_crawl_to_specified_files(self, tmp_index, fake_embedder, tmp_path):
        """memory_sync with paths= restricts crawl to the listed files only."""
        # Create two real markdown files in a temp repo dir.
        repo = tmp_path / "repo"
        repo.mkdir()
        (repo / "included.md").write_text("# Included\n\nThis file should be indexed.")
        (repo / "excluded.md").write_text("# Excluded\n\nThis file should be skipped.")

        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            with patch("speckit_memory.server._repo_root", return_value=repo):
                result = memory_sync(paths=[str(repo / "included.md")])

        # Only the included file should be processed; excluded.md should not appear.
        assert "error" not in result, f"Unexpected error: {result}"
        assert result["indexed"] + result["skipped"] <= 1, (
            f"Expected ≤1 file processed, got indexed={result['indexed']} skipped={result['skipped']}"
        )


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

from contextlib import contextmanager


@contextmanager
def patched_embed(fake_embedder):
    with patch("speckit_memory.server._embed_text", side_effect=lambda t: fake_embedder(t)):
        yield


@contextmanager
def patched_index_dir(tmp_index):
    with patch("speckit_memory.server._index_dir", return_value=tmp_index):
        yield


@contextmanager
def patched_crawl(file_list):
    with patch("speckit_memory.server._crawl_files", return_value=file_list):
        yield


def seed_chunks(index_dir, fake_embedder, count=3, chunk_type="adr",
                source_file=None, idx_start=0):
    from speckit_memory.index import init_table, insert_chunks_batch
    table = init_table(index_dir)
    chunks = []
    for i in range(idx_start, idx_start + count):
        sf = source_file or f"file_{i}.md"
        chunks.append({
            "id": str(uuid.uuid4()),
            "content": f"Content block {i} with enough text for recall testing purposes.",
            "vector": fake_embedder(f"content {i}"),
            "source_file": sf,
            "section": f"Section {i}",
            "type": chunk_type,
            "feature": "001",
            "date": "2026-04-07",
            "tags": [],
            "synthetic": False,
        })
    insert_chunks_batch(table, chunks)


@pytest.fixture
def tmp_index(tmp_path):
    index_dir = tmp_path / ".index"
    index_dir.mkdir()
    return index_dir
