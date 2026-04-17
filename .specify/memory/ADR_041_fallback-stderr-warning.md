# ADR-041: BM25 Fallback Emits stderr Warning

**Date**: 2026-04-16
**Status**: Accepted
**Decision Made In**: specs/007-bm25-keyword-fallback/spec.md § Clarifications (Q3 — 2026-04-16)
**Related Logs**: None

---

## Context

When BM25 fallback activates, the response includes `degraded: true` — sufficient for callers (AI skills) to detect degraded mode programmatically. However, the server itself is silent: an operator tailing the process logs would see no signal that recall quality has dropped and Ollama needs attention.

The existing `_ensure_init` auto-sync already emits a stderr warning when it fails:
```
[speckit-memory] WARNING: auto-init sync failed: <exc>
```

The question is whether fallback activation should follow the same pattern.

## Decision

When the BM25 fallback path activates, the server MUST emit a warning to stderr:
```
[speckit-memory] WARNING: embedding unavailable — falling back to keyword search
```

This is consistent with the existing `_ensure_init` warning convention (FR-012).

## Alternatives Considered

### Option A: Emit stderr warning (chosen)

Consistent with existing `_ensure_init` warning pattern.

**Pros**: Operators monitoring process output see repeated fallback warnings; actionable signal that Ollama is down; no change to caller interface; zero cost when Ollama is healthy
**Cons**: Slightly noisy if Ollama is intentionally down for maintenance; adds a `print()` call per affected request

### Option B: Silent — `degraded: true` only

No stderr output; response flag is the only signal.

**Pros**: Callers that don't care about degraded mode aren't bothered
**Cons**: Invisible from operator perspective; "Ollama has been down for 3 hours" goes undetected until someone queries and notices `degraded` in the response

## Rationale

Option A was chosen for operational consistency. The `_ensure_init` precedent establishes that server-side warnings go to stderr. Callers (AI skills) detect fallback via `degraded: true`; operators detect it via the log line. Both audiences get an appropriate signal without coupling.

## Consequences

**Positive**: Operators can detect repeated fallback activation from process logs; consistent with existing warning pattern
**Negative / Trade-offs**: One `print()` per fallback-triggered request; no sampling or rate-limiting on the warning
**Risks**: Noisy during extended Ollama outages — acceptable for the corpus size (typically < 20 chunks returned); not a high-frequency path
**Follow-on decisions required**: None

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-16 | Initial record | Claude (speckit.clarify Q3) |
| 2026-04-17 | Documented that `httpx.TimeoutException` is a `TransportError` subclass and is therefore absorbed by the BM25 fallback handler in `memory_recall` before `_embed_error` is reached; the timeout-specific error message in `_embed_error` is unreachable from `memory_recall` (only reachable from `memory_store`/`memory_sync`). See LOG-046. Code comment at `server.py:166` cites this amendment. | Claude (speckit.audit) |
