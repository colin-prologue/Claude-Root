# MCP Tool Contracts: Memory Server

**Feature**: 002-vector-memory-mcp
**Date**: 2026-04-06
**Server**: `memory` (configured in `.mcp.json`)

> ⚠️ **Superseded in part — see LOG-059.** This document captures the tool surface
> as shipped in feature 002. Later features added parameters, response fields, and
> changed the error channel. When reading the current surface, consult these delta
> contracts **in addition to this file**:
>
> | Feature | Delta contract(s) | What changed |
> |---|---|---|
> | 003-memory-server-hardening | [`memory_recall.md`](../../003-memory-server-hardening/contracts/memory_recall.md), [`memory_store.md`](../../003-memory-server-hardening/contracts/memory_store.md), [`memory_delete.md`](../../003-memory-server-hardening/contracts/memory_delete.md) | Added `max_chars`, `filter_source_file`, `summary_only` inputs; added `token_estimate`, `budget_exhausted`, `truncated` response fields |
> | 006-ollama-fallback | [`tool-error-contract.md`](../../006-ollama-fallback/contracts/tool-error-contract.md) | Errors now raise `ToolError` (not envelope dicts); `summary_only` bypasses embedding (ADR-037); `synthetic` flag on result items |
> | 007-bm25-keyword-fallback | [`memory_recall.md`](../../007-bm25-keyword-fallback/contracts/memory_recall.md) | Added `degraded` flag on response envelope |
>
> Each delta contract above is self-contained for the field(s) it introduces. When
> implementing a client, merge the 002 baseline here with all active deltas.

These are the four stable tool contracts exposed by the memory MCP server. Skills and commands MUST use only these interfaces — no direct DB access.

---

## `memory_recall`

Semantically searches the index and returns the most relevant chunks for a query.

### Input

| Parameter | Type | Required | Description |
|---|---|---|---|
| `query` | string | Yes | Natural language query text |
| `top_k` | integer | No | Maximum results to return (default: 5, max: 20) |
| `min_score` | float | No | Minimum similarity score threshold (default: 0.5). Results below this score are excluded. See **Score semantics** below. |
| `filters` | object | No | Metadata filter (see below) |

**Filter schema** (all fields optional, AND-combined; multiple `tags` values require ALL to match):

```json
{
  "type": "adr | log | spec | constitution | synthetic",
  "feature": "002-vector-memory-mcp",
  "tags": ["tag1", "tag2"]
}
```

### Output

```json
{
  "results": [
    {
      "id": "uuid",
      "content": "text of the chunk",
      "score": 0.87,
      "source_file": ".specify/memory/ADR_008_lancedb-vector-backend.md",
      "section": "Decision",
      "type": "adr",
      "feature": "002-vector-memory-mcp",
      "date": "2026-04-06",
      "tags": []
    }
  ],
  "total": 1
}
```

### Score semantics

Scores are cosine similarity values (range 0–1, where 1 = identical). Ollama `nomic-embed-text` vectors are L2-normalised before storage so cosine similarity = dot product at query time. Scores are **not** comparable across Ollama model versions — switching models requires `memory_sync --full` (ADR-010).

The default `min_score` of **0.5** is a conservative starting point. Empirical calibration against the actual `.specify/memory/` corpus is recommended as a spike task before production use. A `min_score` of 0.7 is a reasonable target for high-precision recall; lower values increase recall at the cost of relevance.

### Behaviour

- Returns empty `results` array (not an error) when no result meets `min_score`
- Applies metadata `filters` before vector ranking (filters narrows the candidate pool)
- Triggers session-start sync on first call per process lifetime (ADR-011)

---

## `memory_store`

Embeds content and stores it as a chunk in the index. Used by speckit skills to persist command output summaries.

### Input

| Parameter | Type | Required | Description |
|---|---|---|---|
| `content` | string | Yes | Text to embed and store |
| `metadata` | object | Yes | Chunk metadata (see schema below) |

**Metadata schema**:

```json
{
  "source_file": "synthetic",
  "section": "Plan summary",
  "type": "synthetic",
  "feature": "002-vector-memory-mcp",
  "date": "2026-04-06",
  "tags": ["plan", "embedding-model"]
}
```

`source_file` must be `"synthetic"` for command-generated content or a valid repo-relative file path.

### Output

```json
{
  "id": "uuid",
  "status": "stored"
}
```

### Behaviour

- Generates a UUID for the chunk; returns it for caller reference
- Does not deduplicate by content — callers are responsible for not double-storing

---

## `memory_sync`

Re-indexes changed markdown files by comparing modification times against the manifest.

### Input

| Parameter | Type | Required | Description |
|---|---|---|---|
| `full` | boolean | No | If true, discard all chunks and rebuild from scratch (default: false) |
| `paths` | string[] | No | Limit sync to specific file paths (default: all configured paths) |

### Output

```json
{
  "indexed": 3,
  "skipped": 47,
  "deleted": 1,
  "duration_ms": 320,
  "model": "nomic-embed-text"
}
```

### Behaviour

- `full: false` (default): content hash diff against manifest (ADR-012); re-embeds only stale/new files; purges chunks for deleted files
- `full: true`: drops entire LanceDB table and manifest, re-indexes all configured paths
- Errors clearly if embedding model is unreachable (API down or Ollama not running)
- Errors with `MODEL_MISMATCH` if manifest records a different embedding model than current config; advises `full: true`

---

## `memory_delete`

Removes chunks from the index. Accepts either a `source_file` path (deletes all chunks for that file) or an `id` (deletes a single chunk by UUID). These are two distinct deletion semantics — use `source_file` for file lifecycle, use `id` for synthetic chunk management.

### Input

| Parameter | Type | Required | Description |
|---|---|---|---|
| `source_file` | string | No* | Repo-relative path of the file whose chunks should be deleted |
| `id` | string (UUID) | No* | UUID of a single chunk to delete (returned by `memory_store`) |

*Exactly one of `source_file` or `id` must be provided. Providing both or neither returns `INVALID_INPUT`.

### Output

```json
{
  "deleted_chunks": 4,
  "source_file": ".specify/memory/ADR_008_lancedb-vector-backend.md"
}
```

### Behaviour

- **By `source_file`**: deletes all chunks for that file; updates manifest to remove the entry; idempotent (returns `deleted_chunks: 0` if file has no chunks)
- **By `id`**: deletes the single chunk with that UUID; removes the chunk id from any file-synced manifest entry to prevent stale references
- Does not delete the source markdown file itself
- Synthetic chunks should always be deleted by `id` (the UUID returned by `memory_store`), not by `source_file = "synthetic"` which would affect all synthetic chunks project-wide

---

## Error Response Format

All tools return errors in a consistent envelope:

```json
{
  "error": {
    "code": "MODEL_MISMATCH | API_UNAVAILABLE | INVALID_INPUT",
    "message": "Human-readable description",
    "recoverable": true
  }
}
```

`recoverable: true` means the index is intact and prior recall still works. `recoverable: false` means the index may be in an inconsistent state and `memory_sync --full` is advised.
