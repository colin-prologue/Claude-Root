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

import ollama as ollama_sdk

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
        assert result.get("truncated") is True
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

    # --- US3: Summary-Only Recall and Source Filter ---

    def test_recall_summary_only_omits_content(self, tmp_index, fake_embedder):
        """T010b: memory_recall with summary_only=True returns only source_file and section; no content, no score."""
        with patched_index_dir(tmp_index):
            seed_chunks(tmp_index, fake_embedder, count=3)
            result = memory_recall(query="content", summary_only=True, min_score=0.0)
        assert result["total"] > 0
        for entry in result["results"]:
            assert "source_file" in entry
            assert "section" in entry
            assert "content" not in entry
            assert "score" not in entry

    def test_recall_summary_only_with_max_chars_budget(self, tmp_index, fake_embedder):
        """T010c: summary_only=True counts serialized entry size (FR-007), not full content chars.

        Seeds 3 chunks with 300-char content. max_chars=150. Each summary entry is
        ~53 chars (json.dumps of {source_file, section} — no score field). With
        summary-based enforcement: entry 0 (~53) + entry 1 (~53) = ~106 ≤ 150,
        entry 2 would be 159 > 150 → budget_exhausted, total=2.
        With content-based enforcement (wrong): 300 > 150 → no entries or 1 truncated.
        """
        from speckit_memory.index import init_table, insert_chunks_batch
        table = init_table(tmp_index)
        for i in range(3):
            insert_chunks_batch(table, [{
                "id": str(uuid.uuid4()),
                "content": "X" * 300,
                "vector": fake_embedder(f"block {i}"),
                "source_file": f"file_{i:02d}.md",
                "section": f"Section {i}",
                "type": "adr",
                "feature": "001",
                "date": "2026-04-07",
                "tags": [],
                "synthetic": False,
            }])
        with patched_index_dir(tmp_index):
            result = memory_recall(query="content", summary_only=True, max_chars=150, min_score=0.0)
        assert result.get("budget_exhausted") is True
        assert result["total"] == 2, (
            f"Expected 2 summary entries (~53 chars each in 150-char budget); "
            f"got {result['total']}. Budget is likely counting full content chars instead of "
            "serialized summary entry size."
        )

    def test_recall_semantic_raises_tool_error_when_ollama_down(self, tmp_index, fake_embedder):
        """T010a (007): ConnectionError triggers BM25 fallback with degraded:true — no ToolError raised."""
        def bad_embed(text):
            raise ConnectionError("refused")

        with patch("speckit_memory.server._embed_text", side_effect=bad_embed), \
             patched_index_dir(tmp_index), \
             patch("speckit_memory.server._first_call_done", True):
            seed_chunks(tmp_index, fake_embedder, count=3)
            result = memory_recall(query="test")

        assert "error" not in result, "ConnectionError must trigger BM25 fallback, not ToolError"
        assert result.get("degraded") is True
        assert isinstance(result["results"], list)

    def test_recall_filter_source_file_restricts_results(self, tmp_index, fake_embedder):
        """T017: memory_recall with filter_source_file returns only results from that file."""
        from speckit_memory.index import init_table, insert_chunks_batch
        table = init_table(tmp_index)
        for sf in ["target.md", "other.md"]:
            insert_chunks_batch(table, [{
                "id": str(uuid.uuid4()),
                "content": f"Content from {sf}",
                "vector": fake_embedder(sf),
                "source_file": sf,
                "section": "S",
                "type": "adr",
                "feature": "001",
                "date": "2026-04-07",
                "tags": [],
                "synthetic": False,
            }])
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            result = memory_recall(query="content", filter_source_file="target.md", min_score=0.0)
        sources = {r["source_file"] for r in result["results"]}
        assert sources == {"target.md"}

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
# memory_recall fallback contract tests (007 — T003–T006a)
# ---------------------------------------------------------------------------

