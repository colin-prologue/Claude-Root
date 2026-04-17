"""Unit tests for LanceDB table operations and manifest I/O.

These tests must FAIL before T008-T011 implement the operations.
Tests use a temporary directory and a fake embedder to avoid Ollama dependency.
"""
import json
import pytest
import tempfile
from pathlib import Path

import math

from speckit_memory.index import (
    init_table,
    load_manifest,
    save_manifest,
    insert_chunks_batch,
    delete_chunks_by_source_file,
    vector_search,
    scan_chunks,
    keyword_search,
)


@pytest.fixture
def tmp_index(tmp_path):
    index_dir = tmp_path / ".index"
    index_dir.mkdir()
    return index_dir


def make_chunk(source_file="test.md", section="Intro", idx=0, vector=None, fake_embed=None):
    if vector is None and fake_embed is not None:
        vector = fake_embed("dummy")
    elif vector is None:
        vector = [0.0] * 768
    return {
        "id": f"00000000-0000-0000-0000-{idx:012d}",
        "content": f"Content for {section}",
        "vector": vector,
        "source_file": source_file,
        "section": section,
        "type": "adr",
        "feature": "002",
        "date": "2026-04-07",
        "tags": [],
        "synthetic": False,
    }


class TestTableSchema:
    def test_table_initialization_creates_chunks_table(self, tmp_index):
        table = init_table(tmp_index)
        assert table is not None

    def test_table_schema_has_required_fields(self, tmp_index):
        table = init_table(tmp_index)
        schema = table.schema
        field_names = [f.name for f in schema]
        for required in ["id", "content", "vector", "source_file", "section", "type", "synthetic"]:
            assert required in field_names, f"Missing field: {required}"


class TestManifest:
    def test_manifest_round_trip(self, tmp_index):
        manifest = {
            "version": "1",
            "embedding_model": "nomic-embed-text",
            "embedding_dimension": 768,
            "similarity_metric": "cosine",
            "entries": {},
        }
        save_manifest(tmp_index, manifest)
        loaded = load_manifest(tmp_index)
        assert loaded == manifest

    def test_load_manifest_returns_empty_when_missing(self, tmp_index):
        manifest = load_manifest(tmp_index)
        assert manifest["entries"] == {}
        assert manifest["version"] == "2"

    def test_manifest_json_format(self, tmp_index):
        manifest = {
            "version": "1",
            "embedding_model": "nomic-embed-text",
            "embedding_dimension": 768,
            "similarity_metric": "cosine",
            "entries": {"a.md": {"mtime": "2026-04-07T00:00:00", "chunk_ids": ["abc"]}},
        }
        save_manifest(tmp_index, manifest)
        raw = json.loads((tmp_index / "manifest.json").read_text())
        assert raw["entries"]["a.md"]["chunk_ids"] == ["abc"]


class TestInsertBatch:
    def test_insert_batch_persists_correct_fields(self, tmp_index, fake_embedder):
        table = init_table(tmp_index)
        chunk = make_chunk(vector=fake_embedder("hello"))
        insert_chunks_batch(table, [chunk])
        rows = table.to_pandas()
        assert len(rows) == 1
        assert rows.iloc[0]["source_file"] == "test.md"
        assert rows.iloc[0]["section"] == "Intro"
        assert rows.iloc[0]["type"] == "adr"

    def test_insert_batch_multiple_chunks(self, tmp_index, fake_embedder):
        table = init_table(tmp_index)
        chunks = [make_chunk(section=f"S{i}", idx=i, vector=fake_embedder(f"s{i}")) for i in range(3)]
        insert_chunks_batch(table, chunks)
        rows = table.to_pandas()
        assert len(rows) == 3


class TestDeleteBySourceFile:
    def test_delete_by_source_file_removes_all_matching(self, tmp_index, fake_embedder):
        table = init_table(tmp_index)
        chunks = [
            make_chunk("file_a.md", "S1", 0, vector=fake_embedder("s1")),
            make_chunk("file_a.md", "S2", 1, vector=fake_embedder("s2")),
            make_chunk("file_b.md", "S3", 2, vector=fake_embedder("s3")),
        ]
        insert_chunks_batch(table, chunks)
        deleted = delete_chunks_by_source_file(table, "file_a.md")
        rows = table.to_pandas()
        assert len(rows) == 1
        assert rows.iloc[0]["source_file"] == "file_b.md"
        assert deleted == 2

    def test_delete_by_source_file_idempotent(self, tmp_index, fake_embedder):
        table = init_table(tmp_index)
        chunk = make_chunk(vector=fake_embedder("hello"))
        insert_chunks_batch(table, [chunk])
        delete_chunks_by_source_file(table, "test.md")
        deleted = delete_chunks_by_source_file(table, "test.md")
        assert deleted == 0


