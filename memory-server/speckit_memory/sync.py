"""Manifest diff + file crawl + embed + chunking logic."""
from __future__ import annotations

import hashlib
import math
import os
import re
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


# ~6000 chars ≈ 1500 tokens (4 chars/token heuristic)
MAX_CHUNK_CHARS = 6000
MIN_CHUNK_CHARS = 50

# Default Ollama config
DEFAULT_OLLAMA_BASE_URL = "http://localhost:11434"
DEFAULT_OLLAMA_MODEL = "nomic-embed-text"
EMBEDDING_DIMENSION = 768

# Default index paths (glob patterns, relative to repo root)
DEFAULT_INDEX_GLOBS = [
    ".specify/memory/ADR_*.md",
    ".specify/memory/LOG_*.md",
    ".specify/memory/constitution.md",
    "specs/*/spec.md",
    "specs/*/plan.md",
]


# ---------------------------------------------------------------------------
# Chunking
# ---------------------------------------------------------------------------

def _strip_frontmatter(text: str) -> tuple[str, dict[str, str]]:
    """Remove YAML frontmatter from start of markdown. Returns (body, kv_dict)."""
    if not text.startswith("---"):
        return text, {}
    end = text.find("\n---", 3)
    if end == -1:
        return text, {}
    fm_block = text[3:end].strip()
    body = text[end + 4:].lstrip("\n")
    kv: dict[str, str] = {}
    for line in fm_block.splitlines():
        if ":" in line:
            k, _, v = line.partition(":")
            kv[k.strip()] = v.strip()
    return body, kv


def _split_at_paragraphs(text: str, max_chars: int, heading_prefix: str) -> list[str]:
    """Split long text at paragraph boundaries; attach continuation prefix."""
    parts: list[str] = []
    current = ""
    for para in re.split(r"\n\n+", text):
        candidate = (current + "\n\n" + para).strip() if current else para
        if len(candidate) <= max_chars:
            current = candidate
        else:
            if current:
                parts.append(current)
            while len(para) > max_chars:
                parts.append(para[:max_chars])
                para = para[max_chars:]
            current = para
    if current:
        parts.append(current)
    return parts


def chunk_markdown(filename: str, text: str) -> list[dict[str, Any]]:
    """Split markdown into chunks per data-model chunking rules.

    Returns list of chunk dicts with: content, section, source_file.
    """
    body, _fm = _strip_frontmatter(text)
    stem = Path(filename).stem

    heading_pattern = re.compile(r"^(#{1,2})\s+(.+)$", re.MULTILINE)
    matches = list(heading_pattern.finditer(body))

    raw_sections: list[tuple[str, str]] = []

    if not matches:
        raw_sections.append((stem, body.strip()))
    else:
        preamble = body[: matches[0].start()].strip()
        if preamble:
            raw_sections.append((stem, preamble))
        for i, m in enumerate(matches):
            # Regex is #{1,2} so only H1/H2 reach here; H3+ body falls
            # inside the preceding H1/H2 section as plain text (intentional).
            heading_label = m.group(2).strip()
            start = m.end()
            end = matches[i + 1].start() if i + 1 < len(matches) else len(body)
            section_body = body[start:end].strip()
            raw_sections.append((heading_label, section_body))

    chunks: list[dict[str, Any]] = []
    pending_heading: str | None = None
    pending_body: str | None = None

    def flush(heading: str, content: str) -> None:
        parts = _split_at_paragraphs(content, MAX_CHUNK_CHARS, heading)
        if not parts:
            return
        for idx, part in enumerate(parts):
            section_label = heading if idx == 0 else f"{heading} (continued)"
            chunks.append({"content": part, "section": section_label, "source_file": filename})

    for heading, content in raw_sections:
        if not content:
            continue
        if len(content) < MIN_CHUNK_CHARS:
            if pending_heading is not None:
                pending_body = (pending_body + "\n\n" + content).strip()
            else:
                pending_heading = heading
                pending_body = content
            continue

        if pending_heading is not None:
            # Short section merges INTO this section — use this section's heading
            combined = (pending_body + "\n\n" + content).strip()
            flush(heading, combined)
            pending_heading = None
            pending_body = None
        else:
            flush(heading, content)

    if pending_heading is not None and pending_body:
        flush(pending_heading, pending_body)

    return chunks


# ---------------------------------------------------------------------------
# Embedding (T013) + L2 normalisation (T014)
# ---------------------------------------------------------------------------

def _ollama_embed(text: str, base_url: str, model: str) -> list[float]:
    """Call Ollama embed API via the ollama SDK and return the raw vector."""
    import ollama

    client = ollama.Client(host=base_url)
    response = client.embed(model=model, input=text)
    return response["embeddings"][0]


