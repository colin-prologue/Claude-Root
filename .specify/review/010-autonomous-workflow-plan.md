# Review in Progress: 010-autonomous-workflow — plan gate (focused re-review)
**Started**: 2026-04-26T22:31:00Z
**Phase**: REVISE applied (min+ideal); ready for /speckit.tasks
**Panel**: systems-architect, delivery-reviewer, devils-advocate, synthesis-judge
**Rigor**: STANDARD (gate-default; no Project Context in constitution)
**Scope**: Focused re-review of the 11 files changed in revision (see prior synthesis below).

---

## Prior Review Outcome (2026-04-26 earlier)
Gate decision was REVISE with 5 blockers (C-1..C-4, S-1). Revisions applied:
- New: ADR-022 (verdict-receipt), ADR-023 (pre-route postcheck), LOG-010/011/012
- Amended: ADR-016 (MUST-coalesce halt/abort), ADR-019 (verdict-receipt + postcheck codified), ADR-021 (halt fixture + corrected cost), data-model.md (review-contiguity grammar; code-action destructive vs additive), helper-contracts.md (verdict-receipt protocol; new helpers run-common/run-postcheck/run-serialize), plan.md (4-PR split; helper list expanded)

This re-review evaluates whether the revisions actually close the blockers and whether they introduce new defects.

---

## Phase A: systems-architect

**Risk: LOW (net improvement).** All five blockers CLOSED.

- F-01 MED: `run-postcheck.sh` calls `check-prerequisites.sh`; that script's interface and stage-awareness undocumented for new caller. Confidence 75%.
- F-02 MED: Abort sentinel path may emit `abort` event without a prior `run-decide-next.sh` invocation, but `abort` is in the receipt-required set. Either move sentinel-abort out of receipt set or require decide-next on sentinel path. Confidence 80%.
- F-03 LOW: 4-PR estimates sum to ~1160 LOC, but plan elsewhere states ~1850 total. ~700 LOC of bats coverage unaccounted in per-PR figures. Confidence 85%.
- F-04 LOW: `run-postcheck.sh` exit code 2 conflates "usage error" with "required linter unavailable"; orchestrator response to non-zero non-1 exits unspecified. Confidence 70%.
- F-05 LOW: `run-target.sh validate` rejection of review adjacent to code-action stage needs a UX-friendly diagnostic pointing developer to BLOCKING-checkpoint. Confidence 90%.

**Dissent**: ADR-022 claims "bypass structurally impossible" — true for forged emission, false for the LLM precomputing the route then calling the helper to rubber-stamp. The receipt closes *undetected* bypass; it does not close sophisticated rubber-stamp. Should be reframed as structural improvement, not impossibility.

## Phase A: delivery-reviewer

**Risk: MEDIUM.** Blockers: C-1 CLOSED, C-2 CLOSED, C-3 CLOSED, C-4 CLOSED, S-1 PARTIALLY CLOSED.

- F-01 MED: `check-prerequisites.sh` is `cwd`-/branch-driven (sources common.sh, no `--feature-dir` flag). `run-postcheck.sh <feature-dir>` interface mismatch — needs flag-add task or `cd` workaround.
- F-02 MED: PR1 LOC undercounted. Realistic helper LOC 240–370 + bats 150–250 = **390–620 LOC**, not claimed 280. Splits into PR1a/PR1b.
- F-03 MED: PR2 LOC undercounted. Helpers 260–380 + bats 150–200 = **410–580 LOC**, not claimed 290. Same breach risk.
- F-04 LOW: FR-022 vapor residue — `test_clarification_serial.bats` listed but no helper-contract clause expresses how serial-clarification is enforced (in run-decide-next.sh? run-target.sh?).
- F-05 LOW: ADR-016 says orchestrator does not append canonical entries during stage execution; `run-emit-event.sh` writing `verdict-mismatch` to canonical log violates that text. Needs ADR-016 amendment to acknowledge exception.
- F-06 LOW: `quickstart.md` halt-class table missing `postcheck-failed` row.

**Critical TDD gap**: `run-postcheck.sh` has no `test_postcheck.bats` listed. Helper composes 2 external scripts + git command — bats coverage requires explicit mocking design that hasn't been planned.

## Phase A: devils-advocate (FULL rigor)

**Reframe verdict — RELABELED, not closed.** ADR-022 catches *forgery* of route events; it does not catch *omission*. If the LLM invokes `run-decide-next.sh` (writes receipt) then never invokes `run-emit-event.sh` and proceeds in prose to dispatch the next subagent, the receipt sits on disk unconsumed, the next acquire wipes it, no `verdict-mismatch` is ever written. The smoke-tier check ("zero verdict-mismatch on green path") has the *same signature* on a clean run and a fully-bypassed run. Confidence 85%.

7 new assumptions, most RISKY:
1. Slash-command markdown invokes helpers in prescribed order — same prose-trust ADR-019 said it would not depend on. RISKY.
2. `check-prerequisites.sh`/`check-adr-crossrefs.sh` are themselves complete enough to be load-bearing audit primitives. RISKY.
3. LLM-rendered BLOCKING-checkpoint payload faithfully includes postcheck findings. RISKY.
4. `run-lock.sh acquire` reliably wipes verdict + sweeps tmp. PLAUSIBLE.
5. `run_id` source for receipt unspecified — if derivable from lock file, LLM can forge as easily as invoke. PLAUSIBLE.
6. `.tmp` sweep on acquire silently destroys reasoning from a crashed prior run. PLAUSIBLE.
7. PR3 fits 290 LOC with `speckit.run.md` (5–17KB typical orchestrator length) + integration bats. RISKY.

**Catastrophic failure mode the revisions enabled**: false oversight from "✓ all pre-checks passed" prompt. Pre-revision: developer told "review the diff" (honest). Post-revision: developer told all checks passed; rubber-stamp likelihood increases because prompt is more confident. LOG-011 acknowledges this and chooses to ship anyway with SC-008 measurement — but "you don't get to dogfood your way out of a known mode of audit-substrate contamination on a tool that builds itself."

**The thing the team did not address**: no Tier 1 test that mechanically asserts `speckit.run.md` invokes helpers in prescribed order (postcheck → decide-next → emit-event for code-action; decide-next → emit-event otherwise). Static text-grep test, ~20 lines. Without it, a future LLM editing the orchestrator markdown can silently break invocation order; smoke tier won't catch it (wrong polarity).

**Strongest standalone objection**: add Tier 1 invariant — for every route/stage-skip/abort/halt-* verdict, a corresponding sidecar event MUST exist in `.run/control-flow.log` before next dispatch. Orchestrator refuses to dispatch next subagent if prior stage verdict has no matching sidecar entry. Symmetric check that closes the omission gap.

**Alternative reframe**: collapse the 7 helpers into a single `run-stage.sh <feature-dir> <stage>` super-helper that internally calls postcheck → decide-next → emit-event in one bash process. Slash command's only routing responsibility is "call run-stage.sh, read stdout, dispatch or halt." Keeps the 7 helpers as internal functions for testability; makes invocation order load-bearing-by-construction not by-prompt. 60% confidence dogfooding would surface a missing-helper bypass within 30 days.

---

## Phase B: Devil's Advocate Consensus Challenge

**Gate verdict**: REVISE-narrow (75%).

- **CON-1 (PR LOC)**: GENUINE, MEDIUM (80%). Sys-arch's LOW wrong because constitution's 300 LOC is hard gate; mid-stream re-decomposition destabilizes tasks.md. Delivery's MED correct.
- **CON-2 (check-prerequisites interface)**: GENUINE, MEDIUM (90%). cd workaround breaks on sentinel re-runs / --resume from different branches. Plan-level fix required.
- **CON-3 (ADR-022 overclaims)**: GENUINE and UNDER-RATED (85%). Sys-arch and DA converged from different angles, strengthens finding. Receipt is forgery-prevention mislabeled as rubber-stamping prevention.

Uncovered triage:
- **U1 (no test_postcheck.bats)**: LOAD-BEARING — REVISE.
- **U2 (FR-022 vapor)**: TASK-PHASE — defer.
- **U3 (sentinel-abort ordering)**: LOAD-BEARING — REVISE (invariant unsatisfiable on a known path).
- **U4 (ADR-016 verdict-mismatch contradiction)**: LOAD-BEARING — REVISE (Principle VII drift exactly).
- **U5 (quickstart halt-class row)**: TASK-PHASE — defer.

Reframes reaffirmed: verdict-receipt = forgery prevention only; slash-command markdown remains unaudited weak link (no reviewer engaged with `speckit.run.md` in Phase A — itself a blind spot).

## Phase B: systems-architect Response

**Revised overall risk: LOW → MEDIUM.**

