# Tasks: Review Panel Benchmark

**Input**: Design documents from `specs/000-review-benchmark/`
**Branch**: `000-review-benchmark`
**Plan**: [plan.md](plan.md) | **Spec**: [spec.md](spec.md)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2)
- No application code — all deliverables are Markdown files

---

## Phase 1: Setup

**Purpose**: Initialize directory structure for benchmark artifacts and run outputs.

- [x] T001 Create `specs/000-review-benchmark/fixture/` directory (write a `.gitkeep` placeholder)
- [x] T002 Create `specs/000-review-benchmark/runs/` directory (write a `.gitkeep` placeholder — directory is populated at runtime by the command)

---

## Phase 2: Foundational — Fixture Artifacts (HARD GATE)

**Purpose**: Build the synthetic benchmark artifacts with planted issues. This phase MUST complete and pass pilot validation before any command work begins.

**⚠️ CRITICAL**: No User Story 1 or 2 work can begin until T007 (pilot validation) passes.

- [x] T003 [P] Write `specs/000-review-benchmark/fixture/spec.md` — convincing "User Notification Preferences" feature spec with PROD-1 (HIGH: missing admin persona), PROD-2 (MEDIUM: P1/P2 priority reversal), SEC-1 (HIGH: no authorization requirement / IDOR setup), and FALSE-1 (false positive: intentionally narrow scope that looks ambiguous) planted. Authorship rule: false positives must look exactly like the issue they mimic — not merely ambiguous, but actively mimicking the structure of a real gap so an agent raising it cannot be faulted for the reasoning. Do not name planted issues anywhere in the fixture.
- [x] T004 [P] Write `specs/000-review-benchmark/fixture/plan.md` — realistic technical plan with ARCH-1 (HIGH: single nullable-column preferences table with no ADR, doesn't scale to a 4th channel), ARCH-2 (MEDIUM: Redis dependency introduced for rate limiting but absent from the stack table with no ADR), SEC-2 (CRITICAL: rate limiting planned but not wired to preference-update endpoint), and FALSE-2 (false positive: architecture decision that appears underspecified but is intentionally deferred to a referenced existing ADR) planted. Authorship rule: false positives must look exactly like the issue they mimic — FALSE-2 must be written so an agent raising it cannot be faulted for the reasoning, and SEC-2 must require tracing the rate-limiting plan against the endpoint list to detect (not surface from the word "rate" alone). Do not name planted issues anywhere in the fixture. Each planted issue must require genuine content reasoning to detect — keyword matching on terms like "missing" or "undocumented" must not surface it (SC-005).
- [x] T005 [P] Write `specs/000-review-benchmark/fixture/tasks.md` — complete task list with DEL-1 (HIGH: test tasks for User Story 2 appear after implementation tasks by task ID — TDD violation), DEL-2 (MEDIUM: two [P]-marked tasks share a write to the same config file — hidden state conflict), ARCH-3 (MEDIUM: Redis setup task in Phase 3 instead of Phase 2, creating a hidden dependency for Story 2's rate-limiting tasks), and FALSE-3 (false positive: a task that looks like it's missing a test but the test is covered by an integration task two IDs later, clearly referenced) planted. Authorship rule: false positives must look exactly like the issue they mimic — FALSE-3 must be written so an agent raising it cannot be faulted for the reasoning on first read; only close inspection of the nearby integration task reveals coverage. Do not name planted issues anywhere in the fixture. Each planted issue must require genuine content reasoning to detect — keyword matching on terms like "missing" or "undocumented" must not surface it (SC-005).
- [x] T006 Write `specs/000-review-benchmark/benchmark-key.md` — 12-row scoring table with all PlantedIssue fields (id, type, severity, artifact, description, expected_catcher, overlap_risk, applicable_gate) covering all planted issues across T003–T005; exactly 4 rows per artifact (3 real issues + 1 false positive each); FALSE-* entries must have severity = "—" and expected_catcher = "none"; all other entries must have non-null values for both fields; `applicable_gate` must correctly map: spec.md issues → `spec`, plan.md issues → `plan`, tasks.md issues → `task`
- [x] T007 **Pilot validation (HARD GATE)**: Run `/speckit.review spec` (standard review, not profile) against `specs/000-review-benchmark/fixture/spec.md` only. **Context window note**: fixture/spec.md is the only artifact at the spec gate — confirm the review session completes without context-length errors before proceeding. Plan/task gate reviews (multi-artifact) are deferred; if context errors occur even at spec gate, reduce fixture length before proceeding.
  - **Pass criteria (PROD-1 and SEC-1)**: Both raised — AND the finding text does not reproduce ≥4 consecutive words from any single sentence in fixture/spec.md verbatim. This threshold distinguishes a finding built from reasoning (agent's own language, referencing the artifact's structure or implication) from one that copied a signal phrase. A finding that paraphrases is a pass; a finding that quotes is a fail.
  - **Pass criteria (FALSE-1)**: Either not raised, or raised with explicit hedging (e.g., "may," "unclear if," "could be intentional") at HIGH or lower. A definitive HIGH or MEDIUM finding with no hedging is a fail — the false-positive framing must be revised.
  - **Fail criteria**: Any finding reproduces ≥4 consecutive words from fixture/spec.md verbatim, OR FALSE-1 is raised as a definitive concern without hedging. Revise fixture/spec.md at that issue and re-run.
  - **Stopping condition**: If T007 has failed 3 consecutive times for the same planted issue after fixes, do not continue re-running. Instead, revisit the planted issue design: the issue type may be inherently too detectable in this artifact format. Document the finding and decide whether to replace the issue with a different type before proceeding.
  - **Too-obvious check**: After a passing run, scan findings for PROD-1 and SEC-1. If either was raised in ≤2 sentences with no cross-referencing of other artifact sections, the issue may be trivially obvious even without verbatim quoting. Optionally add more misleading context around that planted issue to increase reasoning depth before proceeding.

**Checkpoint**: ✅ Fixture pilot passed — command implementation can begin.

---

## Phase 3: User Story 1 — Single Benchmark Run (Priority: P1) 🎯 MVP

**Goal**: A maintainer can run `/speckit.review-profile spec --rigor FULL` and receive a full three-phase adversarial review of the fixture spec, followed by a Panel Efficiency Report that scores planted issue detection and identifies overlap.

**Independent Test**: Given `specs/000-review-benchmark/` exists with fixture/spec.md and benchmark-key.md, when a maintainer runs `/speckit.review-profile spec --rigor FULL`, the command produces a synthesis report followed by a Panel Efficiency Report containing: unique-contribution counts per agent, Overlap Clusters table (or logged warning if empty), False Positive Rate table, and Miss Rate table covering only the three spec-gate planted issues (PROD-1, PROD-2, SEC-1) and FALSE-1 — not all 12 — with a run file saved to `specs/000-review-benchmark/runs/YYYY-MM-DD-spec-FULL-run1.md`.

### Implementation for User Story 1

- [x] T008 [US1] Write `.claude/commands/speckit.review-profile.md` — complete review mode branch incorporating:
  - Argument detection: parse gate (`spec`/`plan`/`task`) and `--rigor` (`FULL`/`STANDARD`/`LIGHTWEIGHT`, default `FULL`); detect `--compare` flag and route to Branch B (Phase 4)
  - Gate-accurate panel composition per ADR-007 (matching production `/speckit.review`): spec/FULL = product-strategist + security-reviewer + devils-advocate; spec/STANDARD = product-strategist + devils-advocate; plan/FULL = systems-architect + security-reviewer + delivery-reviewer + devils-advocate; plan/STANDARD = systems-architect + security-reviewer + devils-advocate; task/FULL = delivery-reviewer + systems-architect + devils-advocate; task/STANDARD = delivery-reviewer + devils-advocate; LIGHTWEIGHT at any gate = devils-advocate only; synthesis-judge always added
  - Phase A: spawn panel agents in parallel, each receiving `fixture/[gate artifacts]` + CALIBRATION_BLOCK + finding-tag instruction (`[agent-name] | severity | category | location | finding`); benchmark-key.md is NOT in the artifact list (hard invariant)
  - Phase B: consensus summary → DA challenge → specialist responses (per standard speckit.review protocol)
  - Phase C: synthesis judge with overlap-verdict instruction; judge must produce Overlap Clusters table (`| Finding Topic | Agents | Overlap Type | Verdict |`); log warning and skip overlap table if schema absent — do not fail the run
  - Scoring pass (benchmark-key.md read HERE for the first time, step 7 only): (a) contamination check — scan all Phase A findings for verbatim issue IDs (e.g., `PROD-1`, `SEC-1`) — match full IDs only, not prefixes like `SEC` or `PROD` alone; if found, output `CONTAMINATION DETECTED`, abort scoring, prompt re-run; (b) filter benchmark-key.md to `applicable_gate = current gate` — out-of-gate issues are excluded from the denominator entirely, not counted as Missed; (c) score each applicable PlantedIssue against Phase A findings per FR-006 rules: Caught = finding references correct artifact section + core problem area; Caught (partial) = correct artifact but wrong framing or partial identification only; Missed = no finding addresses the issue; (d) compute unique contribution, overlap clusters, FP records, scored issues
  - Panel Efficiency Report: append to terminal with Limitations header — header must state: scoring requires semantic judgment; absolute detection rates have unknown error margin; only deltas between same-scorer same-model runs are reliably interpretable (per validity model in plan.md); save to `specs/000-review-benchmark/runs/YYYY-MM-DD-<gate>-<RIGOR>-run<N>.md` (increment run N if same-day same-gate same-rigor file exists); include maintenance note that panel compositions must stay in sync with `.claude/commands/speckit.review.md`
- [x] T009 [US1] Validate review mode — run `/speckit.review-profile spec --rigor FULL` and verify: (a) Panel Efficiency Report appears with Limitations header (FR-007, plan.md §Validity Model); (b) Miss Rate table contains only PROD-1, PROD-2, SEC-1, FALSE-1 — not all 12 planted issues (gate-scoped scoring, data-model §applicable_gate); (c) Overlap Clusters table is populated or a warning is logged (FR-005); (d) run file saved to `specs/000-review-benchmark/runs/` with correct filename format (FR-007); (e) no contamination flag raised if benchmark-key.md was not in agent context (FR-003)

**Checkpoint**: ✅ US1 complete — single benchmark run working, run file exists.

---

## Phase 4: User Story 2 — Rigor Level Comparison (Priority: P2)

**Goal**: A maintainer can run the benchmark at FULL, STANDARD, and LIGHTWEIGHT, then use `--compare` to produce a single Coverage by Rigor Level table showing which planted issues each panel catches and an explicit PASS/FAIL verdict for STANDARD.

**Independent Test**: Given the benchmark and `/speckit.review-profile` exist from US1, when a maintainer runs all three rigor levels and then `--compare spec`, the output is a single table with all spec-gate planted issues × all three rigor levels and an explicit PASS/FAIL verdict for STANDARD (PASS = zero CRITICAL planted issues missed; FAIL = one or more missed).

### Implementation for User Story 2

- [x] T010 [US2] Extend `.claude/commands/speckit.review-profile.md` with the `--compare` branch (Branch B): detect gate from arguments; find the most recent run file for each rigor level at that gate in `specs/000-review-benchmark/runs/` (lexicographic sort, highest run-N wins on same-day tie); extract Miss Rate tables from each file; build Coverage by Rigor Level table (`| Issue ID | Severity | FULL | STANDARD | LIGHTWEIGHT |`); compute PASS/FAIL verdict for STANDARD (PASS = zero CRITICAL issues missed); output to terminal; display run dates prominently; **validity pre-condition**: before displaying the comparison table, output the note: "⚠️ Validity condition: these comparisons are only meaningful when all three runs used the same Claude model version and the same FR-006 scoring rule text. If model versions differ across runs, deltas may reflect scorer variance rather than panel differences." (per plan.md §Validity Model); error states: missing run file for a rigor level → instruct to run that rigor level first; all three missing → instruct to run all rigor levels first; fixture/ directory missing → direct user to run benchmark setup tasks first; exact message format for all three states defined in contracts §Error States
- [x] T011 [P] [US2] Run `/speckit.review-profile spec --rigor STANDARD` — verify STANDARD run file saved to `specs/000-review-benchmark/runs/YYYY-MM-DD-spec-STANDARD-run1.md` with Panel Efficiency Report and Limitations header
- [x] T012 [P] [US2] Run `/speckit.review-profile spec --rigor LIGHTWEIGHT` — verify LIGHTWEIGHT run file saved to `specs/000-review-benchmark/runs/YYYY-MM-DD-spec-LIGHTWEIGHT-run1.md` with Panel Efficiency Report and Limitations header
- [x] T013 [US2] Validate compare mode — run `/speckit.review-profile --compare spec` and verify: (a) Coverage by Rigor Level table covers all four spec-gate planted issues (PROD-1, PROD-2, SEC-1, FALSE-1); (b) STANDARD verdict is explicitly PASS or FAIL with basis stated; (c) run dates for each rigor level are displayed; (d) no run file is written (compare mode is terminal-only per contract)

**Checkpoint**: ✅ US2 complete — three-way rigor comparison working.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Documentation updates and final validation across all deliverables.

- [x] T014 [P] Update `specs/000-review-benchmark/quickstart.md` §Known Limitations to document the falsification criteria: (1) if any rigor level scores ≥95% catch rate across all HIGH/CRITICAL issues, the fixture may be too obvious from repeated exposure — consider refreshing; (2) if FULL and LIGHTWEIGHT produce identical Miss Rate tables across two consecutive runs, planted issues may be trivially detectable regardless of panel size. Also note any actual vs. expected detection rate differences surfaced by calibration runs.
- [x] T015 [P] Verify `specs/000-review-benchmark/plan.md` Decision Records table includes ADR-007 (gate-accurate panel composition) — added during plan gate review; confirm the entry is present and linked correctly
- [x] T016 Run `quickstart.md` end-to-end validation: follow all steps in quickstart.md from Prerequisites through Compare three runs and confirm the output matches documented expected behavior
- [x] T017 [P] Update `CLAUDE.md` §Recent Changes to document the new `/speckit.review-profile` command and the `specs/000-review-benchmark/fixture/` and `runs/` directory structure

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup; BLOCKS all user stories until T007 pilot passes
- **US1 (Phase 3)**: Depends on Foundational phase + pilot validation (T007) — T008–T009
- **US2 (Phase 4)**: T010 (--compare branch) depends on T008 (command file); T011 and T012 depend on T008 (command must exist to run); T013 depends on T009, T011, T012
- **Polish (Phase 5)**: Depends on T013 (all runs complete)

### User Story Dependencies

- **US1 (P1)**: Depends on Foundational complete + pilot validation passed — no dependency on US2
- **US2 (P2)**: Depends on US1 complete (command must exist and have produced one FULL run) — T011 and T012 can run in parallel with each other once T008 is complete

### Pilot Validation Gate (T007)

If T007 fails, the failure mode determines the fix:
- Planted issue raised by quoting exact signal text → rewrite the fixture content around that issue to obscure the signal; re-run T007
- FALSE-1 raised confidently as a real gap → make the scoping language clearer or add a more visible narrow-scope qualifier; re-run T007
- No planted issue caught at all → fixture too subtle; add more implicit (not explicit) signal; re-run T007

Do NOT proceed to T008 until T007 passes.

### Parallel Opportunities

```
# Phase 2 — fixture files can be written in parallel:
Task T003: Write fixture/spec.md
Task T004: Write fixture/plan.md
Task T005: Write fixture/tasks.md

# Phase 4 — STANDARD and LIGHTWEIGHT runs can be run in parallel (after T010):
Task T011: Run /speckit.review-profile spec --rigor STANDARD
Task T012: Run /speckit.review-profile spec --rigor LIGHTWEIGHT
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001–T002)
2. Complete Phase 2: Fixture + Pilot Validation (T003–T007) — **HARD GATE**
3. Complete Phase 3: Review Profile Command (T008–T009)
4. **STOP and VALIDATE**: `/speckit.review-profile spec --rigor FULL` produces a valid Panel Efficiency Report with a run file
5. US1 is independently demonstrable here

### Incremental Delivery

1. Setup + Foundational → fixture artifacts validated
2. US1 → single benchmark run working → MVP
3. US2 → rigor level comparison working → full calibration workflow

### Single-Maintainer Note

All tasks are sequential by default (no team parallelism required). The [P] markers indicate tasks that can be parallelized if running multiple agent sessions simultaneously; for single-session work, execute in T001–T016 order with the exception that T003, T004, T005 can be interleaved in any order before T006.

---

## Notes

- All deliverables are Markdown files — no compilation, no test runner, no package manager
- "Tests" for this feature are benchmark runs (T007, T009, T013) — manual execution and output inspection
- TDD equivalent: pilot validation (T007) MUST run and pass before writing the command (T008) — the fixture is the test harness, the command is the implementation
- benchmark-key.md (T006) MUST NOT be referenced in any agent prompt during T007, T009, T011, T012
- Commit after each logical group: after T006 (fixture complete), after T009 (US1 complete), after T013 (US2 complete)
- Panel composition maintenance: if `.claude/commands/speckit.review.md` panel compositions change after this feature is merged, `.claude/commands/speckit.review-profile.md` MUST be updated in sync (noted as maintenance dependency in ADR-007)
