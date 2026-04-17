"""FastMCP server exposing four memory tools: recall, store, sync, delete."""
from __future__ import annotations

import json
import math
import os
import sys
import urllib.parse
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import httpx
import ollama as ollama_sdk

from fastmcp import FastMCP
from fastmcp.exceptions import ToolError

from speckit_memory.index import (
    delete_chunk_by_id,
    delete_chunks_by_source_file,
    init_table,
    insert_chunks_batch,
    keyword_search,
    load_manifest,
    maybe_create_index,
    save_manifest,
    scan_chunks,
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
_OLLAMA_TIMEOUT = float(os.environ.get("OLLAMA_TIMEOUT", "10"))
_MEMORY_INDEX_PATH = os.environ.get("MEMORY_INDEX_PATH", "")

# Process-lifetime first-call flag (ADR-011 self-init sync)
_first_call_done = False


def _repo_root() -> Path:
    """Return the repo root. Prefers MEMORY_REPO_ROOT env var when set.

    Falls back to two levels above server.py, which assumes the canonical
    layout: <repo>/memory-server/speckit_memory/server.py. Set the env var
    when installing the package outside its original monorepo location.
    """
    env = os.environ.get("MEMORY_REPO_ROOT", "")
    if env:
        return Path(env)
    return Path(__file__).parent.parent.parent


def _index_dir() -> Path:
    return _repo_root() / ".specify" / "memory" / ".index"


def _embed_text(text: str) -> list[float]:
    """Embed text via Ollama. Raises ToolError on config error; propagates network errors."""
    if urllib.parse.urlparse(_OLLAMA_BASE_URL).scheme not in ("http", "https"):
        raise ToolError(
            f"EMBEDDING_CONFIG_ERROR: OLLAMA_BASE_URL is not a valid HTTP/HTTPS URL "
            f"(got: {_OLLAMA_BASE_URL!r}). Hint: check the value of the OLLAMA_BASE_URL environment variable."
        )
    return _ollama_embed(text, _OLLAMA_BASE_URL, _OLLAMA_MODEL, _OLLAMA_TIMEOUT)


def _crawl_files() -> list[Path]:
    return crawl_files(_repo_root(), _MEMORY_INDEX_PATH or None)


def _ensure_init() -> None:
    """Run first-call self-init sync if not yet done (ADR-011)."""
    global _first_call_done
    if _first_call_done:
        return
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
        _first_call_done = True  # moved inside try — stays False if sync fails (LOG-035)
    except Exception as exc:
        # Self-init failure is non-fatal — server continues without a fresh index.
        # _first_call_done stays False so the next call will retry (LOG-035).
        print(f"[speckit-memory] WARNING: auto-init sync failed: {exc}", file=sys.stderr)


# ---------------------------------------------------------------------------
# FastMCP app
# ---------------------------------------------------------------------------

mcp = FastMCP("speckit-memory")


@mcp.tool()
def memory_recall(
    query: str,
    top_k: int = 5,
    min_score: float = 0.5,
    filters: dict | None = None,
    max_chars: int | None = None,
    filter_source_file: str | None = None,
    summary_only: bool = False,
) -> dict[str, Any]:
    """Semantically search the index and return the most relevant chunks."""
    if max_chars is not None and max_chars <= 0:
        return {
            "error": {
                "code": "INVALID_INPUT",
                "message": "max_chars must be a positive integer.",
                "recoverable": True,
            }
        }

    # LOG-038: skip _ensure_init on summary_only path — post-T007, _ensure_init retries
    # on every call when Ollama is down, adding ~10s latency to every summary_only call.
    if not summary_only:
        _ensure_init()

    idx_dir = _index_dir()
    idx_dir.mkdir(parents=True, exist_ok=True)
    table = init_table(idx_dir)
    f = filters or {}

    _degraded = False
    if summary_only:
        # ADR-037: table scan — no Ollama, no vector search
        raw = scan_chunks(
            table=table,
            top_k=min(top_k, 20),
            filter_type=f.get("type"),
            filter_feature=f.get("feature"),
            filter_tags=f.get("tags"),
            filter_source_file=filter_source_file,
        )
        results = [{"source_file": r["source_file"], "section": r["section"]} for r in raw]
    else:
        # Semantic path — Ollama required; BM25 fallback on network-layer failures (ADR-044)
        query_vec = None
        try:
            query_vec = _embed_text(query)
        except ollama_sdk.ResponseError as exc:
            raise _embed_error(exc, _OLLAMA_MODEL)  # all ResponseError → hard ToolError (ADR-044)
        # httpx.TransportError catches all transport-layer subclasses transitively:
        # ReadError, ConnectError, TimeoutException, etc. TimeoutException is a
        # TransportError subclass, so it is absorbed here and triggers BM25 fallback
        # rather than the specialized timeout message in _embed_error. That message
        # is only reachable from memory_store/memory_sync (ADR-041 amendment, LOG-046).
        except (ConnectionError, OSError, httpx.TransportError):
            _degraded = True  # network-layer only → BM25 fallback

        if _degraded:
            print(
                "[speckit-memory] WARNING: embedding unavailable — falling back to keyword search",
                file=sys.stderr,
            )
            results = keyword_search(
                table=table,
                query=query,
                top_k=min(top_k, 20),
                filter_type=f.get("type"),
                filter_feature=f.get("feature"),
                filter_tags=f.get("tags"),
                filter_source_file=filter_source_file,
            )
        else:
            query_vec = _l2_normalize(query_vec)
            results = vector_search(
                table=table,
                query_vector=query_vec,
                top_k=min(top_k, 20),
                min_score=min_score,
                filter_type=f.get("type"),
                filter_feature=f.get("feature"),
                filter_tags=f.get("tags"),
                filter_source_file=filter_source_file,
            )

    # T012/T013: Stop-at-first-overflow budget enforcement (ADR-022)
    budget_exhausted: bool | None = None
    truncated_flag: bool = False
    if max_chars is not None:
        packed: list[dict] = []
        chars_remaining = max_chars
        for item in results:
            item_len = len(json.dumps(item)) if summary_only else len(item["content"])
            if item_len <= chars_remaining:
                packed.append(item)
                chars_remaining -= item_len
            else:
                budget_exhausted = True
                break  # stop — do not consider subsequent chunks

        if not packed and results and not summary_only:
            # Truncation-of-last-resort: full-content mode only (FR-004).
            # Summary entries cannot be truncated; in summary mode return empty with budget_exhausted.
            first = dict(results[0])
            first["content"] = first["content"][:max_chars]
            truncated_flag = True
            packed = [first]
            budget_exhausted = True

        if budget_exhausted is None:
            budget_exhausted = False

        results = packed

    # T014: token_estimate (ADR-021): content chars in full mode; serialized entry size in summary mode
    if summary_only:
        total_chars = sum(len(json.dumps(r)) for r in results)
    else:
        total_chars = sum(len(r["content"]) for r in results)

    # T014: token_estimate always present (ADR-021)
    token_estimate = math.ceil(total_chars / 4)

    response: dict[str, Any] = {
        "results": results,
        "total": len(results),
        "token_estimate": token_estimate,
    }
    if budget_exhausted is not None:
        response["budget_exhausted"] = budget_exhausted
    if truncated_flag:
        response["truncated"] = True
    if _degraded:
        response["degraded"] = True
    return response


@mcp.tool()
def memory_store(
    content: str,
    metadata: dict,
) -> dict[str, Any]:
    """Embed content and store it as a chunk (for skill-generated summaries)."""
    try:
        raw_vec = _embed_text(content)
    except (ConnectionError, OSError, httpx.TransportError, ollama_sdk.ResponseError) as exc:
        raise _embed_error(exc, _OLLAMA_MODEL)

    vec = _l2_normalize(raw_vec)
    chunk_id = str(uuid.uuid4())
    source_file = metadata.get("source_file", "synthetic")

    if source_file != "synthetic":
        return {
            "error": {
                "code": "INVALID_SOURCE_FILE",
                "message": (
                    f"source_file must be 'synthetic'. Got {source_file!r}. "
                    "Only skill-generated synthetic content may be stored via memory_store. "
                    "Real source files are indexed via memory_sync."
                ),
                "recoverable": True,
            }
        }

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
        "synthetic": True,
    }
    insert_chunks_batch(table, [chunk])
    maybe_create_index(table)
    return {"id": chunk_id, "status": "stored"}