class TestFilterSourceFile:
    """T016: vector_search with filter_source_file returns only matching chunks."""

    def test_filter_source_file_restricts_results(self, tmp_index, fake_embedder):
        table = init_table(tmp_index)
        for i, sf in enumerate(["file_a.md", "file_b.md"]):
            insert_chunks_batch(table, [make_chunk(source_file=sf, section=f"S{i}", idx=i, fake_embed=fake_embedder)])
        results = vector_search(table, fake_embedder("dummy"), top_k=10, min_score=0.0, filter_source_file="file_a.md")
        sources = {r["source_file"] for r in results}
        assert sources == {"file_a.md"}, f"Expected only file_a.md, got {sources}"


class TestScoreFormula:
    """Verify that LanceDB returns L2-squared (not plain L2) in _distance for brute-force search.

    For L2-normalised vectors, cosine similarity = 1 - L2² / 2.
    The score formula in vector_search assumes _distance is L2² — this test confirms it.

    Orthogonal unit vectors: cos_sim = 0 → L2² = 2.0, score = 0.
    If _distance were plain L2, score would be ≈ 0.293 (wrong).
    """

    def _unit(self, dim: int, idx: int) -> list[float]:
        """Return a unit vector with 1.0 at position idx, 0.0 elsewhere."""
        v = [0.0] * dim
        v[idx] = 1.0
        return v

    def test_identical_vectors_score_is_one(self, tmp_index):
        table = init_table(tmp_index)
        vec = self._unit(768, 0)
        insert_chunks_batch(table, [make_chunk(vector=vec)])
        results = vector_search(table, vec, top_k=1, min_score=0.0)
        assert results, "Expected one result"
        assert abs(results[0]["score"] - 1.0) < 0.001, f"Expected score≈1.0, got {results[0]['score']}"

    def test_orthogonal_vectors_score_is_zero(self, tmp_index):
        """Orthogonal unit vectors have cosine similarity 0. Score must be 0, not ~0.293."""
        table = init_table(tmp_index)
        vec_a = self._unit(768, 0)
        vec_b = self._unit(768, 1)
        insert_chunks_batch(table, [make_chunk(vector=vec_a)])
        results = vector_search(table, vec_b, top_k=1, min_score=0.0)
        assert results, "Expected one result"
        # If _distance is L2 (not L2²), score would be ≈0.293 — formula is wrong.
        # If _distance is L2², score = 1 - 2.0/2 = 0.0 — formula is correct.
        assert results[0]["score"] < 0.01, (
            f"Expected score≈0 for orthogonal vectors, got {results[0]['score']}. "
            "This may indicate LanceDB returns plain L2 (not L2²) — fix formula to "
            "1 - (raw_distance ** 2) / 2.0"
        )


class TestScanChunks:
    """T008: scan_chunks covers all filter types, top_k, and edge cases (ADR-037)."""

    def _make_chunk(self, idx, source_file="f.md", section="S", chunk_type="adr",
                    feature="001", tags=None):
        return {
            "id": f"00000000-0000-0000-0000-{idx:012d}",
            "content": f"Content {idx}",
            "vector": [0.0] * 768,
            "source_file": source_file,
            "section": section,
            "type": chunk_type,
            "feature": feature,
            "date": "2026-04-14",
            "tags": tags or [],
            "synthetic": False,
        }

    def test_returns_rows_up_to_top_k(self, tmp_index):
        table = init_table(tmp_index)
        for i in range(5):
            insert_chunks_batch(table, [self._make_chunk(i)])
        result = scan_chunks(table, top_k=3)
        assert len(result) == 3

    def test_empty_table_returns_empty_list(self, tmp_index):
        table = init_table(tmp_index)
        result = scan_chunks(table)
        assert result == []

    def test_filter_type_returns_only_matching(self, tmp_index):
        table = init_table(tmp_index)
        insert_chunks_batch(table, [
            self._make_chunk(0, chunk_type="adr"),
            self._make_chunk(1, chunk_type="log"),
            self._make_chunk(2, chunk_type="adr"),
        ])
        result = scan_chunks(table, top_k=10, filter_type="adr")
        assert all(r["type"] == "adr" for r in result)
        assert len(result) == 2

    def test_filter_feature_returns_only_matching(self, tmp_index):
        table = init_table(tmp_index)
        insert_chunks_batch(table, [
            self._make_chunk(0, feature="001"),
            self._make_chunk(1, feature="002"),
        ])
        result = scan_chunks(table, top_k=10, filter_feature="001")
        assert all(r["feature"] == "001" for r in result)
        assert len(result) == 1

    def test_filter_tags_all_must_match(self, tmp_index):
        table = init_table(tmp_index)
        insert_chunks_batch(table, [
            self._make_chunk(0, tags=["alpha", "beta"]),
            self._make_chunk(1, tags=["beta"]),
            self._make_chunk(2, tags=["gamma"]),
        ])
        result = scan_chunks(table, top_k=10, filter_tags=["beta"])
        assert len(result) == 2
        assert all("beta" in (r.get("tags") or []) for r in result)

    def test_filter_source_file_returns_only_matching(self, tmp_index):
        table = init_table(tmp_index)
        insert_chunks_batch(table, [
            self._make_chunk(0, source_file="a.md"),
            self._make_chunk(1, source_file="b.md"),
        ])
        result = scan_chunks(table, top_k=10, filter_source_file="a.md")
        assert all(r["source_file"] == "a.md" for r in result)
        assert len(result) == 1

    def test_result_has_no_score_field(self, tmp_index):
        table = init_table(tmp_index)
        insert_chunks_batch(table, [self._make_chunk(0)])
        result = scan_chunks(table, top_k=5)
        assert len(result) == 1
        assert "score" not in result[0]

    def test_top_k_truncates_when_more_rows_exist(self, tmp_index):
        table = init_table(tmp_index)
        for i in range(10):
            insert_chunks_batch(table, [self._make_chunk(i)])
        result = scan_chunks(table, top_k=2)
        assert len(result) == 2


