# ADR-039: EMBEDDING_CONFIG_ERROR Does Not Trigger BM25 Fallback

**Date**: 2026-04-16
**Status**: Accepted
**Decision Made In**: specs/007-bm25-keyword-fallback/spec.md § Clarifications (Q1 — 2026-04-16)
**Related Logs**: None

---

## Context

Feature 007 adds BM25 keyword fallback to `memory_recall`: when Ollama is unavailable (`EMBEDDING_UNAVAILABLE`), the tool returns keyword-ranked results rather than a hard error. The existing error infrastructure (006) produces three distinct error codes: `EMBEDDING_UNAVAILABLE` (network failure/timeout), `EMBEDDING_MODEL_ERROR` (model not found), and `EMBEDDING_CONFIG_ERROR` (invalid `OLLAMA_BASE_URL` format).

The spec (FR-009) already excluded `EMBEDDING_MODEL_ERROR` from the fallback trigger. But it was silent on `EMBEDDING_CONFIG_ERROR`, creating an ambiguity: should a bad URL trigger fallback (and silently return results) or surface as a hard error?

Additionally, the existing `EMBEDDING_CONFIG_ERROR` message lacked a guarantee that it included the problematic value — making it hard for users to self-diagnose.

## Decision

`EMBEDDING_CONFIG_ERROR` MUST NOT trigger the BM25 fallback. It surfaces as a hard `ToolError` alongside `EMBEDDING_MODEL_ERROR`. The error message MUST include the actual bad URL value and an actionable hint naming `OLLAMA_BASE_URL` as the variable to fix.

## Alternatives Considered

### Option A: Hard error, no fallback (chosen)

`CONFIG_ERROR` is a misconfiguration. BM25 results don't fix a broken URL; they only mask the problem. Same treatment as `MODEL_ERROR`.

**Pros**: Misconfiguration is surfaced immediately; user knows what to fix; no silent degradation for an error that has a clear fix
**Cons**: Caller gets no results until config is corrected

### Option B: Trigger fallback

`CONFIG_ERROR` triggers BM25 like `EMBEDDING_UNAVAILABLE`.

**Pros**: Caller always gets something back
**Cons**: Silently masks a fixable misconfiguration; `degraded: true` gives no hint that the real fix is correcting the URL

## Rationale

Option A was chosen because `EMBEDDING_CONFIG_ERROR` is a local, fixable misconfiguration — not a transient availability failure. Falling back would delay the user discovering the problem. The actionable message requirement (FR-011) ensures the hard error is self-diagnosable: it includes the bad value and the env var name.

## Consequences

**Positive**: Misconfiguration surfaces immediately with an actionable message; no silent result degradation for fixable errors
**Negative / Trade-offs**: Callers get hard errors on config mistakes (same as before 007)
**Risks**: None — existing behavior preserved for this error code
**Follow-on decisions required**: None

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-16 | Initial record | Claude (speckit.clarify Q1) |