class TestMemoryRecallFallback:
    """BM25 fallback contract tests: error routing, degraded flag, filter/budget parity."""

    # T003 — ResponseError always routes to hard ToolError (ADR-044)

    def test_recall_model_error_still_raises_tool_error(self, tmp_index, fake_embedder):
        """ResponseError status_code=404 raises EMBEDDING_MODEL_ERROR ToolError — no fallback (ADR-044)."""
        from fastmcp.exceptions import ToolError

        def bad_embed_404(text):
            exc = ollama_sdk.ResponseError("not found")
            exc.status_code = 404
            raise exc

        with patch("speckit_memory.server._embed_text", side_effect=bad_embed_404), \
             patched_index_dir(tmp_index), \
             patch("speckit_memory.server._first_call_done", True):
            with pytest.raises(ToolError, match="EMBEDDING_MODEL_ERROR"):
                memory_recall(query="test")

    def test_recall_non404_response_error_raises_tool_error(self, tmp_index, fake_embedder):
        """ResponseError status_code=500 raises ToolError — not degraded fallback (ADR-044)."""
        from fastmcp.exceptions import ToolError

        def bad_embed_500(text):
            exc = ollama_sdk.ResponseError("internal error")
            exc.status_code = 500
            raise exc

        with patch("speckit_memory.server._embed_text", side_effect=bad_embed_500), \
             patched_index_dir(tmp_index), \
             patch("speckit_memory.server._first_call_done", True):
            with pytest.raises(ToolError):
                memory_recall(query="test")

    # T004 — CONFIG_ERROR message includes bad URL (FR-011)

    def test_recall_config_error_message_includes_url(self, tmp_index):
        """EMBEDDING_CONFIG_ERROR message includes the bad URL value and names OLLAMA_BASE_URL (FR-011)."""
        from fastmcp.exceptions import ToolError

        bad_url = "ftp://not-http"
        with patch("speckit_memory.server._OLLAMA_BASE_URL", bad_url), \
             patched_index_dir(tmp_index), \
             patch("speckit_memory.server._first_call_done", True):
            with pytest.raises(ToolError) as exc_info:
                memory_recall(query="test")

        msg = str(exc_info.value)
        assert bad_url in msg, f"Error must include bad URL value; got: {msg}"
        assert "OLLAMA_BASE_URL" in msg

    # T004a — CONFIG_ERROR (ToolError) propagates through fallback handler (ADR-039 invariant)

    def test_recall_config_error_not_caught_by_fallback_handler(self, tmp_index):
        """ToolError(CONFIG_ERROR) from _embed_text propagates — never swallowed by fallback (ADR-039)."""
        from fastmcp.exceptions import ToolError

        config_err = ToolError("EMBEDDING_CONFIG_ERROR: bad url (got: 'ftp://bad'). Hint: check OLLAMA_BASE_URL")
        with patch("speckit_memory.server._embed_text", side_effect=config_err), \
             patched_index_dir(tmp_index), \
             patch("speckit_memory.server._first_call_done", True):
            with pytest.raises(ToolError, match="EMBEDDING_CONFIG_ERROR"):
                memory_recall(query="test")

    # T005 — 'degraded' key absent on non-fallback paths (US2)

    def test_recall_degraded_absent_on_semantic_path(self, tmp_index, fake_embedder):
        """'degraded' key must be absent when Ollama is available (US2)."""
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            result = memory_recall(query="test")
        assert "degraded" not in result, f"'degraded' must be absent on semantic path; got: {result}"

    def test_recall_summary_only_no_degraded(self, tmp_index, fake_embedder):
        """'degraded' key must be absent on summary_only path (summary_only never embeds)."""
        with patched_index_dir(tmp_index):
            result = memory_recall(query="test", summary_only=True)
        assert "degraded" not in result

    # T005a — stderr warning on fallback activation (ADR-041, FR-012)

    def test_recall_fallback_emits_stderr_warning(self, tmp_index, fake_embedder, capsys):
        """Fallback activation emits exact warning string to stderr (ADR-041)."""
        with patch("speckit_memory.server._embed_text", side_effect=ConnectionError("refused")), \
             patched_index_dir(tmp_index), \
             patch("speckit_memory.server._first_call_done", True):
            seed_chunks(tmp_index, fake_embedder, count=1)
            memory_recall(query="test")

        captured = capsys.readouterr()
        assert (
            "[speckit-memory] WARNING: embedding unavailable — falling back to keyword search"
            in captured.err
        )

    # T006 — US3: filter and budget parity in fallback mode

    def test_recall_fallback_filter_source_file(self, tmp_index, fake_embedder):
        """Fallback mode: filter_source_file scopes results to matching source file."""
        from speckit_memory.index import init_table, insert_chunks_batch
        table = init_table(tmp_index)
        for sf in ["target.md", "other.md"]:
            insert_chunks_batch(table, [{
                "id": str(uuid.uuid4()),
                "content": f"Architecture decisions from {sf}",
                "vector": [0.0] * 768,
                "source_file": sf, "section": "S", "type": "adr",
                "feature": "001", "date": "2026-04-07", "tags": [], "synthetic": False,
            }])

        with patch("speckit_memory.server._embed_text", side_effect=ConnectionError("refused")), \
             patched_index_dir(tmp_index), \
             patch("speckit_memory.server._first_call_done", True):
            result = memory_recall(query="architecture", filter_source_file="target.md")

        assert result.get("degraded") is True
        assert {r["source_file"] for r in result["results"]} == {"target.md"}

    def test_recall_fallback_filters_dict(self, tmp_index, fake_embedder):
        """Fallback mode: filters dict (type, feature) scopes results correctly."""
        from speckit_memory.index import init_table, insert_chunks_batch
        table = init_table(tmp_index)
        insert_chunks_batch(table, [
            {"id": str(uuid.uuid4()), "content": "ADR feature 005 decisions",
             "vector": [0.0] * 768, "source_file": "a.md", "section": "S",
             "type": "adr", "feature": "005", "date": "2026-04-07", "tags": [], "synthetic": False},
            {"id": str(uuid.uuid4()), "content": "LOG feature 004 context",
             "vector": [0.0] * 768, "source_file": "b.md", "section": "S",
             "type": "log", "feature": "004", "date": "2026-04-07", "tags": [], "synthetic": False},
        ])

        with patch("speckit_memory.server._embed_text", side_effect=ConnectionError("refused")), \
             patched_index_dir(tmp_index), \
             patch("speckit_memory.server._first_call_done", True):
            result = memory_recall(query="decisions", filters={"type": "adr", "feature": "005"})

        assert result.get("degraded") is True
        assert all(r["type"] == "adr" for r in result["results"])
        assert all(r["feature"] == "005" for r in result["results"])

    def test_recall_fallback_top_k(self, tmp_index, fake_embedder):
        """Fallback mode: top_k caps number of results."""
        seed_chunks(tmp_index, fake_embedder, count=5)
        with patch("speckit_memory.server._embed_text", side_effect=ConnectionError("refused")), \
             patched_index_dir(tmp_index), \
             patch("speckit_memory.server._first_call_done", True):
            result = memory_recall(query="content", top_k=2)

        assert result.get("degraded") is True
        assert len(result["results"]) <= 2

    def test_recall_fallback_max_chars_and_budget_exhausted(self, tmp_index, fake_embedder):
        """Fallback mode: max_chars enforced and budget_exhausted returned."""
        seed_chunks(tmp_index, fake_embedder, count=5)  # each chunk ~58 chars
        with patch("speckit_memory.server._embed_text", side_effect=ConnectionError("refused")), \
             patched_index_dir(tmp_index), \
             patch("speckit_memory.server._first_call_done", True):
            result = memory_recall(query="content", max_chars=50)

        assert result.get("degraded") is True
        assert result.get("budget_exhausted") is True
        assert sum(len(r["content"]) for r in result["results"]) <= 50

    # T006a — min_score ignored in fallback mode (ADR-040)

    def test_recall_fallback_ignores_min_score(self, tmp_index, fake_embedder):
        """Fallback mode: min_score is not applied — low-scoring chunk still returned (ADR-040)."""
        from speckit_memory.index import init_table, insert_chunks_batch
        table = init_table(tmp_index)
        # Content that won't match "architecture decisions technology" at all → TF score = 0.0
        insert_chunks_batch(table, [{
            "id": str(uuid.uuid4()),
            "content": "Completely unrelated prose about nothing.",
            "vector": [0.0] * 768,
            "source_file": "a.md", "section": "S", "type": "adr",
            "feature": "001", "date": "2026-04-07", "tags": [], "synthetic": False,
        }])

        with patch("speckit_memory.server._embed_text", side_effect=ConnectionError("refused")), \
             patched_index_dir(tmp_index), \
             patch("speckit_memory.server._first_call_done", True):
            result = memory_recall(query="architecture decisions technology", min_score=0.95)

        assert result.get("degraded") is True
        assert len(result["results"]) >= 1, "min_score must be ignored in fallback mode"


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
        """T002: memory_store rejects even a nonexistent path — whitelist requires exactly 'synthetic'."""
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
        """T001: memory_store rejects a real-looking ADR path — only 'synthetic' is accepted (FR-001)."""
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            result = memory_store(
                content="A test summary.",
                metadata={
                    "source_file": ".specify/memory/ADR_008_lancedb-vector-backend.md",
                    "section": "Summary",
                    "type": "synthetic",
                    "feature": "002",
                    "date": "2026-04-07",
                    "tags": [],
                },
            )
        assert "error" in result
        assert result["error"]["code"] == "INVALID_SOURCE_FILE"

    def test_store_raises_tool_error_when_ollama_down(self, tmp_index, fake_embedder):
        """T016a: memory_store with Ollama down raises ToolError (ADR-033 breaking change)."""
        from fastmcp.exceptions import ToolError

        def bad_embed(text):
            raise ConnectionError("refused")

        with patch("speckit_memory.server._embed_text", side_effect=bad_embed), \
             patched_index_dir(tmp_index), \
             patch("speckit_memory.server._first_call_done", True):
            with pytest.raises(ToolError, match="EMBEDDING_UNAVAILABLE"):
                memory_store(
                    content="Test content",
                    metadata={"source_file": "synthetic", "section": "S",
                              "type": "synthetic", "feature": "006",
                              "date": "2026-04-14", "tags": []},
                )

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

    def test_delete_missing_file_returns_zero(self, tmp_index, fake_embedder, tmp_path):
        """Deleting a file with no indexed chunks returns deleted_chunks: 0."""
        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            with patch("speckit_memory.server._repo_root", return_value=tmp_path):
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

    def test_sync_raises_tool_error_when_ollama_down(self, tmp_index, fake_embedder):
        """T016b: memory_sync with Ollama down raises ToolError (ADR-033 breaking change)."""
        from fastmcp.exceptions import ToolError

        with patch("speckit_memory.server.run_sync", side_effect=ConnectionError("refused")), \
             patched_index_dir(tmp_index), \
             patch("speckit_memory.server._first_call_done", True):
            with pytest.raises(ToolError, match="EMBEDDING_UNAVAILABLE"):
                memory_sync()

    def test_sync_paths_limits_crawl_to_specified_files(self, tmp_index, fake_embedder, tmp_path):
        """memory_sync with paths= restricts embedding to only the listed files (relative paths)."""
        # Files must be in locations that match DEFAULT_INDEX_GLOBS so crawl_files finds them.
        repo = tmp_path / "repo"
        memory_dir = repo / ".specify" / "memory"
        memory_dir.mkdir(parents=True)
        (memory_dir / "ADR_001_included.md").write_text(
            "# Included\n\nThis file should be indexed when paths= is specified."
        )
        (memory_dir / "ADR_002_excluded.md").write_text(
            "# Excluded\n\nThis file must NOT be indexed when paths= restricts to ADR_001."
        )

        included_rel = ".specify/memory/ADR_001_included.md"
        excluded_rel = ".specify/memory/ADR_002_excluded.md"

        with patched_embed(fake_embedder), patched_index_dir(tmp_index):
            with patch("speckit_memory.server._repo_root", return_value=repo):
                result = memory_sync(paths=[included_rel])

        assert "error" not in result, f"Unexpected error: {result}"
        assert result["indexed"] == 1, (
            f"Expected exactly 1 file indexed, got {result['indexed']} "
            f"(scoped sync must restrict to paths= argument)"
        )
        assert result["skipped"] == 0

        from speckit_memory.index import load_manifest
        manifest = load_manifest(tmp_index)
        assert included_rel in manifest["entries"], "Included file must be in manifest"
        assert excluded_rel not in manifest["entries"], "Excluded file must NOT be in manifest"


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