@mcp.tool()
def memory_sync(
    full: bool = False,
    paths: list[str] | None = None,
) -> dict[str, Any]:
    """Re-index changed markdown files (or full rebuild if full=True)."""
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
    except (ConnectionError, OSError, httpx.TransportError, ollama_sdk.ResponseError) as exc:
        raise _embed_error(exc, _OLLAMA_MODEL)


@mcp.tool()
def memory_delete(
    source_file: str | None = None,
    id: str | None = None,
) -> dict[str, Any]:
    """Remove chunks by source_file (all) or by id (single). Exactly one required."""
    # No _ensure_init() — delete never embeds; auto-sync-on-first-call not needed here (LOG-038)
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
        if (_repo_root() / source_file).exists():
            return {
                "error": {
                    "code": "PROTECTED_SOURCE_FILE",
                    "message": (
                        f"Cannot delete chunks for '{source_file}': the file still exists on disk. "
                        "Only synthetic chunks or chunks for removed files may be deleted this way. "
                        "Use memory_sync to re-index changed files."
                    ),
                    "recoverable": True,
                }
            }
        count = delete_chunks_by_source_file(table, source_file)
        manifest = load_manifest(idx_dir)
        manifest["entries"].pop(source_file, None)
        save_manifest(idx_dir, manifest)
        return {"deleted_chunks": count, "source_file": source_file}
    else:
        # Validate UUID format before touching the DB
        try:
            uuid.UUID(id)
        except ValueError:
            return {
                "error": {
                    "code": "INVALID_INPUT",
                    "message": f"id must be a valid UUID.",
                    "recoverable": True,
                }
            }
        count = delete_chunk_by_id(table, id)
        # Remove this chunk id from any file-synced manifest entry so the next
        # sync doesn't treat the file as unchanged when a chunk was deleted.
        manifest = load_manifest(idx_dir)
        changed = False
        for entry in manifest["entries"].values():
            chunk_ids = entry.get("chunk_ids", [])
            if id in chunk_ids:
                entry["chunk_ids"] = [cid for cid in chunk_ids if cid != id]
                changed = True
                break
        if changed:
            save_manifest(idx_dir, manifest)
        return {"deleted_chunks": count, "id": id}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _embed_error(exc: Exception, model: str) -> ToolError:
    """Return a categorized ToolError. Callers must use `raise _embed_error(...)` (ADR-033).

    NOTE: httpx.TimeoutException is a TransportError subclass. In memory_recall it is caught
    by the BM25 fallback handler before this function is called, so the timeout branch below
    is only reachable from memory_store and memory_sync (ADR-041 amendment, LOG-046).
    """
    if isinstance(exc, ollama_sdk.ResponseError) and getattr(exc, "status_code", None) == 404:
        return ToolError(
            f"EMBEDDING_MODEL_ERROR: model '{model}' is not available. "
            f"Hint: run `ollama pull {model}` to download the model."
        )
    if isinstance(exc, httpx.TimeoutException):
        return ToolError(
            f"EMBEDDING_UNAVAILABLE: Ollama did not respond within {_OLLAMA_TIMEOUT}s. "
            f"Hint: check that Ollama is running and accessible at {_OLLAMA_BASE_URL}."
        )
    return ToolError(
        f"EMBEDDING_UNAVAILABLE: Ollama is not reachable at {_OLLAMA_BASE_URL}. "
        f"Hint: run `ollama serve` to start the embedding service."
    )



# ---------------------------------------------------------------------------
# Entry point (T019)
# ---------------------------------------------------------------------------

def main() -> None:
    mcp.run()


if __name__ == "__main__":
    main()