class TestKeywordSearch:
    """T007: keyword_search() — occurrence-count TF scoring with max-relative [0,1] normalization."""

    def _make_chunk(self, idx, content="", section="", source_file="f.md",
                    chunk_type="adr", feature="001"):
        return {
            "id": f"00000000-0000-0000-0000-{idx:012d}",
            "content": content,
            "vector": [0.0] * 768,
            "source_file": source_file,
            "section": section,
            "type": chunk_type,
            "feature": feature,
            "date": "2026-04-14",
            "tags": [],
            "synthetic": False,
        }

    def test_zero_match_returns_score_zero(self, tmp_index):
        """Chunk with no query terms present scores 0.0."""
        table = init_table(tmp_index)
        insert_chunks_batch(table, [self._make_chunk(0, content="unrelated prose", section="")])
        results = keyword_search(table, "architecture decisions", top_k=10)
        assert len(results) == 1
        assert results[0]["score"] == 0.0

    def test_best_match_chunk_scores_one(self, tmp_index):
        """Best-matching chunk gets score 1.0 via max-relative normalization."""
        table = init_table(tmp_index)
        insert_chunks_batch(table, [
            self._make_chunk(0, content="architecture", section=""),
            self._make_chunk(1, content="architecture architecture architecture", section=""),
        ])
        results = keyword_search(table, "architecture", top_k=10)
        assert max(r["score"] for r in results) == 1.0

    def test_partial_match_returns_intermediate_score(self, tmp_index):
        """Chunk matching some but not all query terms returns score strictly between 0 and 1."""
        table = init_table(tmp_index)
        insert_chunks_batch(table, [
            self._make_chunk(0, content="architecture notes", section=""),
            self._make_chunk(1, content="architecture and decisions", section=""),
        ])
        results = keyword_search(table, "architecture decisions technology", top_k=10)
        scores = sorted([r["score"] for r in results], reverse=True)
        assert any(0.0 < s < 1.0 for s in scores), f"Expected intermediate score; got {scores}"

    def test_more_occurrences_scores_higher(self, tmp_index):
        """Chunk with more occurrences of query term ranks above chunk with fewer (ADR-043)."""
        table = init_table(tmp_index)
        insert_chunks_batch(table, [
            self._make_chunk(0, content="architecture", section=""),
            self._make_chunk(1, content="architecture architecture architecture", section=""),
        ])
        results = keyword_search(table, "architecture", top_k=10)
        score_by_id = {r["id"]: r["score"] for r in results}
        id_low = "00000000-0000-0000-0000-000000000000"
        id_high = "00000000-0000-0000-0000-000000000001"
        assert score_by_id[id_high] > score_by_id[id_low]

    def test_empty_query_all_chunks_score_zero(self, tmp_index):
        """Empty query → all chunks score 0.0; returned in table order."""
        table = init_table(tmp_index)
        insert_chunks_batch(table, [
            self._make_chunk(0, content="architecture", section=""),
            self._make_chunk(1, content="decisions technology", section=""),
        ])
        results = keyword_search(table, "", top_k=10)
        assert all(r["score"] == 0.0 for r in results)

    def test_result_includes_required_fields_excludes_vector(self, tmp_index):
        """Result dicts include all required fields and exclude 'vector'."""
        table = init_table(tmp_index)
        insert_chunks_batch(table, [self._make_chunk(0, content="test content", section="Intro")])
        results = keyword_search(table, "test", top_k=10)
        assert len(results) == 1
        row = results[0]
        for field in ("id", "content", "score", "source_file", "section", "type",
                      "feature", "date", "tags", "synthetic"):
            assert field in row, f"Missing required field: {field}"
        assert "vector" not in row, "'vector' must be excluded from results"

    def test_top_k_caps_results(self, tmp_index):
        """top_k parameter caps number of returned results."""
        table = init_table(tmp_index)
        for i in range(5):
            insert_chunks_batch(table, [self._make_chunk(i, content=f"architecture item {i}")])
        results = keyword_search(table, "architecture", top_k=3)
        assert len(results) <= 3