# ---------------------------------------------------------------------------
# memory_delete — Ollama unavailable (T023)
# ---------------------------------------------------------------------------

class TestMemoryDeleteOllamaUnavailable:
    """T023: memory_delete must work without Ollama — delete never requires embedding (FR-008)."""

    def test_delete_by_id_does_not_call_ensure_init(self, tmp_index, fake_embedder, tmp_path):
        """memory_delete must not call _ensure_init (T023b removes the call)."""
        ensure_init_called = []

        def mock_ensure_init():
            ensure_init_called.append(True)

        with patch("speckit_memory.server._ensure_init", side_effect=mock_ensure_init), \
             patched_index_dir(tmp_index), \
             patch("speckit_memory.server._repo_root", return_value=tmp_path):
            # nonexistent source_file — no embedding needed
            memory_delete(source_file="nonexistent.md")

        assert ensure_init_called == [], "memory_delete must not call _ensure_init (T023b)"

    def test_delete_by_id_succeeds_without_ollama(self, tmp_index):
        """memory_delete by id works even when _embed_text raises ConnectionError."""
        from speckit_memory.index import init_table, insert_chunks_batch

        chunk_id = str(uuid.uuid4())
        table = init_table(tmp_index)
        insert_chunks_batch(table, [{
            "id": chunk_id, "content": "Delete me.", "vector": [0.0] * 768,
            "source_file": "synthetic", "section": "S", "type": "synthetic",
            "feature": "006", "date": "2026-04-14", "tags": [], "synthetic": True,
        }])

        def bad_embed(text):
            raise ConnectionError("Ollama down")

        with patch("speckit_memory.server._embed_text", side_effect=bad_embed), \
             patched_index_dir(tmp_index), \
             patch("speckit_memory.server._first_call_done", False):
            result = memory_delete(id=chunk_id)

        assert "error" not in result
        assert result["deleted_chunks"] == 1


@pytest.fixture
def tmp_index(tmp_path):
    index_dir = tmp_path / ".index"
    index_dir.mkdir()
    return index_dir
