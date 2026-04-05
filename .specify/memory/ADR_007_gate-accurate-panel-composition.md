# ADR-007: Gate-Accurate Panel Composition for review-profile

**Date**: 2026-04-03
**Status**: Accepted
**Supersedes**: ADR-001 (for benchmark execution — ADR-001's STANDARD definition is superseded by gate-accurate composition)
**Decision Made In**: specs/000-review-benchmark/plan.md § Validity Model
**Related Logs**: None

---

## Context

The plan gate review (BLOCK-2) identified that `/speckit.review-profile` used a single
fixed STANDARD panel (`systems-architect + security-reviewer + devils-advocate`) for all
gates, while production `/speckit.review` uses gate-specific compositions. Benchmark
results from a fixed panel would not transfer to production review behavior, undermining
the benchmark's stated purpose.

ADR-001 defined STANDARD as a fixed composition for calibration comparison runs. This
was decided before the plan gate review surfaced the transferability problem.

## Decision

`/speckit.review-profile` MUST use the same gate-specific panel compositions as
`/speckit.review`. At each rigor level, the panel matches what the production command
would spawn for that gate.

Panel compositions per gate and rigor (mirroring `/speckit.review`):

**Spec gate:**
- FULL: product-strategist, security-reviewer, devils-advocate
- STANDARD: product-strategist, devils-advocate
- LIGHTWEIGHT: devils-advocate

**Plan gate:**
- FULL: systems-architect, security-reviewer, delivery-reviewer, devils-advocate
- STANDARD: systems-architect, delivery-reviewer, devils-advocate
- LIGHTWEIGHT: devils-advocate

**Task gate:**
- FULL: delivery-reviewer, systems-architect, operational-reviewer, devils-advocate
- STANDARD: delivery-reviewer, devils-advocate
- LIGHTWEIGHT: devils-advocate

The synthesis-judge is always added regardless of gate or rigor.

## Alternatives Considered

### Option A: Fixed panel across all gates *(rejected — was ADR-001's approach)*

**Pros**: Simpler command; consistent comparison baseline across gates.
**Cons**: Results do not transfer to production behavior; benchmark measures a proxy, not
the actual system. Identified as a validity threat in plan gate review (BLOCK-2).

### Option B: Gate-accurate panels *(chosen)*

**Pros**: Benchmark measures what the production system actually does; results directly
inform panel tuning decisions for real reviews.
**Cons**: More complex command logic; each gate has a different set of planted issues,
so the comparison across gates is less clean. Mitigated by gate-scoped scoring (ADR-006,
BLOCK-3 in plan gate review).

## Rationale

The benchmark's stated purpose is to "empirically measure whether changes to the review
panel improve signal quality." If the measured panel differs from the production panel,
the measurement is invalid for its purpose. A harder-to-build but valid benchmark is
worth more than an easy-to-build invalid one.

## Consequences

**Positive**: Benchmark results directly predict production behavior; panel tuning based
on benchmark data will transfer to actual review sessions.
**Negative / Trade-offs**: The benchmark command must encode all gate-specific panel
compositions from `/speckit.review`. If `/speckit.review` panel compositions change,
review-profile must be updated in sync.
**Risks**: Drift between the two commands if one is updated without the other. Mitigated
by noting this as a maintenance dependency in the command file.
**Follow-on decisions required**: ADR-001 is superseded for benchmark execution purposes.
Its STANDARD definition (systems-architect + security-reviewer + devils-advocate) is
retained as historical context but no longer governs command behavior.

## Consequences (amended)

**Why SR is dropped from plan/STANDARD but retained at plan/FULL**: Benchmark data (2026-04-03, 9 runs across 3 gates × 3 rigor levels) showed that at plan/STANDARD (SA+SR+DA, no DR), overlap rates were ~70% with SA and DA drifting into delivery concerns in DR's absence. SR's unique contribution at plan/STANDARD was 29% (2 unique findings of ~7 total) and SR generated the one false positive in the entire benchmark (FALSE-2, nullable column ADR — raised as MEDIUM without noticing the ADR-015 reference, withdrew in Phase B). SR's CRITICAL coverage at the plan gate (SEC-2) was also caught by SA and DA independently, making SR non-essential for CRITICAL coverage at STANDARD. At plan/FULL (all four specialists), SR's unique rate was 67% with genuinely distinct findings (race conditions, key namespace security, auth flow gaps); the SA+SR overlap at FULL was "Different angle — keep both" on shared topics. SR is retained at plan/FULL where the fuller context and DR's presence allows each agent to specialize.

**Why DR replaces SR as the second specialist at plan/STANDARD**: With DR present, SA can focus on architecture and infrastructure without drifting into delivery concerns. DR's unique rate at plan/FULL was 58% with 7 distinct findings covering TDD violations, dependency table gaps, and external gate requirements. This role differentiation collapses when DR is absent.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-03 | Initial record — supersedes ADR-001 for benchmark execution | speckit.review plan gate |
| 2026-04-03 | Dropped SR from plan/STANDARD; replaced with delivery-reviewer. Rationale: SR's 29% unique rate and one false positive at plan/STANDARD vs. DR's 58% unique rate and anchor effect on panel focus. SR retained at plan/FULL where unique rate was 67%. | /speckit.retro post-benchmark |
| 2026-04-04 | Updated task/FULL panel to include operational-reviewer (DR + SA + OR + DA). Both speckit.review.md and speckit.review-profile.md already reflected this; ADR entry was stale. | benchmark sync pass |
