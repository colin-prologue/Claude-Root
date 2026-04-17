# ADR-040: Fallback Results Include Normalized [0,1] Score Field

**Date**: 2026-04-16
**Status**: Accepted
**Decision Made In**: specs/007-bm25-keyword-fallback/spec.md § Clarifications (Q2 — 2026-04-16)
**Related Logs**: LOG_042_fallback-score-spec-replacement.md

---

## Context

Feature 007's BM25 fallback must return results. The semantic path (`vector_search`) always includes a `score` field (cosine similarity, [0,1]). The `scan_chunks` function (used by `summary_only`) returns raw rows with no `score` field.

The initial spec contained a contradiction: FR-008 said fallback results must include "score or equivalent," but the Key Entities section said the fallback score was "not exposed in the response; used only for ordering." Callers that read the `score` field for display or secondary ranking would get inconsistent behavior depending on which path ran.

## Decision

Fallback results MUST include a `score` field in each result dict, expressed as a normalized [0,1] float reflecting term-frequency keyword relevance. This is the same field name and value range as the semantic path's cosine similarity score.

## Alternatives Considered

### Option A: Normalized [0,1] score in `score` field (chosen)

Same field name, same value range as semantic results.

**Pros**: Callers don't need to check `degraded` before reading `score`; interface is consistent across paths; score can be used for display/ranking without mode awareness
**Cons**: Scores are not semantically comparable across modes (cosine similarity ≠ term frequency); callers may incorrectly compare them

### Option B: Omit score field in fallback results

Fallback result dicts have no `score` key.

**Pros**: No risk of callers comparing incomparable scores
**Cons**: Callers that read `score` get `KeyError` or `None` without `degraded` check; interface inconsistency forces mode-aware caller code

### Option C: Raw term-count integer as `score`

**Pros**: Transparent about what the score represents
**Cons**: Different type and scale than semantic score; harder for callers to normalize or display consistently

## Rationale

Option A was chosen because the overriding design goal is interface consistency: callers should be able to treat fallback and semantic results identically in their normal processing path. The `degraded: true` envelope flag already communicates quality reduction; the `score` field should not add additional per-field inconsistency. Incomparability of scores across modes is an acceptable caveat, documented here.

## Consequences

**Positive**: Consistent response interface; callers need no special-casing for score field
**Negative / Trade-offs**: Cosine similarity scores and term-frequency scores are not directly comparable; callers should not mix or average them across modes
**Risks**: Callers that interpret score magnitude as absolute quality may be misled — mitigated by `degraded: true` flag and this ADR
**Follow-on decisions required**: Implementation must define the normalization formula for term-frequency score (e.g., `matches / total_terms` capped at 1.0)

**min_score not applied in fallback path**: Because TF scores are not semantically comparable to cosine similarity, `min_score` thresholds (calibrated for cosine similarity values) MUST NOT be applied when the fallback path runs. Callers use `degraded: true` as the quality signal instead of score magnitude.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-16 | Initial record | Claude (speckit.clarify Q2) |
| 2026-04-17 | Added min_score skip clause to Consequences — decision was cited as ADR-040 in plan/tasks but was absent from this ADR's body | Claude (speckit.analyze remediation) |
