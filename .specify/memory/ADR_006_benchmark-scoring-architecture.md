# ADR-006: Benchmark Scoring Architecture

**Date**: 2026-04-03
**Status**: Accepted
**Decision Made In**: specs/000-review-benchmark/plan.md § Phase 0 Research
**Related Logs**: LOG_002_benchmark-isolation-strategy.md, LOG_003_benchmark-variance-strategy.md

---

## Context

Three interconnected scoring decisions needed to be made together:
1. Post-processing vs. command-embedded scoring (raised as MIN-4 in spec gate review)
2. How to implement "deterministic" scoring within an LLM-executed command (FR-006)
3. How to tag Phase A findings with agent names (FR-004)

## Decision

**Command-embedded** — the `/speckit.review-profile` command is an extension of the review
flow, not a post-processor. Scoring uses a structured table with mechanical criteria applied
row-by-row. Finding tagging uses agent-name prefixes in output rows.

## Alternatives Considered

### Option A: Post-processing approach

A separate step reads an existing synthesis output file from a standard `/speckit.review`
run and scores it against benchmark-key.md.

**Pros**: Measures unmodified review behavior; clean separation of measurement from review.
**Cons**: Cannot satisfy FR-004 (tagging before Phase B requires being active during Phase A)
or FR-005 (synthesis judge's overlap verdict tagging requires a modified Phase C prompt).
**Verdict**: Ruled out — technically blocked by spec requirements.

### Option B: Command-embedded *(chosen)*

The `/speckit.review-profile` command runs the full three-phase review with lightweight
additive modifications, then performs the scoring pass.

**Pros**: Satisfies FR-004 and FR-005; single workflow; no file coordination needed.
**Cons**: Profiled behavior differs slightly from unmodified review (additive only: agent-name
tag instruction, overlap verdict instruction for synthesis judge). The behavioral difference
is minimized by keeping modifications additive and non-substantive.

### Option C: LLM-based scoring (semantic judgment)

The scoring pass uses open-ended LLM judgment to match findings to planted issues.

**Pros**: More robust to varied finding framings; handles synonyms and paraphrases.
**Cons**: Introduces LLM non-determinism into the measurement instrument (identified in
CF-3 / LOG-003); runs counter to the spec's FR-006 "deterministic, rule-based" requirement.
**Verdict**: Ruled out by spec requirement.

## Scoring Rules (from FR-006)

Applied mechanically, row-by-row, for each planted issue:
1. Does any Phase A finding reference the correct artifact (spec/plan/tasks)?
2. If yes, does the finding describe the core problem area matching the planted issue?
3. Score: both → **Caught**; artifact match only → **Caught (partial)**; neither → **Missed**

Contamination check runs before scoring: any verbatim planted issue ID (e.g., `PROD-1`)
in a finding text → run flagged as contaminated, scoring aborted (FR-003).

## Finding Tagging (FR-004)

Each Phase A agent is instructed to prefix every finding row with `[AGENT_NAME]`. The
synthesis judge receives tagged output and uses it to build the overlap matrix. Simple,
no special parsing mechanism needed.

## Consequences

**Positive**: Satisfies all spec requirements; scoring is as deterministic as the rules allow.
**Negative / Trade-offs**: Profiled behavior differs marginally from unmodified review.
This is an acknowledged limitation (spec Assumptions section).
**Risks**: If scoring rules are ambiguous in edge cases, different Claude instances may score
differently. Mitigated by the explicit three-rule hierarchy.
**Follow-on decisions required**: None.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-03 | Initial record | speckit.plan |
