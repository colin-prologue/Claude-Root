# LOG-003: Benchmark Run Variance Strategy

**Date**: 2026-04-03
**Type**: QUESTION
**Status**: Resolved
**Raised In**: specs/000-review-benchmark/spec.md — spec gate review (CF-3)
**Related ADRs**: None

---

## Description

LLM agents are non-deterministic. The spec calls for one run per rigor level (three total).
A sample of one cannot distinguish signal from noise. How should the benchmark address
run-to-run variance when comparing FULL, STANDARD, and LIGHTWEIGHT results?

## Context

Surfaced by the devil's advocate (DA-A1/FM-1) during the spec gate review. The concern:
if the same agent catches different issues on different runs, the FULL vs. STANDARD comparison
could be measuring random variance rather than the effect of panel composition. SC-003's
recommendation would then be built on unreliable data.

Additionally: if the scoring pass (FR-006) is itself LLM-based, it introduces its own
non-determinism — the measurement instrument would be subject to the same variance as the
subject being measured.

## Discussion

### Pass 1 — Initial Analysis

Options:
1. Multiple runs per rigor level, average results — statistically sound but high cost.
2. Single run per condition, acknowledge limitation — fast but limited confidence.
3. Deterministic scoring — address the instrument variance even if agent variance remains.

### Pass 2 — Critical Review

For the initial calibration pass, statistical rigor is secondary to getting any data. The
benchmark's first purpose is to establish that the measurement infrastructure works and that
the planted issues are detectable at all. Requiring multi-run averages before first data exists
over-engineers the initial pass.

The scoring instrument is a separate concern from agent variance. Making FR-006 deterministic
(rule-based matching rather than LLM-based) costs little and eliminates one source of
non-determinism entirely. This was the higher-priority fix.

### Pass 3 — Resolution Path

Two-part resolution:
1. Specify FR-006 scoring as deterministic (rule-based: artifact section + core problem match).
   This eliminates instrument variance regardless of agent variance.
2. Explicitly acknowledge single-run limitation in Assumptions. Multi-run averaging is deferred
   to a future benchmark iteration once the basic infrastructure is validated.

## Resolution

FR-006 amended to specify deterministic scoring rules. Assumptions section updated to note
that single-run results are indicative, not statistically significant, and that multi-run
averaging is a known future improvement.

**Resolved By**: inline spec update — FR-006 amended, Assumptions updated
**Resolved Date**: 2026-04-03

## Impact

- [x] Spec updated: `specs/000-review-benchmark/spec.md` — FR-006 (deterministic scoring), Assumptions (variance caveat)
- [ ] Plan updated: N/A (pre-planning)
- [ ] ADR created/updated: None
- [ ] Tasks revised: N/A
