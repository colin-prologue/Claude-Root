# ADR-022: Budget Enforcement Algorithm (Greedy Top-Down Packing)

**Date**: 2026-04-09
**Status**: Accepted
**Decision Made In**: specs/003-memory-server-hardening/plan.md § Phase 0 Research
**Related Logs**: None

---

## Context

Feature 003 adds a `max_chars` parameter to `memory_recall`. When set, the total character count
across all returned chunk content must not exceed the specified value. The question is: given a
ranked list of up to 20 chunks, which algorithm selects the subset to include in the response?

Two competing goals:
1. Return the highest-quality (highest-scoring) chunks within the budget.
2. Keep the implementation simple — the result set is small (≤20 items after top_k enforcement).

## Decision

Use greedy top-down packing: iterate over chunks in score-descending order; include each chunk in
full if adding it would not exceed `max_chars`; drop it entirely if it would. Exception: if the
single highest-ranked chunk exceeds `max_chars` on its own, truncate it at exactly `max_chars`
characters and set `truncated: true` in the response envelope (truncation-of-last-resort, FR-004).
Set `budget_exhausted: true` in the response whenever any ranked chunk was dropped (FR-011).

## Alternatives Considered

### Option A: Greedy top-down packing *(chosen)*

O(n) scan over ranked results; greedy include/exclude.

**Pros**: Preserves ranking integrity — always returns the highest-scoring chunks that fit. Simple
to implement and test. Matches FR-003 acceptance scenario 1 specification exactly.
**Cons**: May leave budget partially unused if a mid-ranked chunk is too large to fit but a lower-
ranked smaller chunk would have fit. Accepted — ranking quality is preferred over budget utilization.

### Option B: 0/1 Knapsack optimization

Maximize total included content within `max_chars`.

**Pros**: Higher budget utilization.
**Cons**: Selects a different subset than the top-ranked results, breaking the "best results first"
guarantee. O(n × W) complexity, where W = max_chars — impractical for large budgets (e.g., 32,000).
Overkill for a ≤20 item set. Rejected.

### Option C: Partial chunk inclusion (split at budget boundary)

Include as much of each chunk as fits.

**Pros**: Zero budget waste.
**Cons**: FR-003 explicitly rejects partial inclusion except in the truncation-of-last-resort case.
Partial chunks degrade coherence — a split sentence is less useful than a dropped chunk. Rejected.

## Rationale

FR-003 acceptance scenario 1 specifies greedy top-down packing ("chunks are returned in ranked
order; greedy top-down packing until adding the next complete chunk would exceed the budget — that
chunk is dropped, not partially included"). The algorithm directly implements the spec without
interpretation. Ranking integrity is the primary guarantee; budget utilization is secondary.

## Consequences

**Positive**: Highest-scoring chunks always appear first. Simple to verify in tests (given a known
corpus and budget, the result is deterministic). `budget_exhausted` flag lets callers distinguish
full vs. partial result sets.
**Negative / Trade-offs**: May leave budget partially unused when a large mid-ranked chunk is
dropped and smaller lower-ranked chunks that would fit are also dropped. Callers who want maximum
content density should use `summary_only: true` for a two-pass approach.
**Risks**: Low. The truncation-of-last-resort edge case (FR-004) is unusual but must be tested
explicitly — a caller setting `max_chars` smaller than any single chunk's content will get a
truncated chunk, not an error.
**Follow-on decisions required**: None.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-09 | Initial record | /speckit.plan |
| 2026-04-12 | Clarified enforcement semantics: "drop it entirely" means stop-at-first-overflow (`break`), not skip-and-continue. Results are a contiguous top-N score prefix, never a sparse subset. See LOG-026. | /speckit.audit |
