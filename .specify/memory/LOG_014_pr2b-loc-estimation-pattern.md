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

**Open — pattern confirmed (closure condition #1).** PR2b landed in 6 commits (4 TDD pairs across decide-next, emit-event, serialize) at the following actual diff sizes:

| Component | LOC | Notes |
|---|---|---|
| `run-decide-next.sh` (T017) | 134 | Pre-flight omission + sentinel fold-in + routing matrix + receipt mint |
| `run-emit-event.sh` (T018) | 251 | Receipt validation (run_id + verdict↔event mapping + input_hash recompute), JSON build via jq, append-then-truncate ordering, `verdict-mismatch` canonical write |
| `run-serialize.sh` (T019) | 264 | Two-branch invariant + truncation-tolerant sidecar parse + last-halt exemption + cold-start support |
| `run-common.sh` (shared anchor extract) | 42 | `_latest_routable_anchor` extracted to share recipe between decide-next and emit-event |
| **Helpers subtotal** | **691** | **vs. 600-LOC re-justification gate ⇒ overrun ratio 1.15×** |
| Tests (3 bats files, 62 cases) | 828 | TDD-mandated; ~13 LOC/case |
| Docs (LOG-025 + helper-contracts.md) | 66 | LOG-025 records halt-* sidecar deferral surfaced during T018 |
| **PR2b total** | **1585** | |

**The estimate was wrong even excluding tests.** The 500–600 budget was set after Re-Review #3's M-2 amendment but did not account for two further sources of LOC growth that surfaced only at implementation time:

1. **Verdict↔event mapping needed an explicit table** in `helper-contracts.md` and code (added during T018 — ADR-022 step 2 said "matches the verdict" without enumerating what that meant for each verdict family). The mapping table itself plus the per-verdict case in `run-emit-event.sh` ≈ 40 LOC not in the estimate.
2. **`halt-*` doc inconsistency** (ADR-022 vs sidecar-event.md) required LOG-025 + a rejection branch in `run-emit-event.sh` (8 LOC of code + 48 LOC of LOG-025). Surfaced only when implementation forced reconciling the two contracts.
3. **Bash 3.2 array-safety guards + trailing-newline-detect idiom** in `run-serialize.sh` ≈ 30 LOC of defensive scaffolding the estimate didn't price.

The **method failure** confirmed by this round: estimates were taken against contracts as written *at the time of the estimate*. Each subsequent ADR amendment OR each implementation-discovered contract gap added LOC that was never re-priced. The 600-LOC gate caught the overrun but only after the fact — it didn't prevent it.

This LOG remains open until **any one** of:

1. ✅ ~~PR2b implementation lands and the actual LOC count is recorded~~ — **done; documented above. Pattern confirmed: 691 helper LOC vs 600 gate.**
2. A subsequent feature triggers the same pattern (ADR amendment → unscheduled LOC growth in a constitutional-exception PR) — promotes this from "feature 010 anomaly" to "recurring failure mode."
3. The constitution is amended (or a successor LOG/ADR proposes amendment) to handle exception lifecycles around amendments AND/OR to require contract-completeness sweeps before LOC sizing.

**Resolved By**: TBD — candidates are (a) a constitution amendment requiring re-sizing on amendment, (b) a meta-ADR on exception lifecycle, or (c) closure-by-evidence if the pattern does not recur in subsequent features.
**Resolved Date**: N/A

## Impact

- [x] Plan referenced: `specs/010-autonomous-workflow/plan.md` PR2b paragraph (M-2 amendment + LOC re-derivation)
- [x] Tasks referenced: `specs/010-autonomous-workflow/tasks.md` PR2b sub-phase header (constitutional-exception note + 600-LOC re-justification gate)
- [ ] Spec updated: N/A (estimation concern, not a behavior concern)
- [ ] ADR created: deferred — see Resolution Pointers
- [ ] Constitution amended: candidate, not scheduled
