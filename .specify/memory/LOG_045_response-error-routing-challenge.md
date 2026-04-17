# LOG-045: ResponseError Routing Challenge — Hard Error vs Fallback at Task-Gate Review

**Date**: 2026-04-17
**Type**: CHALLENGE
**Status**: Resolved
**Raised In**: specs/007-bm25-keyword-fallback/plan.md — task-gate adversarial review (M-2)
**Related ADRs**: ADR-044

---

## Description

The initial implementation plan routed `ollama_sdk.ResponseError` by status code: `404` → `EMBEDDING_MODEL_ERROR` (hard error), all other `ResponseError` → BM25 fallback. The task-gate reviewer (M-2) challenged whether non-404 HTTP responses from Ollama should trigger the keyword fallback at all.

## Context

Feature 007's fallback trigger is defined as "embedding service unreachable or times out" (FR-001). The initial plan's exception handler caught all `ollama_sdk.ResponseError` except 404 in the fallback branch, on the assumption that any non-model-error response could represent a transient condition.

The task-gate review identified a critical gap: Ollama can return HTTP 500 (model OOM), 400 (malformed request), 401/403 (auth via proxy). These are server-side conditions where the service *was* reached but returned a problem response — not "service unreachable."

## Discussion

### Pass 1 — Initial Analysis

The plan split `ResponseError` handling:
- `status_code == 404` → `_embed_error()` → `EMBEDDING_MODEL_ERROR`
- All other `ResponseError` → set `_degraded = True`, fall back to keyword search

Rationale: 404 unambiguously means the model isn't loaded; other status codes might be transient.

### Pass 2 — Critical Review (M-2 finding)

The "might be transient" assumption is weak:
- HTTP 500 from Ollama (model OOM) is not transient in the same way connection-refused is; it likely needs operator action
- HTTP 401/403 via a proxy means auth is broken — keyword results silently paper over a security/config problem
- HTTP 400 means the request was malformed — returning fallback results would mask a client-side bug

More critically: the set of status codes Ollama may return is not fully documented and should not be assumed transient by enumeration.

The only unambiguous "service unreachable" signals are network-layer exceptions (`ConnectionError`, `OSError`, `httpx.TransportError`) — these are raised before any HTTP response exists.

### Pass 3 — Resolution Path

Route ALL `ollama_sdk.ResponseError` to `_embed_error()` as hard ToolError, regardless of status code. Only true network-layer exceptions trigger the fallback. This keeps the fallback semantics unambiguous: `degraded: true` means "could not reach the service," not "the service returned an error."

`_embed_error()` already handles routing: 404 → `EMBEDDING_MODEL_ERROR`, all other status codes → `EMBEDDING_UNAVAILABLE` ToolError. No status-code branching needed in the new handler.

## Resolution

Route all `ResponseError` to `_embed_error()` as hard errors. Only `(ConnectionError, OSError, httpx.TransportError)` trigger BM25 fallback.

**Resolved By**: ADR-044
**Resolved Date**: 2026-04-17

## Impact

- [x] Plan updated: `specs/007-bm25-keyword-fallback/plan.md` §After (007) exception handler — handler shape revised
- [x] Spec updated: `specs/007-bm25-keyword-fallback/spec.md` FR-009 — "all ollama_sdk.ResponseError instances MUST NOT trigger the BM25 fallback" added
- [x] ADR created/updated: ADR-044
- [x] Tasks revised: T003, T010 updated to reflect revised handler shape
