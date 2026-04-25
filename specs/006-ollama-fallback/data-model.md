# Data Model: Ollama Fallback (006)

**Branch**: `006-ollama-fallback`
**Date**: 2026-04-14

## Overview

Feature 006 introduces no new data entities. The LanceDB schema and manifest format are unchanged.

The key behavioral changes are:

1. **Timeout-bounded embed calls** — `OLLAMA_TIMEOUT` env var (default 10s) limits all `_ollama_embed` calls.
2. **`scan_chunks` retrieval path** — non-vector chunk retrieval for `summary_only` mode.
3. **`_first_call_done` flag semantics** — flag set only after successful init (not before).

## Existing Entities (unchanged)

### Chunk (LanceDB row)

| Field | Type | Notes |
|---|---|---|
| `id` | string (UUID) | Primary key |
| `content` | string | Source text |
| `vector` | float32[768] | L2-normalized embedding |
| `source_file` | string | Relative path from repo root |
| `section` | string | Heading or synthetic label |
| `type` | string | `adr`, `log`, `constitution`, `spec`, `synthetic` |
| `feature` | string | Feature name from path |
| `date` | string (ISO) | File mtime or user-supplied |
| `tags` | string[] | Caller-supplied tags |
| `synthetic` | bool | True for skill-generated chunks |

### Manifest (manifest.json)

```json
{
  "version": "2",
  "embedding_model": "nomic-embed-text",
  "embedding_dimension": 768,
  "similarity_metric": "cosine",
  "entries": {
    "<rel_path>": {
      "hash": "<sha256>",
      "chunk_ids": ["<uuid>", ...]
    }
  }
}
```

No structural changes in 006.

## Conceptual States Added

### Embedding Availability State

Implicit, per-call. Not persisted.

| State | Condition | Server behavior |
|---|---|---|
| Available | `ollama.Client.embed()` returns within timeout | Normal embedding and indexing |
| Unavailable (not running) | `ConnectionError` | `ToolError("EMBEDDING_UNAVAILABLE: ...")` |
| Unavailable (timeout) | `httpx.TimeoutException` | `ToolError("EMBEDDING_UNAVAILABLE: ...")` |
| Unavailable (model missing) | `ollama.ResponseError(404)` | `ToolError("EMBEDDING_MODEL_ERROR: ...")` |
| Unavailable (bad URL) | `ValueError` from URL parse | `ToolError("EMBEDDING_CONFIG_ERROR: ...")` |

### Init State (`_first_call_done`)

Process-level flag. After fix (LOG-035):
- `False` → init not yet attempted, or last attempt failed
- `True` → init completed successfully at least once

## Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Ollama API endpoint |
| `OLLAMA_MODEL` | `nomic-embed-text` | Embedding model name |
| `OLLAMA_TIMEOUT` | `10` | Seconds before Ollama call fails (new in 006) |
| `MEMORY_INDEX_PATH` | _(glob patterns)_ | Files to index |
| `MEMORY_REPO_ROOT` | _(auto-detected from server.py location)_ | Repo root path; explicit override for out-of-tree deployments (LOG-057) |
