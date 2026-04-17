# ADR-044: ResponseError Does Not Trigger BM25 Fallback

**Date**: 2026-04-17
**Status**: Accepted
**Decision Made In**: specs/007-bm25-keyword-fallback/plan.md § After (007) exception handler
**Related Logs**: LOG-045 (ResponseError routing challenge, task-gate review M-2)

---

## Context

Feature 007 adds a BM25 fallback to `memory_recall` triggered when the embedding service is "unreachable or times out" (FR-001). The initial plan proposed splitting `ollama_sdk.ResponseError` handling by status code: 404 → `MODEL_ERROR` (hard error), all other `ResponseError` → fallback. This was rejected during task-gate review because Ollama can return HTTP 500 (model OOM), 400 (malformed request), and 401/403 (auth via proxy). These are server-side conditions, not "service unreachable" — routing them to keyword fallback would silently paper over real infra problems.

## Decision

All `ollama_sdk.ResponseError` instances are routed to `_embed_error()` as hard `ToolError` raises, regardless of status code. `_embed_error()` already handles the routing:
- `status_code == 404` → `EMBEDDING_MODEL_ERROR`
- All other status codes → `EMBEDDING_UNAVAILABLE` ToolError

Only true network-layer exceptions — `ConnectionError`, `OSError`, `httpx.TransportError` — trigger the BM25 fallback. These unambiguously mean the service is unreachable or the connection timed out.

Exception handler shape:
```python
except ollama_sdk.ResponseError as exc:
    raise _embed_error(exc, _OLLAMA_MODEL)   # ALL ResponseError → hard ToolError
except (ConnectionError, OSError, httpx.TransportError) as exc:
    _degraded = True                          # network-layer only → fallback
```

## Alternatives Considered

### Option A: Status-code split in handler *(rejected)*
Route 404 → `MODEL_ERROR`, non-404 `ResponseError` → fallback.

**Rejected because**: 500/400/401/403 from Ollama are not transient "service unreachable" conditions. A model-OOM 500 or auth 401 silently returning keyword results masks the underlying problem. The full set of non-404 status codes Ollama may return is not documented and should not be assumed transient.

### Option B: Whitelist specific transient status codes *(not chosen)*
Allow 503/504 to fall back; raise on all others.

**Not chosen because**: At the corpus scale of this project (50–200 chunks, local Ollama, solo dev), 503/504 are indistinguishable from connection-refused in practice. The added complexity of a status-code whitelist is not justified. Revisit if Ollama-as-service (remote) use case emerges.

## Rationale

The fallback trigger boundary should be "the network cannot reach the service." HTTP-layer errors mean the service was reached but returned a problem response — that problem should surface to the caller, not be silently absorbed by keyword fallback. The `degraded: true` signal loses meaning if it can also indicate "Ollama threw a 500."

## Consequences

**Positive**: Infra problems (OOM, auth, malformed requests) surface as ToolErrors rather than silently degrading to keyword results; fallback semantics remain unambiguous; handler is simpler (no status-code branching)
**Negative / Trade-offs**: A transient 500 from Ollama (e.g., brief model load spike) raises rather than falling back — caller gets an error instead of keyword results; acceptable at local solo-dev scale
**Risks**: If Ollama is ever used as a remote service returning 503, those will raise rather than fall back — revisit if remote Ollama use case emerges
**Follow-on decisions required**: None

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-17 | Initial record | Claude (speckit.review task-gate, M-2) |