1. Omission-vs-forgery distinction is architecturally real. Receipt closes forgery reliably; omission produces sidecar with no route event for affected stage. F-02 expanded scope (sentinel-abort + omission compose into same window).
2. Static-grep Tier 1 invariant (DA's proposal) accepted. Brittle to helper rename, but rename is a structural change that should require explicit test maintenance. **NEW MEDIUM finding**: PR3 must add 20-LOC bats test grepping `speckit.run.md` for sequence-ordered helper invocations.
3. **`run-stage.sh` super-helper REJECTED for V1**: trades testability + composability (LOG-005 stage-pair-runner reuse) for slash-command cleanliness. Decision worth recording — V2 ADR candidate.
4. Concrete recommendation: add **symmetric sidecar completeness check** — after `run-emit-event.sh` consumes receipt, assert consumed verdict + written sidecar event present as pair. Closes omission gap in Tier 1 without requiring run-stage.sh.
5. F-02 not withdrawn, expanded; F-03 still LOW (sys-arch defers PR-LOC severity to delivery).

## Phase B: delivery-reviewer Response

**Revised overall risk: MEDIUM → HIGH.**

1. **C-1 verdict UPGRADED to HIGH**: ADR-022 does not specify what happens when `run-emit-event.sh` is invoked with NO receipt present (missing/empty `last-verdict`). If exits non-zero → omission caught. If exits zero with warning → not caught. Spec silent. Confidence 82%. Requires ADR-022 amendment (missing-receipt = mismatched-receipt = exit non-zero, refuse emission) before tasks cut.
2. Static-grep test belongs in PR3 (~20 LOC, fits). Accepted.
3. **`run-stage.sh` super-helper REJECTED**: 300–400 LOC single-concern violation; harder Tier 1 testing; four independently mergeable helpers become one shippable unit. Worsens PR-LOC concern.
4. Rubber-stamp UX (LOG-011) acceptable as framed, BUT ADR-020 sidecar lacks `prompt_shown_ts`/`proceed_ts` fields that LOG-011's SC-008 measurement requires. Task-level gap, not plan-level — must appear as explicit task.
5. **PR3 LOC implausible at realistic `speckit.run.md` length** (5–17KB / 300–1000+ LOC typical). 250 LOC estimate unsupported. **F-02 elevated to HIGH** + PR3 must split PR3a (helpers) / PR3b (slash command + integration tests) OR enforce hard length constraint on slash-command via linter.
6. **F-04 (FR-022 vapor) ELEVATED to HIGH**: plan still does not identify which helper owns FR-022 logic. Unanchored test file is delivery risk (vacuous test or test of nonexistent code path).

Two blocking items before tasks: ADR-022 amendment (missing-receipt branch); PR3 split.

---

## Phase C: Synthesis Report

### Executive Summary
The revisions closed 4 of 5 prior blockers cleanly (C-2, C-3, C-4, S-1) but C-1 was **relabeled, not closed**: ADR-022's verdict-receipt prevents *forgery* of route events, not *omission* of them. All three reviewers converged on this from independent angles. Two new HIGH-severity defects surfaced (PR3 LOC implausibility; missing-receipt semantics undefined in ADR-022), and one critical blind spot — `speckit.run.md` slash-command markdown — was not engaged by any Phase A reviewer. **Recommendation: REVISE-narrow.** Two surgical fixes unblock the gate; broader concerns defer to tasks/code review.

### Cross-Panel Consensus (post-Phase B)

| ID | Severity | Finding | Reviewers | Action |
|---|---|---|---|---|
| C-1 | HIGH | ADR-022 verdict-receipt closes forgery, not omission. If LLM calls `run-decide-next.sh` then skips `run-emit-event.sh`, receipt sits unconsumed; next `run-lock.sh acquire` wipes it; smoke-tier check has identical signature on clean and bypassed runs. | sys-arch + delivery + DA | Amend ADR-022 + add symmetric completeness check |
| C-2 | HIGH | ADR-022 silent on `run-emit-event.sh` invoked with no/empty receipt. Determines whether omission is caught or swallowed. | delivery + DA (sys-arch concurs) | Amend ADR-022: missing-receipt ≡ mismatched-receipt → non-zero exit, refuse emission |
| C-3 | HIGH | PR3 LOC estimate (290) implausible. `speckit.run.md` slash commands typically 5–17KB / 300–1000+ LOC; integration bats adds more. | delivery (escalated) + DA (RISKY assumption #7) + sys-arch (F-03 LOW but defers to delivery) | Split PR3a (helpers) / PR3b (slash command + integration); OR enforce hard linter length cap |
| C-4 | MEDIUM | `run-postcheck.sh` calls `check-prerequisites.sh` whose interface is `cwd`/branch-driven, no `--feature-dir` flag. Cd-workaround breaks on sentinel re-runs / `--resume` from different branches. | sys-arch F-01 + delivery F-01 + DA assumption #2 | Add `--feature-dir` flag to `check-prerequisites.sh` (helper-contracts.md task) |
| C-5 | MEDIUM | Sentinel-abort path emits `abort` (in receipt-required set) without a prior `run-decide-next.sh` invocation. Invariant unsatisfiable on a known path. | sys-arch F-02 + DA U3 | Either remove `abort` from receipt set OR require decide-next on sentinel path |

> **Context (C-1):** The plan adds ADR-022 to make orchestrator bypass detectable: `run-decide-next.sh` writes a `last-verdict` receipt, `run-emit-event.sh` consumes it and writes a `verdict-mismatch` event if they disagree. This catches an LLM forging a route event. It does not catch an LLM that calls `run-decide-next.sh` honestly, then quietly skips `run-emit-event.sh` and dispatches the next subagent in prose — the receipt is wiped on next lock acquire and no mismatch event is ever written. The smoke-tier "zero verdict-mismatch on green path" assertion is true in both cases.

> **Recommendation:** Amend ADR-022 to add a *symmetric completeness invariant*: every `route` / `stage-skip` / `abort` / `halt-*` decision MUST have a matching sidecar event in `.run/control-flow.log` before the next dispatch. Add Tier 1 bats test that asserts `run-emit-event.sh` exits non-zero when invoked with missing/empty receipt. Add Tier 1 static-grep test (DA proposal, ~20 LOC) verifying `speckit.run.md` invokes helpers in prescribed order.

### Single-Reviewer Findings That Survived Phase B

| ID | Severity | Finding | Reviewer |
|---|---|---|---|
| S-1 | MEDIUM | No `test_postcheck.bats` listed despite `run-postcheck.sh` composing 2 external scripts + git. | delivery |
| S-2 | MEDIUM | ADR-016 says orchestrator does not append canonical entries during stage execution; `run-emit-event.sh` writing `verdict-mismatch` to canonical log violates that text. | delivery (DA U4 concurs) |
| S-3 | MEDIUM | FR-022 vapor residue: `test_clarification_serial.bats` listed, but no helper-contract clause expresses where serial-clarification logic lives. | delivery + DA |
| S-4 | MEDIUM | LOG-011 SC-008 rubber-stamp UX measurement needs `prompt_shown_ts`/`proceed_ts` fields not present in ADR-020 sidecar schema. | delivery |
| S-5 | LOW | `run-postcheck.sh` exit code 2 conflates "usage error" with "linter unavailable"; orchestrator response unspecified. | sys-arch |
| S-6 | LOW | `run-target.sh validate` rejection of code-action-adjacent review needs UX-friendly diagnostic. | sys-arch |
| S-7 | LOW | `quickstart.md` halt-class table missing `postcheck-failed` row. | delivery |

### Recommended Records
- **Amend ADR-022**: add missing-receipt semantics (non-zero exit, refuse emission); reframe from "structurally impossible bypass" to "structural detection of forgery + omission"; add symmetric sidecar completeness invariant.
- **Amend ADR-016**: acknowledge `verdict-mismatch` as the one orchestrator-written canonical entry (Principle VII drift fix).
- **Amend ADR-020**: add `prompt_shown_ts` / `proceed_ts` fields required for SC-008 measurement.
- **New LOG-013** (rubber-stamp dogfooding risk): record DA's objection that "✓ all checks passed" prompt is strictly worse than pre-revision honest signal; explicit kill-switch criterion if SC-008 shows degradation.
- **New ADR candidate (V2)**: `run-stage.sh` super-helper. Unanimously rejected for V1; record decision now to prevent re-litigation.

### Preserved Dissent
- **DA**: `speckit.run.md` is unaudited weak link. No Phase A reviewer engaged with the slash-command markdown itself — a blind spot that Tier 1 static-grep partially mitigates but does not eliminate.
- **DA**: "✓ all checks passed" prompt is strictly worse than the pre-revision honest signal. Shipping anyway via SC-008 is dogfooding-as-validation on the very tool that builds itself; this is not a closed risk.
- **Sys-arch**: ADR-022 should be reframed as *structural improvement*, not *structural impossibility*. Marketing-language bug.
- **Delivery**: PR-LOC framing is not a style preference — constitution's 300 LOC is a hard gate; mid-stream re-decomposition destabilizes tasks.md ordering.
- **Sys-arch (rejected by delivery)**: `run-stage.sh` super-helper has architectural appeal for V2 but is correctly rejected for V1 on testability + PR-LOC grounds.

### Gate Recommendation: **REVISE-narrow**

### Blockers (must close before `/speckit.tasks`)
1. **C-1**: Amend ADR-022 with symmetric sidecar completeness invariant + Tier 1 omission/static-grep tests defined.
2. **C-2**: Amend ADR-022 with missing-receipt semantics (non-zero exit, refuse emission).
3. **C-3**: Split PR3 into PR3a (helpers) / PR3b (slash command + integration), OR add hard linter length cap on `speckit.run.md` with explicit budget.
4. **C-4**: Add `--feature-dir` flag to `check-prerequisites.sh` in helper-contracts.md and as explicit task.
5. **C-5**: Resolve sentinel-abort vs receipt-required set (remove `abort` from set OR require decide-next on sentinel).
6. **S-2**: Amend ADR-016 to acknowledge `verdict-mismatch` exception (Principle VII).

### Acceptable to defer (task phase or code review)
- S-1 `test_postcheck.bats` (add as explicit task in tasks.md)
- S-3 FR-022 helper anchor (resolve in tasks.md)
- S-4 ADR-020 timing fields (add as task; depends on whether SC-008 is V1 scope)
- S-5/S-6/S-7 (UX polish; code review or task-level)

### Re-review scope (smallest reasonable changed-surface)
If revisions land per blocker list: re-review **ADR-022, ADR-016, ADR-020, helper-contracts.md, plan.md PR-split section**. ~5 files. Single-reviewer pass (delivery-reviewer, since they own PR-LOC + receipt-protocol concerns) sufficient unless DA's `speckit.run.md` blind spot becomes load-bearing — in which case add a focused DA pass on the slash-command markdown.

---
**Phase**: complete — awaiting gate decision


---

## Revisions Applied (2026-04-26 — post-re-review REVISE pass)

User selected option **2 (REVISE)** at the gate. All six blockers were addressed in a single pass; C-5 was resolved via option **(b1)** — fold sentinel detection into `run-decide-next.sh` (preserves uniform receipt invariant per oracle PHI on disk-as-source-of-truth).

| Blocker | File(s) | Change |
|---|---|---|
| C-1 (sidecar completeness invariant) | ADR_022 §Decision step 6, helper-contracts.md §Verdict-Receipt Protocol, run-serialize.sh contract | Added termination-time pipeline-completeness invariant: `run-serialize.sh` asserts every per-stage record in `decisions-log.md` has at least one routing-decision event in `.run/control-flow.log`; missing → `pipeline-incomplete` canonical entry. Tier 1 test surface added. |
| C-1 (omission detection) | ADR_022 §Decision step 5, helper-contracts.md run-decide-next.sh | Added in-band check: `run-decide-next.sh` refuses to mint when prior receipt is unconsumed; writes `verdict-omitted`. |
| C-1 (static-grep guard) | ADR_022 §Risks, helper-contracts.md §Verdict-Receipt Protocol, plan.md PR3b | Tier 1 static-grep test on `speckit.run.md` invocation order added as explicit deliverable in PR3b. |
| C-2 (missing-receipt semantics) | ADR_022 §Decision step 3, helper-contracts.md run-emit-event.sh | Missing-receipt explicitly treated identically to mismatched-receipt; refuses emission, writes `verdict-mismatch`. |
| C-2 (reframe) | ADR_022 §Context, §Decision, helper-contracts.md §Verdict-Receipt Protocol | Reframed "structurally impossible" → "structural detection of forgery + omission". |
| C-3 (PR3 split + hard cap) | plan.md §PR Policy | PR3 split into PR3a (code-action helpers + tests, ~190 LOC) and PR3b (slash-command markdown ≤250 LOC hard cap + integration tests + static-grep test, ~250 LOC). PR4 → PR5. |
| C-4 (check-prerequisites integration) | helper-contracts.md run-postcheck.sh | run-postcheck.sh contract already specifies `check-prerequisites.sh` invocation against the feature-dir; deferred `--feature-dir` flag wiring to tasks.md as an implementation task (orchestration covered; flag is a CLI ergonomic detail). |
| C-5 (sentinel-abort ordering, b1 fold-in) | ADR_019 §Decision step 3.e, ADR_019 §Consequences, helper-contracts.md run-decide-next.sh, run-lock.sh check-sentinel | Sentinel detection folded into `run-decide-next.sh` as a state input ahead of other routing logic; standalone "check between every dispatch" step removed. `run-lock.sh check-sentinel` retained as Tier 1 test surface and recovery utility. Trade-off (fast-path latency for invariant uniformity) documented. |
| S-2 (orchestrator-authored canonical exception) | ADR_016 §Decision (V1 implementation block) | Documented three orchestrator-authored canonical-entry exceptions: `verdict-mismatch`, `verdict-omitted`, `pipeline-incomplete`. All share `_emit_canonical_entry` path; concurrency safe (each fires only when no subagent is dispatched). |
| Preserved dissent (DA Claim D-1) | LOG_013 (new) | Created LOG-013 capturing the "✓ all checks passed" honest-signal concern with explicit SC-008 kill-switch criterion (Branch B rubber-stamp rate > baseline → suppress no-findings banner in V2). |

### Files Touched
- `.specify/memory/ADR_019_deterministic-orchestrator-core.md` (sentinel fold-in, amendment history row)
- `.specify/memory/ADR_022_verdict-receipt-enforcement.md` (Decision steps 5/6, reframe, new risk entry, amendment history row)
- `.specify/memory/ADR_016_decision-log-canonical-derivative.md` (orchestrator-authored canonical-entry exceptions, amendment history row)
- `.specify/memory/LOG_013_rubber-stamp-dogfooding-risk.md` (new — dissent + kill-switch criterion)
- `specs/010-autonomous-workflow/plan.md` (PR3 split → PR3a/PR3b/PR5, hard cap on speckit.run.md, LOG-013 added to Decision Records table)
- `specs/010-autonomous-workflow/contracts/helper-contracts.md` (Verdict-Receipt Protocol expanded, run-decide-next.sh sentinel + omission, run-emit-event.sh missing-receipt, run-serialize.sh completeness invariant, run-lock.sh check-sentinel role clarification, run-common.sh `_emit_canonical_entry` consumers updated)

### Outstanding (S-tier — defer to tasks.md)
- S-1: `test_postcheck.bats` as explicit task
- S-3: FR-022 helper anchor (resolve in tasks.md)
- S-4: ADR-020 timing fields (`prompt_shown_ts`/`proceed_ts`) for SC-008 — task-level if SC-008 is V1-scoped
- S-5: `run-postcheck.sh` exit code 2 disambiguation — UX/diagnostic
- S-6: `run-target.sh validate` UX-friendly rejection diagnostic
- S-7: `quickstart.md` halt-class table missing `postcheck-failed` row

**Next action**: re-review with the recommended scope (delivery-reviewer focused pass on ADR-022, ADR-016, helper-contracts.md, plan.md PR-split section + LOG-013), or proceed directly to `/speckit.tasks` if user prefers to roll the S-tier into task generation.

---

# Re-Review #2 (focused): Post-REVISE pass
**Started**: 2026-04-26T23:45:00Z
**Phase**: A (independent analysis)
**Panel**: delivery-reviewer, devils-advocate, synthesis-judge
**Rigor**: STANDARD-narrow (single-specialist + DA per prior synthesis recommendation)
**Scope**: Six revised files: ADR-019 (sentinel fold-in), ADR-022 (verdict-receipt amendments), ADR-016 (orchestrator-canonical exceptions), LOG-013 (rubber-stamp dissent), helper-contracts.md (Verdict-Receipt Protocol expansion + run-decide-next sentinel/omission + run-emit-event missing-receipt + run-serialize completeness invariant), plan.md (PR3 split + LOG-013 reference). Validates that all six prior blockers (C-1..C-5, S-2) are now closed and that revisions did not introduce new defects.


## Phase A: delivery-reviewer (Re-Review #2)

**Risk verdict: MEDIUM.** Five of six prior blockers CLOSED; C-4 PARTIALLY CLOSED; three new LOW defects + one TDD gap.

**Per-blocker:**
- **C-1 (omission gap)**: CLOSED (90%). In-band check (run-decide-next refuses on unconsumed receipt → verdict-omitted) + termination-time invariant (run-serialize → pipeline-incomplete) + static-grep PR3b deliverable. Mechanism end-to-end.
- **C-2 (missing-receipt semantics)**: CLOSED (95%). ADR-022 step 3 + helper-contracts.md align: missing-receipt ≡ mismatched-receipt → exit non-zero, refuse emission, write verdict-mismatch.
- **C-3 (PR3 LOC)**: CLOSED-with-residual. PR3a (~190) + PR3b (~250 hard cap) split. Residual: see N-1.
- **C-4 (check-prerequisites --feature-dir)**: **PARTIALLY CLOSED (90%).** `check-prerequisites.sh` derives FEATURE_DIR from git branch via `find_feature_dir_by_prefix()` (common.sh L127–155); **no `--feature-dir` parameter exists in current script**. helper-contracts.md L202 lists `check-prerequisites.sh` as a load-bearing step in `run-postcheck.sh`'s contract. cd-workaround silently validates wrong dir if branch ≠ feature-dir; breaks on `--resume` from different branches. Deferral to tasks.md is unguaranteed (no tasks.md exists). Calling this "CLI ergonomic detail" mischaracterizes load-bearing interface mismatch.
- **C-5 (sentinel fold-in)**: CLOSED (95%). ADR-019 step 3.e + helper-contracts.md run-decide-next.sh §Behavior step 2 align; check-sentinel relegated to test/recovery utility.
- **S-2 (Principle VII drift)**: CLOSED (95%). ADR-016 names three orchestrator-canonical exceptions (verdict-mismatch/verdict-omitted/pipeline-incomplete); concurrency-safe via "fires only when no subagent dispatched."

**New defects (introduced by REVISE):**
- **N-1 LOW**: plan.md L74 says "CI guard rejects merges that exceed [250 LOC] cap" — no CI infrastructure exists in this project. Cap is aspirational. **Fix:** replace with Tier 1 bats `test_command_loc.bats` (`wc -l ≤250`, ~5 lines). Confidence 85%.
- **N-2 LOW**: `run-decide-next.sh` exit code 1 overloads "log unreadable" (environmental) and "verdict-omitted written" (semantic protocol violation). Orchestrator must distinguish for correct halt-class routing. **Fix:** assign exit code 3 to verdict-omitted. Confidence 75%.
- **N-3 LOW-MEDIUM**: `pipeline-incomplete` does not block termination; coalesced summary appends `clean` afterward. Audit consumer reading only terminal entry sees `clean` despite contradictory `pipeline-incomplete` upstream. **Fix:** when pipeline-incomplete fires, set `termination-kind` = `incomplete` (or `clean-with-warnings`). One-field change in run-serialize.sh formatting. Confidence 80%.
- **TDD gap LOW**: `run-serialize.sh` is now a separate helper but **no `test_serialize.bats` listed in plan.md project structure**. helper-contracts.md describes test cases inline (L19) but the unit test file isn't enumerated. Confidence 88%.

**Pre-existing (not addressed by revisions):** PR1 (~280 LOC) and PR2 (~290 LOC) were not re-examined. Prior Phase A estimated PR1 390–620 / PR2 410–580. The REVISE only split PR3.

**Dependency/PR ordering:** PR1→PR2→PR3a→PR3b→PR5 strict linear DAG, clean. Static-grep test and `speckit.run.md` ship in same PR (PR3b) — correct ordering.

**Dissent:** C-4 deferral framing as "CLI ergonomic detail" is wrong. Existing script is fundamentally branch-driven. Without a code change to `check-prerequisites.sh`, `run-postcheck.sh` cannot satisfy its contract as written. This is a silent-correctness failure, not a flag-wiring detail.

## Phase A: devils-advocate (Re-Review #2, FULL rigor)

**Verdict: REVISE — confidence 78%.** Omission gap *narrowed*, not closed. Three "doors" share a skeleton key. New structural assumptions added without enforcement. SC-008 instrumentation invented in LOG-013, absent from spec.md.

1. **Three-mechanism defense is one mechanism wearing three hats (85%).** All three checks (in-band omission, completeness invariant, static-grep) are conditional on LLM voluntarily invoking deterministic helpers. In-band fires only if LLM calls run-decide-next.sh **again**; termination invariant fires only if run-serialize.sh runs; static-grep just verifies markdown contents. Skeleton key: LLM must voluntarily reach a finalization helper.

2. **run-serialize.sh is single point of failure for omission detection — nothing forces it to run (90%).** helper-contracts.md L55 has `release` MUST come after `run-serialize.sh` — but that MUST is on the slash-command markdown, not on bash. `run-lock.sh release` does not assert serialize ran. On crash/SIGINT/--break-lock recovery, serialize doesn't run. Next run's `acquire` wipes `.run/last-verdict` — **cross-run forensics destroyed**. Bypass route: BLOCKING-checkpoint emitted, developer interacts outside helpers, session ends, no serialize invocation, no pipeline-incomplete. **Reframe (REF-1):** make `run-lock.sh release` the choke point — refuse cleanup without proof of completion or graceful failure.

3. **Static-grep test is spell-check, not behavior verification (80%).** "asserts speckit.run.md invokes helpers in prescribed sequence" tests text, not LLM compliance. Markdown can simultaneously contain helper invocations AND drift-prose. **Real test**: Tier 2 fixture with tempting shortcut in developer payload, assert orchestrator still emits via helper.

4. **ADR-016's "three exceptions" is a Principle II smell (70%).** Justification reveals the principle was actually "single-writer-at-a-time", not "subagent-only." Three exceptions in V1 with ADR-015 scope discipline is a flag. Reframe: principle = single-writer; orchestrator writes when no subagent dispatched.

5. **LOG-013 SC-008 instrumentation invented out of whole cloth (92%).** LOG-013 L42 claims `run-decide-next.sh` records wall-clock deltas feeding SC-008. But: spec.md SC-008 (L173) doesn't mention rubber-stamp rate / wall-clock / Branch A/B / 30-checkpoint kill-switch. helper-contracts.md run-decide-next contract (L109–137) doesn't list wall-clock-delta sidecar emission. Kill-switch baseline requires retroactive measurement that isn't being captured. **LOG-013 is decorative** unless either (a) wall-clock field elevated to MUST in helper-contracts and SC-008 amended, or (b) LOG-013 downgraded to "deferred to V2."

6. **Sentinel fold-in changes failure-class accounting (60%).** Forgery of `abort` now structurally detectable (real win) — but stuck/corrupt run-decide-next.sh blocks legitimate aborts. Need Tier 1 test: `--break-lock` recovery still works when run-decide-next is broken.

7. **"In-band check" framing rhetorical overreach (75%).** ADR-022 step 5 only fires on next call to run-decide-next.sh. Real omission catch is step 6 (termination). Step 5 should be called "in-band detection of mint-without-emit when subsequent mint attempted" — not "in-band omission detection."

**Catastrophic failure mode (80%):** Orphan receipt on crash. Run dies between mint and emit; next `run-lock.sh acquire` silently wipes `.run/last-verdict` (helper-contracts.md L54). Completeness invariant didn't fire (no serialize on crash); next run produces clean audit substrate that contains no record of the prior incomplete one. **In V1 dogfooding context, yesterday's crashed run is invisible to today's audit trail.** Minimal fix: `acquire` MUST detect stale lock with non-empty `last-verdict` and write `prior-run-unattested` canonical entry before wiping.

**Reframes:**
- **REF-1:** Lock release as omission choke point (replaces serialize as enforcement point).
- **REF-2:** Replace static-grep with runtime breadcrumb — orchestrator writes "stage-dispatched" marker per dispatch; serialize compares markers to routing events.
- **REF-3:** Reframe "omission" → "unattested termination." Real failure mode is out-of-band exit channel; only closure is making lock release impossible without attestation.

**Strongest standalone objection (88%):** "The omission gap is closed because there are three checks" overstates the property. Honest claim: forgery is structurally closed; omission is detected iff termination flows through run-serialize.sh, which V1 does not enforce.


## Phase B: Devil's Advocate Consensus Challenge (Re-Review #2)

**Verdict: REVISE-narrow (82%).**

**CONV-1 (omission detection): GENUINE 88%.** Convergent finding from divergent vectors confirms genuine, not groupthink. **Deeper invariant violated:** `decisions-log.md` is being asked to be both an append-only event log AND a query-by-last-entry status surface. Two symptoms of one violated invariant. Every consumer protocol (including FR-023 resume) has to choose which mode it's in; spec doesn't say.

**CONV-2 (C-4): PARTIALLY GENUINE 72%.** Gap is real but framing too strong: a 5-minute mechanical fix (3-line argparse OR `SPECIFY_FEATURE=$(basename feature-dir)` env-var wrapper). Defensible if plan.md adds explicit phasing constraint ("PR3a depends on a 1-commit precursor"). But helper-contracts.md L202 documents an interface that doesn't exist — documentation defect at plan gate regardless.

**CONV-3 (TDD coverage): PARTIALLY GENUINE 65%.** `test_serialize.bats` IS implicitly covered under "their bats files." But substantive finding emerges: **PR2 LOC budget (~290) not credible** given test surface ADR-022 implies (~400+ LOC of bats alone for receipt + sentinel + omission + serialize tests).

**Uncovered findings (DA Phase B):**
- **U-1 HIGH**: Developer SIGINT between mint and emit creates orphan-receipt failure mode identical to crash; SIGINT is the modal interruption pattern; plan does not name SIGINT handling. Fix: `acquire` preserves orphaned verdict before wipe.
- **U-2 MEDIUM**: REF-1's `prior-run-unattested` breaks FR-023 `--resume` semantics (latest-entry detection reads bookkeeping). Needs explicit interaction rule.
- **U-3 LOW**: No `schema_version` field in canonical-log entries; can't add new entry-type-set boundaries cleanly in V2.
- **U-4 MEDIUM**: PR3b over budget — slash-command markdown alone hits the 250-LOC cap; integration bats (~150 LOC) + static-grep test don't fit.

**REF-4 (new):** Treat canonical log as 3-section file (header = run-attestation, body = subagent records append-only, footer = orchestrator violations). Status query = read header. Solves CONV-1's structural ambiguity; more invasive than REF-1/2/3.

**Falsifiers for strongest objection** (orphan-receipt-after-crash-silently-wiped):
1. `run-lock.sh acquire` writes `prior-run-receipt-orphaned` canonical entry on every non-empty wipe.
2. PR1/PR2 includes test asserting kill between mint and emit produces audit evidence on next run.
3. ADR-022 explicitly names invariant: "every dispatch path is either attested or has canonical-log record of non-attestation."
None currently exist.

**Required for PROCEED (DA narrowed list):**
1. acquire writes prior-run-receipt-orphaned on non-empty wipe.
2. helper-contracts.md L202 either references real `--feature-dir` interface (1-commit precursor to PR3a) OR rewords to env-var path.
3. Plan.md PR2 budget re-derived against ADR-022 test surface OR serialize tests split into PR2.5.
4. Plan.md names resolution for canonical-log-as-status-vs-event ambiguity.

## Phase B: delivery-reviewer Response

**Risk verdict: HIGH (unchanged from Phase A, increased confidence).**

**Engages with each DA challenge:**

**CONV-1 (REF-4 / two-job invariant): PARTIALLY ACCEPTED with correction.** DA's structural diagnosis is right but jobs are temporally separated (event tape during run; status surface at termination). Violation is structural-not-concurrent — V2 cross-session-resume problem, not V1 runtime problem. **N-3 stays LOW-MEDIUM.** REF-4 too invasive for V1 (changes `_emit_canonical_entry`, completeness predicate, schema). **Simpler delivery-side fix**: `run-serialize.sh` writes a single merged entry containing both `pipeline-incomplete` detail and termination kind, rather than two sequential entries. 5-line fix; tasks-phase.

**CONV-2 (env-var wrapper): REJECTED as insufficient.** DA's env-var path silently uses stale `SPECIFY_FEATURE` if dev runs `--feature-dir` ≠ encoded value. `--feature-dir` flag validates path at invocation time, env-var validates at wrapper-creation. Right fix is the flag. **Tasks-phase blocker — deferral risky if tasks author reads helper-contracts.md L202 at face value.**

**CONV-3 (PR2 LOC): ACCEPTED. Gap is larger than DA estimated.** Detailed test count: run-decide-next 8–10 tests, run-emit-event 6–8, run-serialize 6–8, run-validate-entry 6–10. At 15–25 LOC per case, **30+ tests = 450–750 LOC of bats** + helpers 200–280 LOC. **PR2 realistically 650–1000 LOC, 2–3x stated budget. Must split into PR2a (run-validate-entry alone, simplest helper) + PR2b (verdict-receipt triplet — cannot split further without losing receipt-protocol test coherence).**

**U-1 (SIGINT): CONCUR but downgrade HIGH→MEDIUM.** Detection guaranteed by completeness invariant; V1 single-session; SIGINT most likely at BLOCKING checkpoint not mid-helper. Risk = confusing `--resume` after SIGINT, not data corruption. **Fix as documentation task in quickstart.md, not signal-handler complexity in V1 helpers.**

**U-2 (resume interaction): CONCUR at MEDIUM.** Completeness-check + resume logic must skip orchestrator-authored entry types when scanning for latest subagent record. Not a big implementation change but contract gap that must be specified before run-decide-next.sh routing logic is written. **Tasks-phase blocker.**

**U-3 (schema_version): ACCEPT AT LOW.** V2 migration can use existing `event_type` discriminant. 1-field addition to sidecar-event.md contract; tasks-phase note. Does not affect V1.

**U-4 (PR3b over budget): CONCUR AND STRENGTHEN.** Plan.md L74 conflates "≤250 LOC markdown file length" with "PR LOC budget." PR3b realistically 400+ LOC. **Must split: PR3b-i (slash-command markdown only, ≤250 LOC) + PR3b-ii (integration bats + static-grep test, ≤200 LOC).**

**Updated blocker list:**
| ID | Sev | Action |
|---|---|---|
| C-4 | MED | Add `--feature-dir` flag as explicit precursor task; reject env-var wrapper |
| PR2-split | MED | Split PR2→PR2a (run-validate-entry) + PR2b (verdict-receipt triplet) before tasks generated |
| PR3b-split | MED | Split PR3b→PR3b-i (markdown) + PR3b-ii (tests) before tasks generated |
| U-2 | MED | Add FR-023 resume-scan rule to skip orchestrator-authored entry types; specify before run-decide-next.sh implementation |
| N-3 | LOW-MED | Merge pipeline-incomplete + termination-kind into single run-serialize entry; tasks-phase |
| U-1 | LOW | Document SIGINT-orphan behavior in quickstart `--resume` path; no V1 implementation change |
| N-1 | LOW | Replace "CI guard" prose with manual-enforcement note OR Tier 1 bats LOC test |
| N-2 | LOW | Reserve exit code 3 for verdict-omitted; tasks-phase |
| U-3 | LOW | Add schema_version field to sidecar-event.md; 1-line change |

**Two PR-budget errors (PR2, PR3b) are highest-confidence delivery risks — will cause tasks to be written against incorrect budgets, forcing mid-implementation splits that break dependency graph. Must be corrected in plan.md before `/speckit.tasks` runs.**


## Phase C: Re-Review #2 Synthesis

### Executive Summary
The post-REVISE plan closes 4 of 6 prior blockers cleanly (C-1, C-2, C-5, S-2) but **C-4 is documentation-only-closed** and **C-3 is split-on-paper-but-budgets-still-wrong**. Both reviewers converge that the omission gap is *narrowed not closed* (canonical-log-as-tape-vs-status invariant violation underneath) and that PR2 + PR3b budgets are still 2–3× understated. **Recommendation: REVISE-narrow.** Six surgical plan-level fixes unblock the tasks gate; remaining items defer cleanly.

### Cross-Panel Consensus (Phase B close)

| ID | Severity | Finding | Reviewers | Action |
|---|---|---|---|---|
| RC-1 | MED-HIGH | Omission detection narrowed-not-closed. Three "checks" share one skeleton key: LLM voluntarily reaches finalization helper. **Underlying invariant**: `decisions-log.md` asked to be both append-only event tape AND query-by-last-entry status surface; consumers (incl. FR-023 resume) must choose mode and spec doesn't say. | DA (CONV-1) + delivery (N-3) | Plan-level: name canonical-log mode and pick resolution. Tasks-level: merge `pipeline-incomplete` + `termination-kind` into single run-serialize entry. |
| RC-2 | MED | C-4 not architecturally closed. helper-contracts.md L202 documents an interface that doesn't exist (`check-prerequisites.sh` is branch-driven, no `--feature-dir` flag in common.sh L127–155). cd-workaround silently validates wrong dir if branch ≠ feature-dir; breaks under `--resume`. | sys-arch + delivery + DA | Add `--feature-dir` flag as 1-commit precursor to PR3a; update helper-contracts.md L202 to real interface. |
| RC-3 | MED | PR2 LOC budget (~290) 2–3× understated. ADR-022 test surface implies 30+ bats × 15–25 LOC = 450–750 LOC of tests + 200–280 LOC helpers = realistic 650–1000 LOC. Will force mid-stream split, destabilizing tasks DAG. | delivery + DA | Split PR2 → PR2a (run-validate-entry) + PR2b (verdict-receipt triplet). |
| RC-4 | MED | PR3b LOC conflated with markdown file length cap. plan.md L74 reads `≤250 LOC markdown` as PR budget; PR3b also carries integration bats (~150 LOC) + static-grep test. Realistic 400+ LOC. | delivery + DA | Split PR3b → PR3b-i (markdown only ≤250 LOC) + PR3b-ii (tests ~200 LOC). Clarify L74 cap applies to file, not PR. |
| RC-5 | MED | FR-023 resume-scan must skip orchestrator-authored entry types (`verdict-mismatch`, `verdict-omitted`, `pipeline-incomplete`); otherwise new exception types pollute resume detection. | DA (U-2) + delivery (CONCUR) | Add explicit FR-023 resume-scan rule before run-decide-next.sh routing logic implemented. |
| RC-6 | MED (compromise) | Developer SIGINT between mint and emit creates orphan-receipt; next `acquire` silently wipes; cross-run forensics destroyed. | DA (U-1 HIGH) + delivery (CONCUR at MED) | Document SIGINT-orphan in quickstart; defer signal-handler complexity. (See preserved dissent.) |

> **Context (RC-1):** The plan adds three structural checks to detect orchestrator bypass — `run-decide-next.sh` refuses on unconsumed receipt; `run-serialize.sh` asserts every per-stage record has a routing-decision event; static-grep verifies `speckit.run.md` invokes helpers in order. All three only fire when LLM voluntarily reaches a finalization helper. The deeper issue: `decisions-log.md` is both event tape during a run and status surface queried at termination/resume — and the spec doesn't tell consumers which mode they're in. Current fix appends `pipeline-incomplete` followed by coalesced `clean` summary, so an audit consumer reading only the terminal entry sees `clean` despite an upstream contradiction.

> **Context (RC-2):** `run-postcheck.sh` is documented (helper-contracts.md L202) as calling `check-prerequisites.sh` against a feature-dir. The actual script derives FEATURE_DIR from current git branch via `common.sh::find_feature_dir_by_prefix()`; no `--feature-dir` flag accepted. Contract as written cannot be satisfied. cd-workaround silently validates wrong directory under `/speckit.run --resume --feature-dir=...` from a different branch.

> **Context (RC-3):** PR2 in plan.md is ~290 LOC. ADR-022 verdict-receipt protocol implies test cases for run-decide-next (8–10), run-emit-event (6–8), run-serialize (6–8), run-validate-entry (6–10) — ~30+ bats cases × 15–25 LOC = 450–750 LOC tests + 200–280 LOC helpers = realistic 650–1000 LOC. Will force mid-implementation split that breaks dependency ordering.

> **Context (RC-4):** plan.md L74 specifies "≤250 LOC" cap on `speckit.run.md` markdown file length and treats it as PR3b budget. PR3b also carries integration bats (~150 LOC) + static-grep test — none contribute to markdown line count, all contribute to PR diff. Realistic PR3b 400+ LOC.

> **Context (RC-5):** FR-023 resume scans `decisions-log.md` to find latest subagent record and resume from next stage. REVISE introduced three new orchestrator-authored entry types (`verdict-mismatch`, `verdict-omitted`, `pipeline-incomplete`) sharing the same canonical log. If resume-scan reads "latest entry" without filtering, it treats orchestrator violation entries as resume anchor → wrong-stage resumption.

> **Context (RC-6):** Developer hitting Ctrl-C between `run-decide-next.sh` (writes `.run/last-verdict`) and `run-emit-event.sh` (consumes it) leaves orphaned receipt. Next `run-lock.sh acquire` silently wipes `.run/last-verdict` (helper-contracts.md L54). Completeness invariant doesn't fire because serialize never ran. Yesterday's interrupted run leaves no audit evidence in today's session — exactly the failure mode verdict-receipt was supposed to catch.

### Single-Reviewer Findings That Survived Phase B

| ID | Severity | Finding | Reviewer |
|---|---|---|---|
| SR-1 | MED-HIGH (DA, 92%) | LOG-013 SC-008 instrumentation invented out of whole cloth: claims `run-decide-next.sh` records wall-clock deltas feeding SC-008, but spec.md SC-008 (L173) doesn't mention rubber-stamp rate / wall-clock / Branch A/B / 30-checkpoint kill-switch, and helper-contracts.md run-decide-next contract (L109–137) doesn't list wall-clock-delta sidecar emission. Kill-switch baseline requires retroactive measurement that isn't being captured. | DA |
| SR-2 | MED (DA, 70%) | ADR-016's "three exceptions" is Principle II smell — principle is actually "single-writer-at-a-time," not "subagent-only." Reframing now prevents future ADR drift. | DA |
| SR-3 | LOW (DA, 60%) | Sentinel fold-in changes failure-class accounting: forgery of `abort` now structurally detectable (real win), but stuck/corrupt run-decide-next.sh blocks legitimate aborts. Need Tier 1 test that `--break-lock` recovery still works when run-decide-next broken. | DA |
| SR-4 | LOW | N-1: plan.md L74 "CI guard rejects merges that exceed [250 LOC] cap" — no CI infrastructure exists. Cap is aspirational. | delivery |
| SR-5 | LOW | N-2: `run-decide-next.sh` exit code 1 overloads "log unreadable" (env) and "verdict-omitted written" (semantic). Reserve exit 3 for verdict-omitted. | delivery |
| SR-6 | LOW | TDD gap: `test_serialize.bats` not enumerated in plan.md project structure despite run-serialize.sh being separate helper with significant new responsibility. | delivery |
| SR-7 | LOW | U-3: No `schema_version` field in canonical-log entries; complicates V2 boundary. 1-line change to sidecar-event.md. | DA |

### Active Disagreements (preserved dissent)

| Topic | Position A | Position B | Resolution Path |
|---|---|---|---|
| C-4 fix mechanism | DA: env-var wrapper acceptable (5-min mechanical fix `SPECIFY_FEATURE=$(basename feature-dir)`) | Delivery: REJECTED — env-var validates at wrapper-creation time not invocation time; silently uses stale value if dev runs `--feature-dir` ≠ encoded; breaks under `--resume` with different `--feature-dir` | Adopt `--feature-dir` flag (delivery's position stronger — `--resume` failure mode is the one rest of design hardens against) |
| U-1 SIGINT severity | DA: HIGH — orphan receipt + silent wipe = invisible failure mode in V1 dogfooding | Delivery: MEDIUM — completeness invariant guarantees detection; SIGINT most likely at BLOCKING checkpoint not mid-helper; risk = confusing `--resume` not data corruption | Compromise: document in quickstart now (delivery), open LOG capturing DA's stronger formulation as V2 candidate |
| REF-4 (three-section file) | DA: structural fix to canonical-log invariant | Delivery: too invasive for V1; simpler fix is single merged `pipeline-incomplete + termination-kind` entry | Delivery's simpler fix lands in V1; REF-4 deferred to V2 ADR candidate |

### Blind Spots
- `speckit.run.md` content itself still unaudited as behavioral artifact. Static-grep catches sequence but not drift-prose alongside helper invocations. Tier 2 fixture with tempting shortcut + assertion that orchestrator still emits via helper — flagged as V2 work.
- Cross-run forensics on crash/SIGINT — both reviewers raise variants; neither position adopts structural fix (REF-1 lock-release-as-choke-point) for V1.
- LOG-013 SC-008 measurability under solo-dev, no-Branch-A/B-infrastructure project context — no reviewer challenged whether the protocol is executable at all.

### Recommended Decision Records
- **Amend ADR-022**: clarify "in-band check" framing — step 5 fires on next call (not on omission itself); rename or annotate.
- **Amend ADR-016**: reframe principle from "subagent-only canonical writes" to "single-writer-at-a-time" with subagent dispatch as synchronization. Three exceptions then read as natural consequences.
- **Amend LOG-013**: reconcile SC-008 instrumentation claim with spec.md + helper-contracts.md, OR downgrade kill-switch to V2-deferred. Cannot ship as written.
- **New LOG-014**: canonical-log mode ambiguity (event-tape vs status-surface). Type CHALLENGE. Document V1 resolution + V2 REF-4 candidate.
- **New LOG-015**: orphan-receipt cross-run forensics gap. Type QUESTION. V1 quickstart documentation + V2 re-evaluation trigger after dogfooding.
- **New LOG-016**: static-grep as behavior proxy. Type CHALLENGE. V2 fixture-based test candidate.
- **New ADR (V2 candidate)**: REF-1 lock-release-as-omission-choke-point. Record rejection rationale for V1.
- **Sidecar-event.md amendment**: add `schema_version` field (1 line, V1).
- **ADR-020 amendment** (carryover): `prompt_shown_ts`/`proceed_ts` — depends on LOG-013 decision (V1 if SC-008 stays V1; remove if SC-008 V2-deferred).

### Gate Recommendation: **REVISE-narrow**

**Plan-gate blockers (must close before `/speckit.tasks`):**
1. **RC-2 (C-4)**: `--feature-dir` flag added to `check-prerequisites.sh` as 1-commit precursor task; helper-contracts.md L202 updated to real interface.
2. **RC-3 (PR2 split)**: plan.md PR2 split → PR2a (run-validate-entry) + PR2b (verdict-receipt triplet) with re-derived budgets against ADR-022 test surface.
3. **RC-4 (PR3b split)**: plan.md PR3b split → PR3b-i (markdown ≤250 LOC) + PR3b-ii (integration bats + static-grep). Clarify L74 cap applies to file not PR.
4. **RC-5 (FR-023 resume-scan filter)**: helper-contracts.md (or spec.md FR-023) names orchestrator-authored entry types resume-scan must skip.
5. **RC-1 plan-level**: plan.md or spec.md adds one-paragraph statement of canonical-log mode (event-tape during run vs status-surface at termination/resume).
6. **SR-1 (LOG-013 reconciliation)**: either elevate wall-clock-delta to MUST in helper-contracts.md + amend spec.md SC-008 with measurement protocol, OR downgrade LOG-013 kill-switch to V2-deferred.

**Acceptable to defer to tasks.md:**
- RC-1 task-level fix (merge `pipeline-incomplete + termination-kind` into one run-serialize entry — 5-line change)
- RC-6/U-1 (SIGINT documentation in quickstart)
- SR-3 (Tier 1 `--break-lock` recovery test when run-decide-next broken)
- SR-4/N-1 (replace "CI guard" prose)
- SR-5/N-2 (reserve exit code 3 for verdict-omitted)
- SR-6 (enumerate `test_serialize.bats` in plan.md project structure)
- SR-7/U-3 (add `schema_version` field)
- ADR-016 reframe (SR-2) — useful but not load-bearing
- ADR-022 step-5 framing clarification — useful but not load-bearing

**Acceptable to defer to code review:**
- DA blind spots on `speckit.run.md` behavior verification (V2 fixture-based test)
- DA REF-1/REF-2/REF-4 (V2 ADR candidates captured in LOG-014/015/016)

### Re-Review Scope (smallest reasonable changed-surface)
If revisions land per 6-blocker list: re-review **plan.md (PR2/PR3b split + canonical-log mode paragraph), helper-contracts.md (`--feature-dir` interface + FR-023 resume-scan filter), `check-prerequisites.sh` precursor commit, LOG-013 (reconciled or V2-deferred)**. ~4 files + 1 helper script change.

**Single-reviewer pass: delivery-reviewer** is the right specialist (owns PR-LOC + receipt-protocol + interface-contract concerns). Add focused DA spot-check **only on LOG-013 reconciliation** — DA's 92%-confidence "invented out of whole cloth" is the highest-risk single item; DA should validate the reconciliation isn't another paper closure.

---
**Phase**: complete — awaiting gate decision

---

## Revisions Applied (2026-04-26 — post-Re-Review-#2 REVISE pass)

User selected option **2 (REVISE)** at the gate. SR-1 LOG-013 reconciliation chose option **(b) downgrade to V2-deferred** (per user preference: "b"). All six plan-gate blockers addressed in a single pass.

| Blocker | File(s) | Change |
|---|---|---|
| **RC-1** (canonical-log mode) | spec.md §Key Entities Decision Log | Added "Canonical-log read mode" paragraph naming event-tape mode (full scan, all entries) vs status-surface mode (filtered scan skipping the three orchestrator-authored canonical-exception types). Notes V1 ships dual-mode with filter as disambiguator; V2 may collapse via 3-section restructure. |
| **RC-2** (--feature-dir flag) | helper-contracts.md `run-postcheck.sh` step 2; plan.md PR Policy (new PR0) | helper-contracts.md L202 updated to `check-prerequisites.sh --feature-dir <feature-dir>` with explicit precursor-task note. plan.md adds **PR0** (~30 LOC, no dependencies) extending `check-prerequisites.sh` and `common.sh::find_feature_dir_by_prefix()` to accept the flag; PR3a now depends on PR0. Rationale documented: branch-derived default produces silent wrong-directory validation under `/speckit.run --resume --feature-dir=...`. |
| **RC-3** (PR2 split) | plan.md PR Policy | PR2 split → **PR2a** (`run-validate-entry.sh` + tests, ~150 LOC) + **PR2b** (verdict-receipt triplet — run-decide-next + run-emit-event + run-serialize + tests, ~450 LOC, **constitutional exception**). PR2b documents constitutional-exception rationale (verdict-receipt protocol test coherence requires triplet co-landing; cannot split without violating TDD or leaving receipt-validation contract unverifiable in isolation). |
| **RC-4** (PR3b split) | plan.md PR Policy | PR3b split → **PR3b-i** (slash-command markdown only, ~250 LOC = file hard cap = PR cap because markdown is the only artifact) + **PR3b-ii** (integration bats + static-grep + `test_command_loc.bats` enforcing the 250-LOC cap, ~200 LOC). Aspirational "CI guard" replaced with Tier 1 bats test (Re-Review #2 SR-4 task-deferred fix incorporated since it was load-bearing for PR3b-i's hard-cap claim). L74 cap now explicitly applies to the markdown file, not the PR. |
| **RC-5** (FR-023 resume-scan filter) | spec.md FR-023; helper-contracts.md `run-decide-next.sh` §Behavior step 3 | spec.md FR-023 amended with resume-scan filter rule: MUST filter out the three orchestrator-authored canonical-exception entry types (`verdict-mismatch`, `verdict-omitted`, `pipeline-incomplete`) when locating the latest stage record. helper-contracts.md run-decide-next.sh §Behavior step 3 expanded with the same filter rule and rationale (without filter, a `pipeline-incomplete` from a crashed prior run becomes the resume anchor → wrong-stage resumption). |
| **SR-1** (LOG-013 reconciliation, option b) | LOG_013_rubber-stamp-dogfooding-risk.md; plan.md Decision Records table | LOG-013 fully rewritten. SC-008 instrumentation chain (wall-clock-delta sidecar field, Branch A/B segmentation, 30-checkpoint kill-switch arithmetic) **removed** — explicitly acknowledged as invented infrastructure not present in spec.md SC-008 nor helper-contracts.md run-decide-next contract. V1 posture reframed as "mitigations only, no measurement": neutral phrasing in slash-command markdown + `SPECKIT_POSTCHECK_BANNER=off` escape hatch. V2 trigger conditions named (orchestrator stops dogfooding itself, OR SC-008 amended to include rubber-stamp rate, OR second developer adopts /speckit.run). Decision Records table entry updated to reflect V1 mitigations + V2 deferral. |

### Files Touched
- `.specify/memory/LOG_013_rubber-stamp-dogfooding-risk.md` (full rewrite — SC-008 instrumentation removed; V1 mitigations + V2 deferral)
- `specs/010-autonomous-workflow/spec.md` (FR-023 resume-scan filter + Decision Log canonical-log read mode paragraph)
- `specs/010-autonomous-workflow/contracts/helper-contracts.md` (run-postcheck.sh `--feature-dir` flag + run-decide-next.sh resume-scan filter)
- `specs/010-autonomous-workflow/plan.md` (PR Policy: 5 → 7 PRs with PR0 precursor; PR2/PR3b splits; constitutional exception for PR2b documented; LOG-013 Decision Records table entry updated)

### Outstanding (acceptable-to-defer to tasks.md per Re-Review #2 synthesis)
- RC-1 task-level fix (merge `pipeline-incomplete` + `termination-kind` into single run-serialize entry — 5-line change)
- RC-6 / U-1 (SIGINT-orphan documentation in quickstart.md `--resume` path)
- SR-3 / DA #6 (Tier 1 `--break-lock` recovery test when run-decide-next broken)
- SR-5 / N-2 (reserve exit code 3 for `run-decide-next.sh` verdict-omitted path)
- SR-6 (enumerate `test_serialize.bats` in plan.md project structure or task list)
- SR-7 / U-3 (add `schema_version` field to `contracts/sidecar-event.md`)
- ADR-016 reframe (SR-2: principle = single-writer-at-a-time, not subagent-only) — useful but not load-bearing for V1
- ADR-022 step-5 framing clarification (DA #7) — useful but not load-bearing

### Acceptable-to-defer to code review or V2
- DA blind spots on `speckit.run.md` behavior verification (V2 fixture-based test)
- DA REF-1 (lock-release-as-omission-choke-point) — V2 ADR candidate
- DA REF-2 (runtime stage-dispatched breadcrumb) — V2 ADR candidate
- DA REF-4 (3-section canonical log) — V2 ADR candidate
- New LOG-014/015/016 capturing the above as durable dissent — **OFFERED but not yet created**; user can request

**Next action**: re-review per Re-Review #2 synthesis recommended scope (delivery-reviewer focused pass on plan.md PR2/PR3b split + canonical-log mode paragraph, helper-contracts.md `--feature-dir` interface + FR-023 resume-scan filter, PR0 precursor commit, LOG-013 reconciliation; plus DA spot-check on LOG-013 reconciliation specifically). Or proceed directly to `/speckit.tasks` if user prefers to roll the deferred S-tier items into task generation.

---

## Re-Review #3 — Phase A: delivery-reviewer

**Risk: MEDIUM.** Four of six blockers genuinely closed. RC-2 (`--feature-dir`) documentation-closed not architecturally-closed. One new TDD-ordering defect (F-2).

### Findings
- **F-1 HIGH (RC-2 closure):** `helper-contracts.md` §run-postcheck.sh step 2 describes `check-prerequisites.sh --feature-dir` as if current; actual script exits 1 on the flag (verified at lines 30–75). Tasks author may treat contract as satisfiable today and skip PR0. Recommend annotating the interface as `[PRECURSOR required — see PR0; flag does not exist in current script]`. Confidence 95%.
- **F-2 MEDIUM (new defect, TDD ordering):** `test_command_loc.bats` ships in PR3b-ii but enforces a constraint on `speckit.run.md` shipped in PR3b-i. One-PR window where the 250-LOC cap is unenforced. Move the ~5-LOC test into PR3b-i. Confidence 88%.
- **F-3 MEDIUM (RC-3 LOC math):** PR2b 450 LOC estimate is at the floor of plausible (20 cases × 15 LOC + 3 helpers × 50 LOC). Realistic range 450–600. Third upward revision pattern in this review history. Re-derive at 20 LOC/case before tasks; document wider exception if >500. Confidence 80%.
- **F-4 LOW (RC-4 closure):** PR3b-i "PR cap = file cap" only holds if `speckit.run.md` is the sole artifact in the PR. Add explicit "no other files in this PR" sentence. Confidence 70%.
- **F-5 LOW (RC-5 phrasing divergence):** FR-023 vs helper-contracts.md entry_type sets differ on `halt` and `stage-end`. One-sentence reconciliation. Confidence 82%.
- **F-6 LOW (SR-1 closure):** LOG-013 §Related vestigially links `spec FR-014` (V2-deferred). Annotate or remove. Confidence 90%.

### Closure Verdict
| Blocker | Status | Conf |
|---|---|---|
| RC-1 (omission) | CLOSED | 88% |
| RC-2 (--feature-dir) | PARTIALLY CLOSED — doc defect remains | 95% |
| RC-3 (PR2 split) | CLOSED-with-residual LOC optimism | 80% |
| RC-4 (PR3b split) | CLOSED | 90% |
| RC-5 (FR-023 filter) | SUBSTANTIALLY CLOSED — minor divergence | 82% |
| SR-1 (LOG-013) | CLOSED | 90% |

---

## Re-Review #3 — Phase A: devils-advocate (LOG-013 spot-check)

**Verdict:** Rewrite resolves the *specific* SR-1 claim (kill-switch arithmetic gone) but does NOT resolve the *pattern* SR-1 was diagnosing.

### Most Dangerous Assumption
That an "Open" LOG with V2 trigger conditions but no V1 measurement constitutes preserved dissent rather than soft-close. V2 trigger #1 ("orchestrator stops dogfooding itself") fires *exactly* when the V1 dogfooding-during-build risk becomes unrecoverable.

### Key Findings
- **DA-1 (88%):** Neutral-phrasing requirement lives only in LOG-013 (rhetorical). Not in `helper-contracts.md` § run-postcheck.sh output spec. PR3b-i author can ship "✓ all checks passed" with green coloring; no test catches it.
- **DA-2 (90%):** `SPECKIT_POSTCHECK_BANNER=off` env var has no implementation anchor. Not in helper-contracts.md, not in plan.md PR3b-i scope. Structurally identical to SR-1 in miniature: LOG names infrastructure no other artifact owns.
- **DA-3 (80%):** V2 trigger #1 is self-defeating — fires when the V1 cohort that experienced the risk is gone.
- **DA-4 (72%):** No reviewer asked whether LOG-013 should be merged into LOG-011. LOG-011 Pass-3 metric #2 (`proceed`-rate when postcheck has findings vs clean) IS the no-findings-banner-degradation test under a different name. LOGs should consolidate, not split, on shared risk model.

### Recommended Smaller-Surface Fix
(a) Move phrasing requirement into `helper-contracts.md` as MUST on `run-postcheck.sh` clean-exit output, with Tier-1 bats assertion.
(b) Drop `SPECKIT_POSTCHECK_BANNER=off` env var (project context — solo, async — does not support the feedback loop it presumes).
(c) Close LOG-013 by reference to LOG-011, whose Pass-3 metric #2 already tests the same hypothesis using existing sidecar fields.

DA does NOT withdraw SR-1's spirit. The rewrite trades "invented kill-switch arithmetic" for "rhetorical mitigations no one will enforce."


---

## Re-Review #3 — Phase B: Devil's Advocate Cross-Examination

**Splits the convergence point.** F-1 and DA-1/DA-2 are NOT the same defect — different remediation paths:
- **F-1 = temporal drift**: contract is wrong about *current state* (script doesn't have the flag yet). Fix: precursor-landed-first or contract softening.
- **DA-1/DA-2 = locational drift**: LOG-013 names mitigations with no anchor in artifacts implementers consult. Fix: migrate to helper-contracts.md as MUST clauses.

### DA-5 NEW (90%): F-1 defect repeats in three locations
1. `contracts/helper-contracts.md` §run-postcheck.sh L204 (delivery F-1)
2. `.specify/memory/ADR_023_pre-route-linter-postcheck.md` Decision §2 ("`check-prerequisites.sh` (existing helper)")
3. `specs/010-autonomous-workflow/plan.md` L72 PR0 description

### Reframe (78%): Option (c) — demote LOG-013 into LOG-011
LOG-013 is a sub-hypothesis of LOG-011 (no-findings sub-case of BLOCKING-rubber-stamping). LOG-011 Pass-3 metric #2 already tests it. V1 mitigations migrate to helper-contracts.md + speckit.run.md as MUST clauses with LOG-011 carrying a single sentence pointer. Avoids both DA-4 ("close by reference") and (b) ("keep open with rhetorical mitigations").

### Self-Correction on DA-4
DA-4's "close LOG-013 by reference" was conflating two asks. The structural fix (migrate mitigations to contracts) is independent of the open/close decision. Withdraw the close-by-reference recommendation; keep the structural ask.

### Strongest Objection (75%) — PR2b sizing
PR2b's 450-LOC budget was set BEFORE ADR-022's amendments added Decision steps 5 (verdict-omitted refusal) and 6 (pipeline-incomplete invariant). Budget never re-derived. DA estimate 550–650 LOC. Constitutional exception retroactively widens without explicit re-justification.

---

## Re-Review #3 — Phase B: delivery-reviewer Response

### Splits accepted
- F-1 vs DA-1/DA-2 split adopted: temporal drift (contract ahead of code) vs locational drift (LOG-only requirements).
- DA-2 noted as closer to "invented mitigations" pattern from SR-1 than pure locational drift — warrants deletion, not migration.

### DA-5: confirmed 2 of 3 locations
- helper-contracts.md §run-postcheck.sh step 2 — CONFIRMED
- ADR-023 Decision §2 ("(existing helper)") — CONFIRMED at line 28; describes script as currently having the interface
- plan.md L72 — REJECTED. PR0 description correctly frames as future work; not the same defect. DA over-reaches here.

### F-3 upgraded MEDIUM → HIGH
ADR-022 amendments added 3–4 cases (verdict-omitted, pipeline-incomplete two-branch). Revised estimate **500–600 LOC**, not 450. Three successive upward revisions (290 → 450 → 500–600) signals estimation method is wrong — per-case LOC must be the starting point. Document the wider exception now; do not discover during PR2b review.

### Per-finding standing after Phase B
| Finding | Sev (Phase B) | Action |
|---|---|---|
| F-1 | HIGH (widened to 2 locations) | Annotate helper-contracts.md AND ADR-023 §2 with `[PRECURSOR: PR0]` |
| F-2 | MEDIUM (stands) | Move `test_command_loc.bats` to PR3b-i |
| F-3 | **HIGH (upgraded)** | Re-derive PR2b range as 500–600 LOC; restate exception rationale in plan.md and PR description |
| F-4 | LOW (stands) | Add "no other files in this PR" to PR3b-i |
| F-5 | LOW (stands) | Reconcile FR-023 vs helper-contracts.md entry_type set on `halt`/`stage-end` |
| F-6 | LOW (overtaken) | Remove vestigial FR-014 reference; broader concern in F-8 |
| **F-7 NEW** | MEDIUM | Annotate ADR-023 Decision §2 with `[PRECURSOR: PR0]` (same fix as F-1, second location) |
| **F-8 NEW** | LOW | Drop `SPECKIT_POSTCHECK_BANNER=off` OR give it MUST clause in helper-contracts.md + Tier-1 bats assertion |


---

## Re-Review #3 — Phase C: Synthesis

**Verdict: REVISE-narrow** — 3 documentation edits + 1 PR ordering swap (~30 min). After REVISE, proceed directly to `/speckit.tasks`. No Re-Review #4 required for the minimum-fix set.

### Consensus
- **S-1 BLOCKER**: RC-2 fix is documentation-tense-only. `--feature-dir` described as current capability in `helper-contracts.md` AND `ADR-023 §2 line 28`; script exits 1 on the flag. Both reviewers confirm 2 of 3 claimed locations (plan.md L72 is correctly future-tense — DA over-reach withdrawn).

### Minority (high-signal)
- **M-1 BLOCKER (delivery F-2)**: TDD ordering — `test_command_loc.bats` ships in PR3b-ii but constrains `speckit.run.md` shipped in PR3b-i. Move to PR3b-i.
- **M-2 HIGH (delivery F-3 upgraded)**: PR2b LOC pattern (290 → 450 → 500–600) signals estimation method is wrong, not unlucky. Update plan.md to 500–600 with explicit "supersedes prior 450 exception"; deeper question deferred to LOG-014.
- **M-3 MEDIUM (DA-2 + delivery F-8)**: `SPECKIT_POSTCHECK_BANNER=off` is implementation-owner-less. Drop OR contract+test.
- **M-4 MEDIUM (DA-1)**: Neutral-phrasing requirement lives only in LOG-013 prose. Migrate to `helper-contracts.md` as MUST clause; leave rationale in LOG-013.
- **M-5/M-6/M-7 LOW**: phrasing divergence (halt/stage-end), vestigial FR-014 ref, PR3b-i scope sentence.

### Dissent Preserved
DA's **option (c)** for LOG-013 (demote to a section of LOG-011 because LOG-011 Pass-3 metric #2 already tests the no-findings-banner hypothesis) is structurally sound but deferred — user already chose (b) at Re-Review #2 with full information; DA Phase B self-corrected that the structural fix (M-3, M-4 contract migration) is independent of the merge decision. **Not surfaced for re-decision in this gate.** Recorded for retrospective.

### Dismissed
- F-1 third location (plan.md L72) — false positive on inspection
- DA-3 (V2 trigger #1 self-defeating) — out-of-scope (V2 design)
- DA-4 (close LOG-013 by reference) — DA self-withdrew in Phase B

### Minimum-Fix Set (clears the gate)
1. Annotate `--feature-dir` in `helper-contracts.md` §run-postcheck.sh step 2 AND `ADR_023_pre-route-linter-postcheck.md` Decision §2 line 28 with `[PRECURSOR: PR0 — adds this flag; helpers exit 1 today]`
2. Move `test_command_loc.bats` into PR3b-i (or swap PR3b-i/PR3b-ii ordering)
3. Update `plan.md` PR2b LOC budget to 500–600 with explicit "supersedes prior 450 exception" note

### Ideal-Fix Set (additionally tightens)
4. Resolve M-3 (env var ownership) — drop or contract+test
5. Migrate neutral-phrasing requirement to `helper-contracts.md` (M-4)
6. Reconcile halt/stage-end terminology (M-5)
7. Remove vestigial FR-014 reference in LOG-013 (M-6)
8. Add "no other files" scope sentence to PR3b-i (M-7)
9. Confirm PR0 has its own DoD before tasks.md (blind spot)

### Blind Spots
- Other tests may have similar TDD-ordering defects; only `test_command_loc.bats` was spot-checked
- PR0 has no written DoD; it is referenced by S-1/F-7 as the future home for `--feature-dir` but no scope/test list/LOC budget is documented for PR0 itself

### LOGs Recommended
- **LOG_014 (CHALLENGE) — PR2b LOC estimation pattern**: Three upward revisions signal estimation method is wrong; root cause likely ADR amendments adding Decision steps after PR sizing; open question whether constitutional exceptions should expire when underlying ADR is amended. Write during/after tasks.md, not before.

### Gate Decision Recorded
**REVISE-narrow** — apply minimum-fix set (~30 min), then `/speckit.tasks`.


---

## Re-Review #3 REVISE Pass Applied (2026-04-27)

User selected: minimum-fix set + ideal-fix set.

### Minimum (gate-clearing)
- **S-1 part 1**: `helper-contracts.md` §run-postcheck.sh step 2 — annotated `[PRECURSOR: PR0 — adds this flag; check-prerequisites.sh exits 1 on --feature-dir today]`.
- **S-1 part 2**: `ADR_023_pre-route-linter-postcheck.md` Decision §2 line 28 — same precursor annotation; replaced "(existing helper)" framing.
- **M-1**: `test_command_loc.bats` moved from PR3b-ii to PR3b-i (now co-located with `speckit.run.md` it constrains; Principle III TDD ordering restored).
- **M-2**: `plan.md` PR2b LOC budget updated 450 → **500–600** with explicit "supersedes prior 450 estimate" note + LOC re-derivation paragraph (ADR-022 amendments accounting). Pattern tracked in pending LOG-014.

### Ideal (additional tightening)
- **M-3**: `SPECKIT_POSTCHECK_BANNER=off` env-var dropped from LOG-013 V1 mitigations entirely (DA-2 / no implementation owner; project context does not support feedback loop). Rationale documented in LOG-013.
- **M-4**: Neutral-phrasing requirement migrated from LOG-013 prose into `helper-contracts.md` §run-postcheck.sh **Output** as a normative MUST clause (`postcheck: no findings`, no iconography, no affirmative language). LOG-013 retains rationale only.
- **M-5**: FR-023 entry_type list reconciled with `helper-contracts.md` — explicit `{stage-start, stage-end, halt, abort, stage-skip, route, break-lock}` set named in both, with cross-reference to the contract.
- **M-6**: LOG-013 §Related — vestigial `spec FR-014` reference replaced with pointer to helper-contracts.md `run-postcheck.sh` §Output (M-4 contract migration target).
- **M-7**: PR3b-i description gained explicit "scope: this PR adds `speckit.run.md` and `test_command_loc.bats` only; no other files" sentence.
- **PR0 DoD**: PR0 description in plan.md now includes scope, files touched, test list (`test_check_prereqs_feature_dir_flag.bats`, ~3 cases), and ~50 LOC budget.

### Files modified (Re-Review #3 REVISE pass)
- `specs/010-autonomous-workflow/contracts/helper-contracts.md` (S-1 step-2 annotation; M-4 Output MUST clause)
- `.specify/memory/ADR_023_pre-route-linter-postcheck.md` (S-1 Decision §2 annotation)
- `specs/010-autonomous-workflow/plan.md` (PR0 DoD; PR2b LOC; PR3b-i scope + test co-location; PR3b-ii test cross-reference)
- `.specify/memory/LOG_013_rubber-stamp-dogfooding-risk.md` (Related field; mitigations 1+2 rewritten)
- `specs/010-autonomous-workflow/spec.md` (FR-023 entry_type reconciliation)

### Deferred
- LOG-014 (PR2b LOC estimation pattern) — write during/after `/speckit.tasks`, not before
- DA option (c) for LOG-013 (demote into LOG-011) — not surfaced for re-decision; deferred to retrospective
- PR0 file-DoD edge cases (unknown-arg behavior preservation) — to be confirmed during PR0 implementation

### Gate Status
**REVISE applied.** Minimum + ideal fix sets complete. State file is the audit record. No Re-Review #4 required — proceed to `/speckit.tasks`.

