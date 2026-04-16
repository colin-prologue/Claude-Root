# LOG-036: `httpx.TimeoutException` Escapes Current Exception Catch Clauses

**Date**: 2026-04-14
**Type**: CHALLENGE
**Status**: Resolved
**Raised In**: specs/006-ollama-fallback/spec.md — identified during adversarial spec review
**Related ADRs**: ADR-032, ADR-033

---

## Description

FR-004 requires that all Ollama calls time out within a configurable threshold (default 10 seconds). The current exception handling in `server.py` catches `(ConnectionError, OSError)`. The `httpx` library — used internally by the Ollama Python SDK — raises `httpx.TimeoutException` when a network call times out. `TimeoutException` is not a subclass of either `ConnectionError` or `OSError`, so it escapes all existing catch clauses and propagates as an unhandled exception. FR-004 is unimplementable with the current exception strategy.

## Context

Feature 006's core promise is "no call hangs or crashes when Ollama is unavailable." Timeout handling is the primary mechanism for preventing hangs. If the timeout fires but the resulting exception isn't caught, the tool crashes — which is the failure mode 006 is designed to eliminate.

## Discussion

### Pass 1 — Initial Analysis

Current catch clauses in `server.py` (lines 124, 210, 272):

```python
except (ConnectionError, OSError) as e:
    return _api_unavailable(...)
```

Python's `httpx` exception hierarchy (relevant subset):

```
Exception
└── httpx.HTTPStatusError        (HTTP 4xx/5xx responses)
└── httpx.TimeoutException       (connect, read, write, pool timeouts)
    └── httpx.ConnectTimeout
    └── httpx.ReadTimeout
    └── httpx.WriteTimeout
└── httpx.ConnectError           (connection refused, DNS failure)
    # Note: httpx.ConnectError IS a subclass of ConnectionError (Python built-in)
```

`httpx.ConnectError` (connection refused) IS caught by `except ConnectionError`. But `httpx.TimeoutException` is NOT — it's a sibling class, not a subclass. A configured timeout firing will always escape the current catch.

The Ollama SDK may also raise `ollama.ResponseError` for HTTP-level errors (e.g., model not found returns HTTP 404). This is also not caught by the current clauses and is needed for FR-003 (distinguishing "service unreachable" from "model not found").

### Pass 2 — Critical Review

This is a concrete, verifiable code fact, not a speculation. Any integration test that actually triggers a timeout (rather than a connection refusal) will reproduce it. The fix is well-defined.

### Pass 3 — Resolution Path

The catch clauses need to be extended to include:

```python
import httpx
import ollama

except (ConnectionError, OSError, httpx.TimeoutException, ollama.ResponseError) as e:
    if isinstance(e, ollama.ResponseError):
        # distinguish model-not-found from other errors
        ...
    return _api_unavailable(...)
```

Additionally, implementing FR-004 requires setting the timeout on the httpx client used by the Ollama SDK. The Ollama Python SDK likely accepts a `timeout` parameter on the client constructor or per-request. This needs to be verified and wired to the FR-005 environment variable.

The plan phase must include a task that: (1) verifies Ollama SDK timeout configuration, (2) extends catch clauses, (3) adds a test that triggers a real timeout.

## Resolution

Resolved in plan phase. Planned catch clauses: `(ConnectionError, OSError, httpx.TimeoutException, ollama.ResponseError)`.

**Implementation amendment (post-codereview, 2026-04-15)**: The code review (commit `dc28b8a`) widened the catch from `httpx.TimeoutException` to `httpx.TransportError` — the parent class that covers `TimeoutException`, `ReadError`, `WriteError`, and all other transport-level failures. The implemented catch clauses in `server.py` (lines 157, 229, 289) are:

```python
except (ConnectionError, OSError, httpx.TransportError, ollama_sdk.ResponseError) as exc:
```

`_embed_error` still uses `isinstance(exc, httpx.TimeoutException)` internally to produce the more specific "did not respond within Ns" message — correct because `TimeoutException ⊂ TransportError`. Non-timeout `TransportError` subclasses (e.g., `ReadError`) fall through to the generic `EMBEDDING_UNAVAILABLE` message.

Rationale: `httpx.TimeoutException` alone would miss mid-response failures (`ReadError`) and other transport errors that can occur when Ollama is degraded but not completely unreachable.

**Additional finding**: LOG-036 stated "`httpx.ConnectError` IS a subclass of `ConnectionError`" — this is FALSE (`issubclass(httpx.ConnectError, ConnectionError)` returns `False`). However, the ollama SDK's `_request_raw` wraps `httpx.ConnectError` as Python built-in `ConnectionError`, so the current catch clause works for connection refused.

**Resolved By**: inline fix; specs/006-ollama-fallback/plan.md § Changes 1–2; specs/006-ollama-fallback/research.md Findings 1–2; implementation widened to `httpx.TransportError` in commit `dc28b8a`
**Resolved Date**: 2026-04-14 (plan); 2026-04-15 (implementation amendment)

## Impact

- [x] Spec updated: `specs/006-ollama-fallback/spec.md` — FR-004 now includes prerequisite note about exception hierarchy gap; FR-003 extended to three error conditions
- [x] Plan updated: `specs/006-ollama-fallback/plan.md` — Changes 1 and 2 scope the fix; research.md Finding 1–2 detail the exception hierarchy
- [x] ADR created/updated: ADR-033 (MCP error channel strategy) covers the ToolError migration; ADR-037 is adjacent
- [x] Tasks revised: T014, T020, T021 specify `httpx.TimeoutException` — implementation used `httpx.TransportError` (broader; see amendment above)
