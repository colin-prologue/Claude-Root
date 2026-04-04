# ADR-001: STANDARD Panel Composition

**Date**: 2026-04-02
**Status**: Accepted
**Decision Made In**: specs/000-review-benchmark/spec.md § Clarifications (Q3 — 2026-04-02)
**Related Logs**: None

---

## Context

The `/speckit.review-profile` command (and future `/speckit.review` rigor tuning) requires
three named panel compositions — FULL, STANDARD, LIGHTWEIGHT — to support calibration
comparison runs. LIGHTWEIGHT is unambiguous (devil's advocate only). FULL is unambiguous
(all six specialist agents). STANDARD was undefined: the constitution noted it as a
"reduced set" without specifying which agents to include or exclude.

Without an explicit definition, the benchmark command cannot determine which agents to
invoke at STANDARD rigor, and the calibration results would not be reproducible.

## Decision

STANDARD panel = `systems-architect` + `security-reviewer` + `devils-advocate`.

## Alternatives Considered

### Option A: systems-architect + security-reviewer (no DA)

Minimal technical coverage with no anti-convergence check.

**Pros**: Lowest token cost; fastest run.
**Cons**: No challenge layer — reviewers may converge without pressure; DA is the
primary source of cross-cutting issues in FULL runs.

### Option B: systems-architect + security-reviewer + devils-advocate *(chosen)*

Core technical reviewers plus the anti-convergence check.

**Pros**: Preserves the two highest-signal technical specialists; DA challenges both,
preventing premature consensus; drops product-strategist and delivery-reviewer whose
coverage overlaps meaningfully with DA challenges.
**Cons**: Loses product coverage (PROD-* planted issues may go uncaught at STANDARD) —
this is intentional and measurable via the benchmark.

### Option C: product-strategist + security-reviewer + devils-advocate

Product + security focus with DA.

**Pros**: Covers product gaps well.
**Cons**: Drops systems-architect, the primary catcher of ARCH-* issues — the most
common high-severity class in technical specs.

### Option D: Full panel minus devils-advocate

Broad specialist coverage without the challenger.

**Pros**: Wide domain coverage.
**Cons**: No anti-convergence mechanism; four agents with significant overlap risk.

## Rationale

Option B retains the two roles with the least domain overlap (architecture vs. security)
and adds the DA whose sole purpose is to challenge the others. Dropping product-strategist
and delivery-reviewer is a testable hypothesis: the benchmark will reveal whether PROD-*
and DEL-* issues are caught at STANDARD — if not, the composition can be revised based on
data rather than assumption.

## Consequences

**Positive**: STANDARD composition is reproducible and testable; calibration run results
are comparable across sessions.
**Negative / Trade-offs**: PROD-* planted issues (PROD-1, PROD-2) are likely to be missed
at STANDARD — this is the expected cost of reducing the panel and will be documented in
results.md.
**Risks**: If the benchmark shows unacceptable CRITICAL miss rates at STANDARD, the
composition must be revised (create a new ADR superseding this one).
**Follow-on decisions required**: After calibration runs complete, decide whether STANDARD
is the safe default for lower-stakes projects (to be documented in results.md, may
generate ADR-002).

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-02 | Initial record | speckit.clarify — Q3 |
