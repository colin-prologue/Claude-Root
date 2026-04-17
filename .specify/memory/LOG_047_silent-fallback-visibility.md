---
name: LOG-047 — Silent fallback visibility gap
description: degraded:true is caller-only; nothing surfaces a broken Ollama install to operators beyond per-request stderr lines
type: project
---

# LOG-047: Silent Fallback Visibility Gap

**Date**: 2026-04-17
**Status**: Open — known gap, no fix scheduled
**Feature**: 007-bm25-keyword-fallback
**Related ADRs**: ADR-041 (fallback stderr warning)

---

## Observation

When Ollama becomes unavailable, `memory_recall` falls back to BM25 and:
1. Returns `degraded: true` in the response envelope (caller-visible)
2. Emits a stderr warning per fallback-activated request (operator-visible if tailing logs)

The per-request stderr warning (ADR-041) is the only operator signal. There is no:
- Aggregate counter or metric
- Health endpoint that reports "embedding service is down"
- Rate-limited warning (if Ollama is down for hours, warnings fire on every recall call)
- Distinction between "first fallback in an hour" vs "Ollama has been down for 6 hours"

## Impact

**Why:** For a solo developer CLI use case, per-request stderr is sufficient. If Ollama has been broken for days and the user hasn't noticed because BM25 results "look fine," there is no automated alert.

**How to apply:** If the memory server is ever deployed as a shared service or run headlessly, consider adding a simple counter or periodic health probe. Not needed for current usage.

## Potential Mitigations (future)

- Expose a `/health` endpoint that probes `_embed_text` and returns `{ollama: "down", fallback: "active"}` when unavailable
- Rate-limit the stderr warning to once per N requests or once per minute
- Track fallback-activation count as a session counter (reset on process restart)

## Status

Accepted as a known limitation of the current scope. Surfaced by `/speckit.codereview` Phase B.
