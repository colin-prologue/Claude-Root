# LOG-014: PR2b LOC Estimation Pattern — Three Upward Revisions Signal Method, Not Luck

**Date**: 2026-04-27
**Type**: CHALLENGE
**Status**: Open
**Raised In**: `specs/010-autonomous-workflow/plan.md` PR2b paragraph; `specs/010-autonomous-workflow/tasks.md` PR2b sub-phase header; plan-gate Re-Review #3 finding M-2 (`.specify/review/010-autonomous-workflow-plan.md` L588, L619)
**Related ADRs**: ADR-019 (deterministic orchestrator core), ADR-022 (verdict-receipt enforcement), Principle II (Simplicity — NON-NEGOTIABLE), PR Policy (300-LOC cap)

---

## Description

PR2b's LOC budget has been revised upward three times across review rounds:

| Pass | LOC budget | Driver |
|---|---|---|
| Initial plan | ~290 LOC | Original verdict-receipt triplet sizing (decide-next + emit-event + serialize) |
| Re-Review #1 / #2 | ~450 LOC (constitutional exception declared) | Helper interactions and bats coverage understated; exception justified per Principle II |
| Re-Review #3 (M-2) | **500–600 LOC** (supersedes prior 450) | ADR-022 amendments added Decision steps 5 (`verdict-omitted` refusal) and 6 (`pipeline-incomplete` two-branch invariant) after the 450 figure was set |

A 1.7×–2× overrun on a budget marked "constitutional exception" is not noise. The pattern signals the estimation **method** is wrong, not unlucky.

## Context

The 300-LOC PR cap (constitution PR Policy) is a hard governance constraint with explicit-justification escape valve (Principle II "complexity MUST be justified"). PR2b invokes that escape valve once. The unstated assumption when granting the exception was that the exception applied to a *known* size — a one-shot acknowledgement that the verdict-receipt protocol's correctness is unverifiable in helper isolation.

What actually happened: the exception was granted at 450 LOC, and a subsequent ADR amendment (ADR-022 steps 5/6 — strengthening the protocol from "structurally impossible bypass" to "structural detection of forgery + omission") expanded the helpers' decision surface without re-opening the exception decision. The plan.md PR2b paragraph absorbed the growth as a "supersedes prior 450 estimate" annotation rather than treating the amendment as a trigger to re-evaluate whether the exception still applies.

## Discussion

### Pass 1 — Initial Analysis

The mechanical fix is to update the LOC budget to match the helpers' new contract surface. Plan.md M-2 already did this (450 → 500–600 with re-derivation paragraph). That clears the immediate gate but does not address why estimation drifted in the same direction three times.

### Pass 2 — Critical Review

Three plausible root causes:

1. **Estimation under-counts test surface.** Each ADR-022 amendment added a new Tier 1 test case. At 15–20 LOC per bats case × 4 new cases (verdict-omitted refusal, pipeline-incomplete two-branch invariant, sentinel fold-in routing, completeness-invariant assertion), that is 60–80 LOC of growth per amendment that was not budgeted at amendment time.
2. **ADR amendments are not re-sized.** Plan.md treats ADR amendments as text edits to the relevant ADR file. None of the three reviews triggered a "re-sweep PR LOC budgets affected by this amendment" step. The PR-to-task mapping in tasks.md was last sized before ADR-022 step 6 landed.
3. **Constitutional exceptions accumulate slack.** Once a PR is marked an exception, subsequent growth is absorbed under the existing exception rather than reopening the justification. The exception becomes a cap-shaped variable rather than a one-shot annotation.

The deeper question Re-Review #3 deferred to this LOG: **should constitutional exceptions expire when their underlying ADR is amended?** A "yes" answer makes amendments expensive (forces re-justification) but keeps the exception honest. A "no" answer accepts that the exception is open-ended in scope and trusts the LOC re-derivation paragraph to bound it.

### Pass 3 — Resolution Path *(deferred)*

V1 resolution is partial: plan.md M-2 caps the current PR at 500–600 LOC with a "re-justify in PR description before merge if implementation lands above 600" gate. That bounds *this* exception but does not generalize.

The full resolution requires a constitution amendment (or LOG-graduating-to-ADR) answering whether constitutional exceptions auto-expire on amendment. That is out of scope for feature 010 and should be addressed at retrospective or in a separate constitutional review.

## Resolution

**Open.** V1 mitigation is the 600-LOC re-justification gate in plan.md PR2b. Long-term resolution requires deciding whether constitutional exceptions auto-expire when their underlying ADR is amended.

This LOG should be re-evaluated when **any one** of the following conditions is met:

1. PR2b implementation lands and the actual LOC count is recorded — confirms or refutes the 500–600 estimate.
2. A subsequent feature triggers the same pattern (ADR amendment → unscheduled LOC growth in a constitutional-exception PR) — promotes this from "feature 010 anomaly" to "recurring failure mode."
3. The constitution is amended (or a successor LOG/ADR proposes amendment) to handle exception lifecycles around amendments.

**Resolved By**: TBD — candidates are (a) a constitution amendment, (b) a meta-ADR on exception lifecycle, or (c) closure-by-evidence if the actual PR2b implementation lands at or below 600 LOC and the pattern does not recur.
**Resolved Date**: N/A

## Impact

- [x] Plan referenced: `specs/010-autonomous-workflow/plan.md` PR2b paragraph (M-2 amendment + LOC re-derivation)
- [x] Tasks referenced: `specs/010-autonomous-workflow/tasks.md` PR2b sub-phase header (constitutional-exception note + 600-LOC re-justification gate)
- [ ] Spec updated: N/A (estimation concern, not a behavior concern)
- [ ] ADR created: deferred — see Resolution Pointers
- [ ] Constitution amended: candidate, not scheduled
