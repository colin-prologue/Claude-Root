# LOG-042: Spec Statement Replacement — Fallback Score Exposure

**Date**: 2026-04-16
**Type**: UPDATE
**Status**: Resolved
**Raised In**: specs/007-bm25-keyword-fallback/spec.md § Key Entities (speckit.clarify Q2 — 2026-04-16)
**Related ADRs**: ADR-040

---

## Description

The initial spec contained a contradictory statement in the Key Entities section that was replaced during clarification (Q2).

**Replaced statement**:
> Fallback score: A numeric relevance score computed from keyword matching, used to rank chunks in the absence of vector similarity. Not exposed in the response; used only for ordering.

**Replacement**:
> Fallback score: A normalized [0,1] numeric score reflecting term-frequency keyword relevance, included in the `score` field of each fallback result. Computed from query-term matches against `content` and `section`. (Q2 — 2026-04-16)

## Context

The initial spec was internally inconsistent: FR-008 said fallback results must include "score or equivalent," but Key Entities said the score was "not exposed." This was identified during the clarification scan as an ambiguity in the response contract.

## Discussion

### Pass 1 — Initial Analysis

`vector_search` always returns a `score` field. `scan_chunks` returns raw rows without one. The spec's FR-008 ("score or equivalent") was intentionally vague, but the Key Entities section contradicted it by saying the score was internal-only. Callers reading `score` on fallback results would get a `KeyError`.

### Pass 2 — Critical Review

The question is whether interface consistency (same `score` field in both paths) outweighs the risk of callers misinterpreting incomparable scores. Given that `degraded: true` already signals quality reduction, the `score` field inconsistency adds unnecessary caller complexity.

### Pass 3 — Resolution Path

Q2 resolved in favor of interface consistency: include the score in the same field, same [0,1] range. The spec was updated and the contradictory Key Entities statement was replaced. ADR-040 records the decision.

## Resolution

Spec Key Entities section updated to state that the fallback score IS exposed in the `score` field as a normalized [0,1] value. FR-008 tightened to enumerate all required fields explicitly. Contradictory "not exposed" statement removed.

**Resolved By**: ADR-040
**Resolved Date**: 2026-04-16

## Impact

- [x] Spec updated: specs/007-bm25-keyword-fallback/spec.md § Key Entities, § FR-008
- [ ] Plan updated: N/A (pre-plan)
- [x] ADR created/updated: ADR-040
- [ ] Tasks revised: N/A (pre-tasks)
