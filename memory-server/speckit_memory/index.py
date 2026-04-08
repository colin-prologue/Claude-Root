"""LanceDB read/write operations for the speckit memory index."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import lancedb
import pyarrow as pa


# LanceDB table name
TABLE_NAME = "chunks"

# Chunk schema
_SCHEMA = pa.schema([
    pa.field("id", pa.string()),
    pa.field("content", pa.string()),
    pa.field("vector", pa.list_(pa.float32(), 768)),
    pa.field("source_file", pa.string()),
    pa.field("section", pa.string()),
    pa.field("type", pa.string()),
    pa.field("feature", pa.string()),
    pa.field("date", pa.string()),
    pa.field("tags", pa.list_(pa.string())),
    pa.field("synthetic", pa.bool_()),
])

_EMPTY_MANIFEST = {
    "version": "1",
    "embedding_model": "",
    "embedding_dimension": 768,
    "similarity_metric": "cosine",
    "entries": {},
}


def _db(index_dir: Path) -> lancedb.DBConnection:
    return lancedb.connect(str(index_dir / "chunks.lance"))


def init_table(index_dir: Path) -> Any:
    """Open or create the chunks LanceDB table."""
    db = _db(index_dir)
    try:
        return db.open_table(TABLE_NAME)
    except Exception:
        return db.create_table(TABLE_NAME, schema=_SCHEMA)


def drop_table(index_dir: Path) -> None:
    """Drop the chunks table entirely (used for full re-index)."""
    db = _db(index_dir)
    try:
        db.drop_table(TABLE_NAME)
    except Exception:
        pass


def load_manifest(index_dir: Path) -> dict[str, Any]:
    """Load manifest.json; return default structure if missing."""
    manifest_path = index_dir / "manifest.json"
    if not manifest_path.exists():
        return dict(_EMPTY_MANIFEST, entries={})
    return json.loads(manifest_path.read_text())


def save_manifest(index_dir: Path, manifest: dict[str, Any]) -> None:
    """Persist manifest to disk."""
    (index_dir / "manifest.json").write_text(json.dumps(manifest, indent=2))


def insert_chunks_batch(table: Any, chunks: list[dict[str, Any]]) -> None:
    """Insert a batch of chunk dicts into the LanceDB table."""
    if not chunks:
        return
    records = []
    for c in chunks:
        records.append({
            "id": c["id"],
            "content": c["content"],
            "vector": [float(v) for v in c["vector"]],
            "source_file": c.get("source_file", ""),
            "section": c.get("section", ""),
            "type": c.get("type", "synthetic"),
            "feature": c.get("feature", ""),
            "date": c.get("date", ""),
            "tags": c.get("tags", []),
            "synthetic": bool(c.get("synthetic", False)),
        })
    table.add(records)


def delete_chunks_by_source_file(table: Any, source_file: str) -> int:
    """Delete all chunks for a given source file. Returns count deleted."""
    before = table.count_rows()
    table.delete(f"source_file = '{source_file}'")
    after = table.count_rows()
    return before - after


def delete_chunk_by_id(table: Any, chunk_id: str) -> int:
    """Delete a single chunk by UUID. Returns 1 if deleted, 0 if not found."""
    before = table.count_rows()
    table.delete(f"id = '{chunk_id}'")
    after = table.count_rows()
    return before - after


def vector_search(
    table: Any,
    query_vector: list[float],
    top_k: int = 5,
    min_score: float = 0.5,
    filter_type: str | None = None,
    filter_feature: str | None = None,
    filter_tags: list[str] | None = None,
) -> list[dict[str, Any]]:
    """Perform vector similarity search with optional metadata pre-filter.

    Returns list of result dicts with score field. Cosine similarity computed
    as dot product (vectors are L2-normalised at write time — ADR-010).
    """
    q = table.search(query_vector, vector_column_name="vector")

    # Build pre-filter conditions (AND-combined)
    conditions: list[str] = []
    if filter_type:
        conditions.append(f"type = '{filter_type}'")
    if filter_feature:
        conditions.append(f"feature = '{filter_feature}'")
    # tags filter: check array containment (LanceDB SQL dialect)
    if filter_tags:
        for tag in filter_tags:
            conditions.append(f"array_has(tags, '{tag}')")
    if conditions:
        q = q.where(" AND ".join(conditions))

    q = q.limit(top_k * 4)  # over-fetch to allow score threshold filtering
    rows = q.to_list()  # list[dict] — no pandas dependency at runtime

    output = []
    for row in rows:
        # LanceDB returns _distance (L2 squared for normalised vectors).
        # Cosine similarity = 1 - L2² / 2 (valid only for L2-normalised vectors — ADR-010).
        raw_distance = float(row.get("_distance", 0.0))
        score = max(0.0, 1.0 - raw_distance / 2.0)
        if score < min_score:
            continue
        tags = row.get("tags") or []
        output.append({
            "id": row["id"],
            "content": row["content"],
            "score": round(score, 4),
            "source_file": row["source_file"],
            "section": row["section"],
            "type": row["type"],
            "feature": row["feature"],
            "date": row["date"],
            "tags": list(tags),
            "synthetic": bool(row["synthetic"]),
        })
        if len(output) >= top_k:
            break

    return output
