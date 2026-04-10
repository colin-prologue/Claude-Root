# LOG-015: Unimplemented Error Codes in MCP Tool Contract

**Date**: 2026-04-08
**Type**: UPDATE
**Status**: Open
**Raised In**: speckit.audit consistency audit — contracts/mcp-tools.md:181
**Related ADRs**: None

---

## Description

`contracts/mcp-tools.md:181` lists five error codes in the error envelope schema: `MODEL_MISMATCH`, `API_UNAVAILABLE`, `NO_EMBEDDER_CONFIGURED`, `INVALID_INPUT`, `INDEX_CORRUPT`. The implementation emits only three of these (`MODEL_MISMATCH`, `API_UNAVAILABLE`, `INVALID_INPUT`). `NO_EMBEDDER_CONFIGURED` and `INDEX_CORRUPT` are never produced by any code path.

## Context

These two codes appear to be design-time placeholders for failure modes that were anticipated but not implemented:

- `NO_EMBEDDER_CONFIGURED`: Originally relevant when the design considered multiple embedding backends (Voyage AI + Ollama). After ADR-010 locked in Ollama as the sole backend, the "no embedder configured" failure mode became moot — Ollama is always the embedder; if it's unreachable, `API_UNAVAILABLE` is returned instead.
- `INDEX_CORRUPT`: No code path detects or surfaces index corruption. LanceDB errors propagate as unhandled exceptions or are silently caught, never returning a structured `INDEX_CORRUPT` response.

## Discussion

### Pass 1 — Initial Analysis

Three options:
1. **Remove from contract**: Simplest. Callers should only expect codes the server actually emits. Overstating the error surface is misleading.
2. **Implement both codes**: Add detection logic for each failure mode. Higher effort; `INDEX_CORRUPT` in particular requires LanceDB-specific error introspection.
3. **Mark as reserved/future**: Document them as not-yet-emitted, preventing callers from relying on them while preserving the design intent.

### Pass 2 — Critical Review

`NO_EMBEDDER_CONFIGURED` has no future use case given the single-backend design (ADR-010). It should be removed. `INDEX_CORRUPT` has legitimate value — a corrupt Lance file is a real failure mode — but implementing it requires non-trivial error introspection and is out of scope for this feature.

## Resolution

Recommended: remove `NO_EMBEDDER_CONFIGURED` from the contract (no longer applicable), and either remove `INDEX_CORRUPT` or explicitly annotate it as a reserved future code. Decision deferred to contract cleanup pass.

**Resolved By**: N/A (open)
**Resolved Date**: N/A

## Impact

- [ ] Contract to update: specs/002-vector-memory-mcp/contracts/mcp-tools.md:181 — remove or annotate `NO_EMBEDDER_CONFIGURED` and `INDEX_CORRUPT`