def _l2_normalize(vector: list[float]) -> list[float]:
    """L2-normalize a vector. Returns zero vector unchanged."""
    norm = math.sqrt(sum(v * v for v in vector))
    if norm == 0:
        return vector
    return [v / norm for v in vector]


# ---------------------------------------------------------------------------
# File crawl + type inference (T016)
# ---------------------------------------------------------------------------

def _infer_type(rel_path: str) -> str:
    """Infer chunk type from path prefix per data-model validation rules."""
    name = Path(rel_path).name
    if name.startswith("ADR_"):
        return "adr"
    if name.startswith("LOG_"):
        return "log"
    if name == "constitution.md":
        return "constitution"
    if "specs/" in rel_path and name in ("spec.md", "plan.md"):
        return "spec"
    return "synthetic"


def _infer_feature(rel_path: str) -> str:
    """Extract feature name from specs/<feature>/... paths."""
    parts = Path(rel_path).parts
    if len(parts) >= 2 and parts[0] == "specs":
        return parts[1]
    return ""


def crawl_files(repo_root: Path, index_paths_env: str | None = None) -> list[Path]:
    """Return list of markdown files to index, based on configured globs."""
    import glob as _glob
    patterns_raw = index_paths_env or ""
    if patterns_raw:
        patterns = [p.strip() for p in patterns_raw.split(",") if p.strip()]
    else:
        patterns = DEFAULT_INDEX_GLOBS

    found: list[Path] = []
    for pattern in patterns:
        for match in _glob.glob(str(repo_root / pattern)):
            p = Path(match)
            if p.is_file():
                found.append(p)
    return list(set(found))


# ---------------------------------------------------------------------------
# Change detection (T022)
# ---------------------------------------------------------------------------

def _iso_mtime(path: Path) -> str:
    """ISO mtime string — used for chunk `date` metadata only, not change detection."""
    ts = path.stat().st_mtime
    return datetime.fromtimestamp(ts, tz=timezone.utc).isoformat()


def _content_hash(path: Path) -> str:
    """SHA-256 hex digest of file content.

    Used for manifest change detection instead of mtime. Unlike mtime, content
    hashes are stable across git operations (checkout, pull, reset) that reset
    file timestamps without changing content.
    """
    return hashlib.sha256(path.read_bytes()).hexdigest()


def classify_files(
    files: list[Path],
    manifest: dict,
    repo_root: Path,
) -> dict[str, list[Path]]:
    """Classify files as new / stale / unchanged relative to manifest entries."""
    entries = manifest.get("entries", {})
    classified: dict[str, list[Path]] = {"new": [], "stale": [], "unchanged": []}
    for f in files:
        rel = str(f.relative_to(repo_root))
        if rel not in entries:
            classified["new"].append(f)
        elif _content_hash(f) != entries[rel].get("hash", ""):
            classified["stale"].append(f)
        else:
            classified["unchanged"].append(f)
    return classified


def find_deleted(manifest: dict, files: list[Path], repo_root: Path) -> list[str]:
    """Return relative paths present in manifest but absent from filesystem.

    Empty-string keys and the reserved "synthetic" key are excluded — they are
    never real source files and must not trigger deletion (FR-007).
    """
    indexed_rel = {str(f.relative_to(repo_root)) for f in files}
    return [
        rel for rel in manifest.get("entries", {})
        if rel and rel != "synthetic" and rel not in indexed_rel
    ]


# ---------------------------------------------------------------------------
# Sync orchestration (T022-T025)
# ---------------------------------------------------------------------------

