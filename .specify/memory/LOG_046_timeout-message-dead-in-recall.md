---
name: LOG-046 — TimeoutException message unreachable in memory_recall
description: _embed_error's timeout branch is dead code in memory_recall context; only reachable from memory_store/memory_sync
type: project
---

# LOG-046: TimeoutException Timeout Message Unreachable in memory_recall

**Date**: 2026-04-17
**Status**: Accepted — documented, no action required
**Feature**: 007-bm25-keyword-fallback
**Related ADRs**: ADR-041 (fallback stderr warning), ADR-043 (in-process TF scoring)

---

## Observation

006-ollama-fallback added `OLLAMA_TIMEOUT` and a specialized timeout error message in `_embed_error`:

```
EMBEDDING_UNAVAILABLE: Ollama did not respond within {_OLLAMA_TIMEOUT}s.
Hint: check that Ollama is running and accessible at {_OLLAMA_BASE_URL}.
```

007-bm25-keyword-fallback added the BM25 fallback handler in `memory_recall`:

```python
except (ConnectionError, OSError, httpx.TransportError):
    _degraded = True  # network-layer only → BM25 fallback
```

Because `httpx.TimeoutException` is a subclass of `httpx.TransportError`, it is caught by this handler before `_embed_error` is ever called in the `memory_recall` code path. The specialized timeout message is **unreachable from `memory_recall`** — a user experiencing a slow/hung Ollama will receive `degraded: true` with no timeout-specific message in the response.

## Impact

**Why:** The fallback handler (ADR-041) intentionally absorbs timeout as a degradation trigger — this is consistent with "fail soft with no info" semantics where the BM25 result is correct behavior. The specialized error message is preserved and reachable from `memory_store` and `memory_sync`, which have no fallback path.

**How to apply:** This is accepted behavior for `memory_recall`. The code comment in `server.py::_embed_error` and in the fallback except clause documents this explicitly. No code change is needed.

## Decision

The dead branch in `_embed_error` is intentionally kept (not deleted) because it remains live from `memory_store` and `memory_sync`. A code comment documents the narrowed reachability from `memory_recall`. Surfaced by `/speckit.codereview` Phase B cross-examination.

## Alternatives Considered

- **Route timeouts through `_embed_error` before fallback**: Would preserve the specialized message but means memory_recall would raise ToolError for timeouts instead of falling back — contradicts ADR-041.
- **Delete the timeout branch from `_embed_error`**: Loses the specialized message for memory_store/memory_sync. Rejected.
- **Current: accept the dead path with comment**: Chosen. Matches ADR-041 fail-soft intent for memory_recall.
