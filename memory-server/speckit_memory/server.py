"""FastMCP server exposing four memory tools: recall, store, sync, delete."""
from __future__ import annotations

import os
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastmcp import FastMCP

from speckit_memory.index import (
    delete_chunk_by_id,
    delete_chunks_by_source_file,
    init_table,
    insert_chunks_batch,
    load_manifest,
    save_manifest,
    vector_search,
)
from speckit_memory.sync import (
    _l2_normalize,
    _ollama_embed,
    run_sync,
    crawl_files,
)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

_OLLAMA_BASE_URL = os.environ.get("OLLAMA_BASE_URL", "http://localhost:11434")
_OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "nomic-embed-text")
_MEMORY_INDEX_PATH = os.environ.get("MEMORY_INDEX_PATH", "")

# Process-lifetime first-call flag (ADR-011 self-init sync)
_first_call_done = False


def _repo_root() -> Path:
    """Return the repo root (directory of this package's grandparent)."""
    # memory-server/speckit_memory/server.py -> memory-server/ -> repo root
    return Path(__file__).parent.parent.parent


def _index_dir() -> Path:
    return _repo_root() / ".specify" / "memory" / ".index"


def _embed_text(text: str) -> list[float]:
    """Embed text via Ollama. Raises on network failure."""
    return _ollama_embed(text, _OLLAMA_BASE_URL, _OLLAMA_MODEL)


def _crawl_files() -> list[Path]:
    return crawl_files(_repo_root(), _MEMORY_INDEX_PATH or None)


def _ensure_init() -> None:
    """Run first-call self-init sync if not yet done (ADR-011)."""
    global _first_call_done
    if _first_call_done:
        return
    _first_call_done = True
    idx_dir = _index_dir()
    idx_dir.mkdir(parents=True, exist_ok=True)
    try:
        run_sync(
            index_dir=idx_dir,
            repo_root=_repo_root(),
            embed_fn=_embed_text,
            model_name=_OLLAMA_MODEL,
            full=False,
            index_paths_env=_MEMORY_INDEX_PATH or None,
        )
    except Exception:
        # Self-init failure is non-fatal — server continues without a fresh index
        pass


# ---------------------------------------------------------------------------
# FastMCP app
# ---------------------------------------------------------------------------

mcp = FastMCP("speckit-memory")


@mcp.tool()
def memory_recall(
    query: str,
    top_k: int = 5,
    min_score: float = 0.5,
    filter: dict | None = None,
) -> dict[str, Any]:
    """Semantically search the index and return the most relevant chunks."""
    _ensure_init()

    try:
        query_vec = _embed_text(query)
    except (ConnectionError, OSError) as exc:
        return _api_unavailable(str(exc))

    query_vec = _l2_normalize(query_vec)
    idx_dir = _index_dir()
    idx_dir.mkdir(parents=True, exist_ok=True)
    table = init_table(idx_dir)

    f = filter or {}
    results = vector_search(
        table=table,
        query_vector=query_vec,
        top_k=min(top_k, 20),
        min_score=min_score,
        filter_type=f.get("type"),
        filter_feature=f.get("feature"),
        filter_tags=f.get("tags"),
    )
    return {"results": results, "total": len(results)}


@mcp.tool()
def memory_store(
    content: str,
    metadata: dict,
) -> dict[str, Any]:
    """Embed content and store it as a chunk (for skill-generated summaries)."""
    _ensure_init()
    try:
        raw_vec = _embed_text(content)
    except (ConnectionError, OSError) as exc:
        return _api_unavailable(str(exc))

    vec = _l2_normalize(raw_vec)
    chunk_id = str(uuid.uuid4())
    source_file = metadata.get("source_file", "synthetic")

    # Non-existent source_file path → synthetic=True
    is_synthetic = source_file == "synthetic" or not Path(_repo_root() / source_file).exists()

    idx_dir = _index_dir()
    idx_dir.mkdir(parents=True, exist_ok=True)
    table = init_table(idx_dir)

    chunk = {
        "id": chunk_id,
        "content": content,
        "vector": vec,
        "source_file": source_file,
        "section": metadata.get("section", ""),
        "type": metadata.get("type", "synthetic"),
        "feature": metadata.get("feature", ""),
        "date": metadata.get("date", datetime.now(tz=timezone.utc).date().isoformat()),
        "tags": metadata.get("tags", []),
        "synthetic": is_synthetic,
    }
    insert_chunks_batch(table, [chunk])
    return {"id": chunk_id, "status": "stored"}


@mcp.tool()
def memory_sync(
    full: bool = False,
    paths: list[str] | None = None,
) -> dict[str, Any]:
    """Re-index changed markdown files (or full rebuild if full=True)."""
    _ensure_init()
    idx_dir = _index_dir()
    idx_dir.mkdir(parents=True, exist_ok=True)

    try:
        return run_sync(
            index_dir=idx_dir,
            repo_root=_repo_root(),
            embed_fn=_embed_text,
            model_name=_OLLAMA_MODEL,
            full=full,
            paths=paths,
            index_paths_env=_MEMORY_INDEX_PATH or None,
        )
    except (ConnectionError, OSError) as exc:
        return _api_unavailable(str(exc))
    except Exception as exc:
        err_str = str(exc)
        if "connection" in err_str.lower() or "refused" in err_str.lower():
            return _api_unavailable(err_str)
        raise


@mcp.tool()
def memory_delete(
    source_file: str | None = None,
    id: str | None = None,
) -> dict[str, Any]:
    """Remove chunks by source_file (all) or by id (single). Exactly one required."""
    _ensure_init()
    if (source_file is None) == (id is None):
        return {
            "error": {
                "code": "INVALID_INPUT",
                "message": "Provide exactly one of source_file or id, not both or neither.",
                "recoverable": True,
            }
        }

    idx_dir = _index_dir()
    idx_dir.mkdir(parents=True, exist_ok=True)
    table = init_table(idx_dir)

    if source_file is not None:
        count = delete_chunks_by_source_file(table, source_file)
        # Also remove manifest entry
        manifest = load_manifest(idx_dir)
        manifest["entries"].pop(source_file, None)
        save_manifest(idx_dir, manifest)
        return {"deleted_chunks": count, "source_file": source_file}
    else:
        count = delete_chunk_by_id(table, id)
        return {"deleted_chunks": count, "id": id}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _api_unavailable(detail: str) -> dict[str, Any]:
    return {
        "error": {
            "code": "API_UNAVAILABLE",
            "message": f"Ollama embedding API unreachable: {detail}",
            "recoverable": True,
        }
    }


# ---------------------------------------------------------------------------
# Entry point (T019)
# ---------------------------------------------------------------------------

def main() -> None:
    mcp.run()


if __name__ == "__main__":
    main()