def run_sync(
    index_dir: Path,
    repo_root: Path,
    embed_fn,  # callable(text) -> list[float]
    model_name: str,
    full: bool = False,
    paths: list[str] | None = None,
    index_paths_env: str | None = None,
) -> dict[str, Any]:
    """Orchestrate incremental or full re-index.

    Returns stats dict: {indexed, skipped, deleted, duration_ms, model}.
    """
    if full and paths:
        raise ValueError(
            "full=True and paths cannot be used together — a full rebuild drops and "
            "recreates the entire index, making scoped paths meaningless."
        )

    import time
    from speckit_memory.index import (
        init_table, drop_table, load_manifest, save_manifest,
        insert_chunks_batch, delete_chunks_by_source_file,
        maybe_create_index, compact_table,
    )

    start = time.monotonic()
    index_dir.mkdir(parents=True, exist_ok=True)
    manifest = load_manifest(index_dir)

    # Manifest version migration: v1 used mtime for change detection; v2 uses
    # content hash. Force full re-index to rebuild with consistent hash-based
    # entries. This runs once per index and is transparent to the caller.
    if manifest.get("version", "1") != "2" and not full:
        full = True

    # Model mismatch check (T035) — only meaningful when not rebuilding
    stored_model = manifest.get("embedding_model", "")
    if stored_model and stored_model != model_name and not full:
        return {
            "error": {
                "code": "MODEL_MISMATCH",
                "message": (
                    f"Index was built with model '{stored_model}' but current config is '{model_name}'. "
                    "Run memory_sync with full=True to rebuild the index."
                ),
                "recoverable": False,
            }
        }

    # DB-manifest divergence → force full re-index (T037).
    # Covers two cases:
    #   1. Manifest has model info but chunks.lance directory is gone (clean deletion).
    #   2. Table exists but is empty while manifest claims indexed files exist —
    #      happens when chunks.lance is partially cleared (files removed but dir stub
    #      remains) or when the DB was recreated fresh after a partial index deletion.
    lance_path = index_dir / "chunks.lance"
    if not full:
        if manifest.get("embedding_model") and not lance_path.exists():
            full = True
        elif manifest.get("entries") and lance_path.exists():
            if init_table(index_dir).count_rows() == 0:
                full = True

    if full:
        drop_table(index_dir)
        manifest = {
            "version": "2",
            "embedding_model": model_name,
            "embedding_dimension": EMBEDDING_DIMENSION,
            "similarity_metric": "cosine",
            "entries": {},
        }

    table = init_table(index_dir)

    # Determine file set
    all_files = crawl_files(repo_root, index_paths_env)
    # scoped_files drives the add/update pass; all_files drives cleanup so that
    # a scoped sync never considers out-of-scope files as "deleted" (ADR-027, FR-001a).
    scoped_files = (
        [f for f in all_files if str(f.relative_to(repo_root)) in paths]
        if paths else all_files
    )

    classified = classify_files(scoped_files, manifest, repo_root)

    indexed = 0
    skipped = len(classified["unchanged"])
    deleted = 0

    # Cleanup pass — skipped on scoped syncs (ADR-027, FR-001a) and full rebuilds
    # (full=True drops and recreates the table, so per-file cleanup is a no-op).
    if not paths and not full:
        deleted_candidates = find_deleted(manifest, all_files, repo_root)
        for rel in deleted_candidates:
            # Conservative safety check (ADR-030): verify the file truly doesn't exist
            # before deleting. Handles permission errors or glob misses.
            try:
                if (repo_root / rel).exists():
                    continue  # file exists but wasn't crawled — skip
            except OSError:
                continue  # cannot check; treat as present (conservative)
            n = delete_chunks_by_source_file(table, rel)
            manifest["entries"].pop(rel, None)
            deleted += n  # chunks removed, not files (FR-008)

    # Stale file: delete old chunks then re-embed
    for f in classified["stale"]:
        rel = str(f.relative_to(repo_root))
        delete_chunks_by_source_file(table, rel)
        manifest["entries"].pop(rel, None)

    # Embed new + stale files
    to_embed = classified["new"] + classified["stale"]
    for f in to_embed:
        rel = str(f.relative_to(repo_root))
        text = f.read_text(encoding="utf-8", errors="replace")
        raw_chunks = chunk_markdown(rel, text)
        chunk_records = []
        for c in raw_chunks:
            raw_vec = embed_fn(c["content"])
            vec = _l2_normalize(raw_vec)
            chunk_id = str(uuid.uuid4())
            chunk_records.append({
                "id": chunk_id,
                "content": c["content"],
                "vector": vec,
                "source_file": rel,
                "section": c["section"],
                "type": _infer_type(rel),
                "feature": _infer_feature(rel),
                "date": _iso_mtime(f),
                "tags": [],
                "synthetic": False,
            })
        if chunk_records:
            insert_chunks_batch(table, chunk_records)
            manifest["entries"][rel] = {
                "hash": _content_hash(f),
                "chunk_ids": [c["id"] for c in chunk_records],
            }
            indexed += 1

    manifest["embedding_model"] = model_name
    manifest["embedding_dimension"] = EMBEDDING_DIMENSION
    manifest["version"] = "2"
    save_manifest(index_dir, manifest)

    # Create ANN index when corpus is large enough; compact after full rebuild
    maybe_create_index(table)
    if full:
        compact_table(table)

    duration_ms = int((time.monotonic() - start) * 1000)
    return {
        "indexed": indexed,
        "skipped": skipped,
        "deleted": deleted,
        "duration_ms": duration_ms,
        "model": model_name,
    }
