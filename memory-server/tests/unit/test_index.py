"""Unit tests for LanceDB table operations and manifest I/O.

These tests must FAIL before T008-T011 implement the operations.
Tests use a temporary directory and a fake embedder to avoid Ollama dependency.
"""
import json
import pytest
import tempfile
from pathlib import Path

from speckit_memory.index import (
    init_table,
    load_manifest,
    save_manifest,
    insert_chunks_batch,
    delete_chunks_by_source_file,
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
        assert manifest["version"] == "1"

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
