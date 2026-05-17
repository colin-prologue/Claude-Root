---
description: "Task list for /speckit.run autonomous pipeline orchestrator (V1)"
---

# Tasks: Autonomous Pipeline Orchestration (`/speckit.run`)

**Input**: Design documents from `/specs/010-autonomous-workflow/`
**Prerequisites**: plan.md (read), spec.md (read), research.md, data-model.md, contracts/{decision-log-entry, sidecar-event, helper-contracts}.md, quickstart.md

**Tests**: REQUIRED. Per ADR-017 (hybrid TDD strategy), the deterministic core (Tier 1: bats unit) is TDD-strict and the LLM-call boundary (Tier 2: smoke) is contract-cap-bounded. No test tasks may be deferred.

**Organization**: Tasks are grouped by user story. US-1 (single-trigger pipeline) is the MVP and carries the bulk of implementation. US-2 (decision-log review) and US-4 (resume after interruption) are scenario-coverage phases that exercise the same helpers from US-1 against story-specific fixtures and assertions. US-3 is DEFERRED to V2 per ADR-015 and produces no tasks here.

**PR-to-task mapping** (per plan.md split):

| PR | Tasks | LOC est. |
|---|---|---|
| PR0 — precursor `--feature-dir` flag | T003–T004 | ~50 |
| PR1 — foundation helpers | T005–T011 | ~280 |
| PR2a — schema validation | T012–T013 | ~150 |
| PR2b — verdict-receipt triplet (constitutional exception) | T014–T019 | ~500–600 |
| PR3a — code-action helpers | T020–T023 | ~190 |
| PR3b-i — slash-command markdown + LOC test | T024–T025 | ~255 |
| PR3b-ii — integration + static-grep guard | T026, T027, T029, T030 | ~120 |
| PR4 — smoke harness + 2 fixtures + docs | T037–T042 | ~300 |

## Path Conventions

- **Single project, no app/server**: orchestrator surface is `.claude/commands/speckit.run.md`; deterministic core is `.specify/scripts/bash/run-*.sh`; tests live under a new `tests/` root.
- All paths absolute from repo root: `/Users/colindwan/Developer/Claude-Root/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the new `tests/` test root (the project's first) and document tier conventions.

- [X] T001 Create directory `tests/unit/` and `tests/smoke/fixtures/` at repo root
- [X] T002 Create `tests/README.md` documenting Tier 1 (bats unit, pre-commit) vs Tier 2 (smoke, pre-merge, cost-capped) per ADR-017 and how to run each locally

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Land prerequisites that every user story depends on. PR0 (the `check-prerequisites.sh --feature-dir` flag) is named as a precursor in plan.md and helper-contracts.md L204; without it, `run-postcheck.sh` cannot be implemented to its contract. `run-common.sh` is sourced by every other `run-*.sh` helper.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

**Intra-phase ordering**: PR0 (T003, T004) and Shared helper utilities (T005) are **independent within Phase 2** — they share no code paths and may land in either order. PR0 is a separable precursor PR; T005 is pulled into PR1 in the PR-to-task mapping. Both must be in `main` before Phase 3 begins.

### PR0 — `check-prerequisites.sh --feature-dir` precursor

- [X] T003 Write bats tests for `--feature-dir` flag in `tests/unit/test_check_prereqs_feature_dir_flag.bats` covering: (a) `--feature-dir <matching>` honored, (b) `--feature-dir <non-matching-branch>` overrides branch derivation, (c) missing path errors with exit 1
- [X] T004 Extend `.specify/scripts/bash/check-prerequisites.sh` and `.specify/scripts/bash/common.sh::find_feature_dir_by_prefix()` to accept `--feature-dir <path>` overriding branch-name-derived default; preserve unknown-arg behavior for non-`--feature-dir` flags

### Shared helper utilities

- [X] T005 Implement `.specify/scripts/bash/run-common.sh` providing `_run_lock_dir`, `_atomic_rename_into`, `_emit_canonical_entry`, `_sweep_tmp`, `_run_id_of_lock`, `_hash_input` per helper-contracts.md §`run-common.sh`. No dedicated bats file (tested indirectly via consumers per ADR-019 single-purpose convention)

**Checkpoint**: Foundation ready — user story 1 implementation can now begin

---

## Phase 3: User Story 1 — Single-Trigger Pipeline Execution (Priority: P1) 🎯 MVP

**Goal**: A developer invokes `/speckit.run --target "specify→review→clarify→plan→review→tasks"` and the session executes all six stages, producing all artifacts in `specs/[###-feature-name]/`, pausing only at configured BLOCKING gates and at code-action gates.

**Independent Test**: Given a developer who invokes `/speckit.run` with a feature description and the target above, the session completes all six stages, produces `spec.md`, review summary entries, `plan.md`, and `tasks.md` in the correct spec directory, and presents a summary — without requiring six separate slash-command invocations. (Matches spec.md US-1 Independent Test.)

### PR1 — Foundation helpers (FR-009, FR-026, FR-027, FR-028, ADR-018)

> **TDD ordering**: each helper's bats file is written and verified to fail before the helper is implemented. Helper/test pairs land as commit pairs per plan.md "Intra-PR commit discipline."

- [X] T006 [P] [US1] Write `tests/unit/test_lock.bats` covering acquire/release/break (FR-027/FR-028, ADR-018), atomic abort-sentinel cleanup, stale-receipt wipe on acquire (ADR-022), `.run/*.tmp` sweep on acquire (LOG-012), exit-code matrix per helper-contracts.md §`run-lock.sh`
- [X] T007 [US1] Implement `.specify/scripts/bash/run-lock.sh` (commands: `acquire | release | break | check-sentinel`) per helper-contracts.md §`run-lock.sh` (depends on T005, T006)
- [X] T008 [P] [US1] Write `tests/unit/test_target.bats` covering FR-009 contiguous-subsequence validation, the review-contiguity grammar (data-model.md E-6: review allowed between non-code stages, at most one per gap, never adjacent to code-action stages, never at start/end), and `next` exhaustion sentinel `__END__`
- [X] T009 [US1] Implement `.specify/scripts/bash/run-target.sh` (commands: `validate | next`) per helper-contracts.md §`run-target.sh` (depends on T005, T008)
- [X] T010 [P] [US1] Write `tests/unit/test_completeness.bats` covering FR-026 V1 predicates per data-model.md E-7: `specify`/`plan`/`tasks`/`review`/`clarify`/`analyze`/`implement`/`codereview`/`audit` (last three unconditionally `incomplete`)
- [X] T011 [US1] Implement `.specify/scripts/bash/run-completeness.sh <feature-dir> <stage>` per helper-contracts.md §`run-completeness.sh` (depends on T005, T010)

### PR2a — Schema validation (FR-006)

- [ ] T012 [US1] Write `tests/unit/test_validate_entry.bats` (~6–10 cases at 15–20 LOC each) covering decision-log-entry.md §Validation contract: heading regex, required key-value fields, `status` enum, `author` regex, subagent-record three-sub-block requirement, `halt_directive.halt=true` reason requirement, **`halt_directive.failure_class` ∈ {`temporal`, `semantic`, `permission`} when `halt=true` (FR-019 three-class taxonomy) — missing or unrecognized class fails validation**, malformed-entry diagnostics
- [ ] T013 [US1] Implement `.specify/scripts/bash/run-validate-entry.sh` per decision-log-entry.md §Validation contract (depends on T005, T012)

### PR2b — Verdict-receipt triplet (ADR-019, ADR-020, ADR-022; constitutional exception per plan.md PR2b)

> **Constitutional exception**: this sub-phase ships three helpers + their tests as a coherent unit because the verdict-receipt protocol's correctness is unverifiable in helper isolation. PR description must restate this; if implementation lands above 600 LOC, re-justify in PR description (per plan.md M-2 amendment). LOG-014 tracks the LOC-estimation pattern.

- [ ] T014 [US1] Write `tests/unit/test_decide_next.bats` covering ADR-019 routing matrix + ADR-022 verdict-receipt mint + sentinel fold-in: `continue` / `halt:<reason>` / `skip:<stage>` / `abort` outputs; pre-flight omission check (refuse-to-mint when receipt non-empty, write `verdict-omitted` canonical entry); resume-scan filter (skip `verdict-mismatch`/`verdict-omitted`/`pipeline-incomplete` per FR-023, RC-5); halt-reason enumeration (`subagent-halt-directive`, `schema-violation`, `code-gate-blocking`, `multi-blocker-collected`, `postcheck-failed`, `verdict-mismatch`); receipt format `<verdict>\t<run_id>\t<input_hash>\t<ts>`. **Covers FR-021** (multi-blocker-collected halt aggregation per data-model.md routing matrix) and **FR-025** (below-threshold-continue: review subagent without halt directive ⇒ `continue` output, findings still in subagent record)
- [ ] T015 [US1] Write `tests/unit/test_emit_event.bats` covering ADR-020 JSONL emission + ADR-022 receipt validation: matched route consumes receipt; mismatched route refuses with exit 1 and writes `verdict-mismatch` canonical entry; missing receipt = mismatched receipt; second emission without fresh verdict refuses identically; stale cross-run receipt fails on `run_id` mismatch; `stage-start`/`stage-skip`/`break-lock`/`budget-exhausted` emit without receipt; **`stage-skip` events MUST carry a non-empty `criterion` field — silent skips fail the test (FR-024)**; truncation tolerance (last malformed line dropped silently). **Covers FR-024** (empty-output stage produces explicit `stage-skip` entry with criterion)
- [ ] T016 [US1] Write `tests/unit/test_serialize.bats` covering ADR-016 MUST-coalesce + ADR-022 step-6 completeness invariant: stage-then-rename success + cold-start (no prior `decisions-log.md`); empty sidecar tolerated; sidecar unparseable → exit 1 (caller proceeds to `release`); invariant violation writes `pipeline-incomplete` canonical entry then appends coalesced summary; both invariant branches (a: receipt non-empty; b: missing routing event for stage record)
- [ ] T017 [US1] Implement `.specify/scripts/bash/run-decide-next.sh` per helper-contracts.md §`run-decide-next.sh` (depends on T005, T013, T014)
- [ ] T018 [US1] Implement `.specify/scripts/bash/run-emit-event.sh` per helper-contracts.md §`run-emit-event.sh` and sidecar-event.md (depends on T005, T013, T015)
- [ ] T019 [US1] Implement `.specify/scripts/bash/run-serialize.sh` per helper-contracts.md §`run-serialize.sh` (depends on T005, T016)

### PR3a — Code-action helpers (FR-020, ADR-023)

- [ ] T020 [P] [US1] Write `tests/unit/test_check_sandbox.bats` covering FR-020 allowlist per data-model.md E-8: ALLOWED paths (specs/[###]/, project source); DISALLOWED (`main` mutations, force-push reflog, `.gitignore`, `.github/`, `.claude/settings*.json`, `.claude/hooks/`, `.env*`); per-violation diagnostic format `<path>: <reason>`
- [ ] T021 [US1] Implement `.specify/scripts/bash/run-check-sandbox.sh <feature-dir> <stage>` per helper-contracts.md §`run-check-sandbox.sh` (depends on T005, T020)
- [ ] T022 [P] [US1] Write `tests/unit/test_postcheck.bats` covering ADR-023: invokes `check-adr-crossrefs.sh` (Principle VII) and `check-prerequisites.sh --feature-dir <feature-dir>`; `stage=implement` cross-checks claimed test files against `git ls-files`; clean-exit emits exactly the neutral line `postcheck: no findings` (per Re-Review #3 M-4 / LOG-013 — no iconography, no "✓", no "all checks passed"); failure emits `<check>: <detail>` per finding; non-code stages out of scope per LOG-010
- [ ] T023 [US1] Implement `.specify/scripts/bash/run-postcheck.sh <feature-dir> <stage>` per helper-contracts.md §`run-postcheck.sh` (depends on T005, T004 PR0 precursor, T022)

### PR3b-i — Slash command + LOC cap (FR-008, FR-012, FR-016, FR-017, ADR-014, ADR-019)

> **Scope per plan.md M-7**: this sub-phase adds `speckit.run.md` and `test_command_loc.bats` only.

- [ ] T024 [US1] Write `tests/unit/test_command_loc.bats` asserting `.claude/commands/speckit.run.md` ≤ 250 lines (markdown file hard cap per plan.md PR3b-i; co-located with the artifact per Re-Review #3 M-1)
- [ ] T025 [US1] Implement `.claude/commands/speckit.run.md` (≤ 250 lines) — slash-command markdown specifying: `--target` / `--checkpoints` / `--force` / `--break-lock` flags; per-stage invocation sequence (`run-lock acquire` → loop: `run-completeness` → dispatch subagent → `run-validate-entry` → if code-action `run-check-sandbox` + `run-postcheck` → `run-decide-next` → `run-emit-event` → next stage); BLOCKING-everywhere posture (ADR-014); subagent dispatch instructions naming the FR-006 schema as the contract; halt-presentation UX (FR-019 self-contained halt messages per quickstart.md §When the orchestrator halts); `run-serialize` before `run-lock release` on every termination path; sentinel-fold-in via `run-decide-next` (no separate `check-sentinel` invocation between dispatches per ADR-019 b1 amendment) (depends on T024 and all helper tasks T007/T009/T011/T013/T017/T018/T019/T021/T023)

### PR3b-ii — Integration tests + static-grep guard

- [ ] T026 [P] [US1] Write `tests/unit/test_command_static_grep.bats` asserting `.claude/commands/speckit.run.md` invokes `run-decide-next.sh` and `run-emit-event.sh` for every routing point in the prescribed sequence (ADR-022 step 6 mitigation; catches authoring drift before runtime per helper-contracts.md §Verdict-Receipt Protocol)
- [ ] T027 [P] [US1] Write `tests/unit/test_integration_invocation_sequence.bats` exercising the full per-stage sequence (lock → completeness → dispatch → validate → postcheck → decide-next → emit) end-to-end at the helper layer (no real subagent dispatch — fixtures stand in for subagent output)

### FR-specific integration tests (PR3b-ii — exercise orchestrator/slash-command behavior beyond any single helper)

> **FR-021, FR-024, FR-025 folded into PR2b** (helper-level coverage in T014/T015 — see task body annotations). FR-022 and FR-023 remain integration scenarios because they exercise cross-stage sequencing and slash-command flag handling respectively.

- [ ] T029 [P] [US1] Write `tests/unit/test_clarification_serial.bats` covering FR-022: two adjacent stages requiring clarification serialize — first surfaced and resolved before second is dispatched
- [ ] T030 [P] [US1] Write `tests/unit/test_spec_already_exists.bats` covering FR-023: `spec.md` exists + `decisions-log.md` present ⇒ resume; `spec.md` exists + no `decisions-log.md` ⇒ require `--force`; resume-scan filter excludes the three canonical-exception entry types

**Checkpoint**: User Story 1 functional at the helper + slash-command layer. Tier 1 covers the deterministic surface; Tier 2 smoke (Phase 6) closes the LLM-call boundary.

---

## Phase 4: User Story 2 — Decision Log Review (Priority: P2)

**Goal**: After a completed run, the developer can read `decisions-log.md` and reconstruct the full reasoning path — every decision, rationale, and alternative. The schema enforcement and coalesced-summary writing are already implemented in US-1 (T013, T019); this phase verifies the audit-trail properties.

**Independent Test**: Given a completed pipeline run through `specify→review→clarify→plan→review→tasks`, when the developer requests the decision log, a structured document exists at `specs/[###-feature-name]/decisions-log.md` listing every autonomous decision with rationale and alternatives. (Matches spec.md US-2 Independent Test.)

- [x] T033 [US2] Write `tests/unit/test_log_chronological_order.bats` asserting that for a fixture run with multiple subagent records, entries appear in chronological order (timestamp-monotonic) and the coalesced control-flow summary appears at the tail (after all subagent records, per ADR-016 termination append)
- [x] T034 [US2] Write `tests/unit/test_log_audit_completeness.bats` asserting that for a fixture run including a route-back-to-specify scenario (US-2 Acceptance Scenario 2): the originating finding, the revision, and the re-review outcome are all present in the canonical log; and that an autonomous skip decision (US-2 Acceptance Scenario 1) records the criterion that produced the skip

**Checkpoint**: User Story 2 verifiable independently against fixture decision logs

---

## Phase 5: User Story 4 — Pipeline Resume After Interruption (Priority: P2)

**Goal**: Developer-triggered resume picks up from the first incomplete stage without re-running stages whose artifacts pass FR-026 completeness predicates. The resume-scan filter (FR-023, RC-5) lives in `run-decide-next.sh` (T017); this phase exercises resume scenarios.

**Independent Test**: Given a pipeline run that completed `specify→review→clarify` before being interrupted, when the developer restarts and requests resume, the orchestrator picks up at `plan` without re-running the first three stages, and the existing `spec.md` and decision log are preserved. (Matches spec.md US-4 Independent Test.)

- [x] T035 [US4] Write `tests/unit/test_resume_skip_complete_artifacts.bats` exercising US-4 Acceptance Scenario 1: fixture with complete `spec.md` + `plan.md` (passes FR-026) ⇒ orchestrator detects complete state, identifies next uncompleted stage, dispatches there; artifact mtimes unchanged after resume (SC-003 verification)
- [x] T036 [US4] Write `tests/unit/test_resume_scan_filter.bats` exercising the canonical-exception filter on resume (FR-023, RC-5): fixture log ending with `pipeline-incomplete` and/or `verdict-mismatch` ⇒ resume anchors on the latest valid stage record (`stage-start`/`stage-end`/`halt`/`abort`/`stage-skip`/`route`/`break-lock`), never on a canonical-exception entry; mid-stage interruption (US-4 Acceptance Scenario 2) re-runs the incomplete stage from the beginning rather than reconstructing partial output; **all three FR-019 failure classes surface failure-class + retrigger command on resume — fixtures cover (a) `temporal` (rate-limit halt), (b) `semantic` (schema-violation halt), and (c) `permission` (sandbox-violation per FR-020 halt)** (US-4 Acceptance Scenario 3)

**Checkpoint**: User Story 4 verifiable independently against resume fixtures

---

## Phase 6: Polish & Cross-Cutting Concerns (PR4 — Smoke harness)

**Purpose**: Close the LLM-call boundary per ADR-017 Tier 2 + ADR-021 fixture budget. Two synthetic fixtures (one green-path, one halt-path) at a 50K token per-run / 100K per-merge cap.

- [x] T037 [P] Write `tests/smoke/fixtures/feature-min-path.txt` — synthetic feature description producing a green-path `specify→plan` run (ADR-021 Fixture 1)
- [x] T038 [P] Write `tests/smoke/fixtures/feature-halt-on-specify.txt` — synthetic feature description where the spec subagent emits `halt_directive=true` (ADR-021 Fixture 2; verifies MUST-coalesce + verdict-receipt on halt path)
- [x] T039 Write `tests/smoke/fixture_min_path.bats` invoking `/speckit.run` against fixture 1 with real subagent dispatches; asserts artifacts produced + canonical-log conformance + sidecar-canonical reconciliation
- [x] T040 Write `tests/smoke/fixture_halt_on_specify.bats` invoking `/speckit.run` against fixture 2; asserts halt presented + coalesced summary appended on halt + verdict-receipt consumed
- [x] T041 Implement smoke harness inside the two bats files (per-run token-cost reading + per-merge cap enforcement, exit non-zero on cap breach per ADR-021)
- [x] T042 Update `CLAUDE.md` Recent Changes section to record `/speckit.run` shipping; add `tests/` to Directory Structure; add bats-core as a soft dependency note (not a runtime requirement — only required to run Tier 1 tests locally)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: T001–T002 — no dependencies
- **Foundational (Phase 2)**: T003–T005 — depends on Phase 1; BLOCKS all user stories
- **US-1 (Phase 3)**: depends on Phase 2 complete; the bulk of implementation
- **US-2 (Phase 4)**: depends on T013 (`run-validate-entry.sh`) + T019 (`run-serialize.sh`)
- **US-4 (Phase 5)**: depends on T011 (`run-completeness.sh`) + T017 (`run-decide-next.sh`)
- **Polish (Phase 6)**: depends on T025 (slash command) + all helpers

### Within US-1 — sub-PR ordering (per plan.md "Splits into 7 PRs")

```
PR0 (T003–T004) ──┐
                  ├──▶ PR1 (T006–T011) ──▶ PR2a (T012–T013) ──▶ PR2b (T014–T019) ──▶ PR3a (T020–T023) ──▶ PR3b-i (T024–T025) ──▶ PR3b-ii (T026, T027, T029, T030) ──▶ PR4 (T037–T042)
T005 (run-common) ┘
```

PR0 and `run-common.sh` can land in either order but both must precede PR1. PR3a depends on PR2b *only* for the test fixture's invocation-order assumption (per plan.md PR3a definition). PR4 depends on PR3b-ii.

### Within Each Sub-PR — TDD ordering (NON-NEGOTIABLE)

- Tests written and verified to FAIL before the helper they exercise is implemented (Principle III)
- Helper/test pairs land as commit pairs per plan.md "Intra-PR commit discipline"
- PR2b is a constitutional exception: three helpers + their tests ship as one PR but the per-helper commit ordering inside is preserved (test commit, then helper commit, three times)

### Parallel Opportunities

- **Phase 1**: T001 + T002 are sequential (T002 references the directories T001 creates)
- **PR1**: T006/T008/T010 (test-writing for three independent helpers) can run in parallel; their helper implementations T007/T009/T011 then follow each test
- **PR2b**: T014/T015/T016 (three test files for three helpers) can run in parallel; T017/T018/T019 implementations are sequential within the PR per the constitutional-exception ordering
- **PR3a**: T020 + T022 (two independent test files) can run in parallel
- **PR3b-ii**: T026 + T027 + T029 + T030 in parallel — different fixture files, no shared state
- **Phase 4**: T033 + T034 in parallel (different fixtures, different bats files)
- **Phase 5**: T035 + T036 in parallel
- **Phase 6**: T037 + T038 in parallel (different fixture text files); T039 + T040 in parallel (different bats files)

---

## Parallel Example: PR1 (Foundation Helpers)

```bash
# Phase 2 done. Launch all three Tier 1 test files for PR1 in parallel:
Task: "Write tests/unit/test_lock.bats covering FR-027/FR-028/ADR-018"           # T006
Task: "Write tests/unit/test_target.bats covering FR-009 + review-contiguity"    # T008
Task: "Write tests/unit/test_completeness.bats covering FR-026 V1 predicates"    # T010

# Then implement each helper, verifying its tests pass:
Task: "Implement run-lock.sh"                  # T007
Task: "Implement run-target.sh"                # T009
Task: "Implement run-completeness.sh"          # T011
```

---

## Implementation Strategy

### MVP First (US-1 only)

1. Phase 1 — `tests/` root + README
2. Phase 2 — PR0 precursor + `run-common.sh`
3. Phase 3 — all 24 US-1 tasks (T006–T030 minus deleted T028/T031/T032 — fold-ins covered in T014/T015), landing as 6 PRs (PR1, PR2a, PR2b, PR3a, PR3b-i, PR3b-ii)
4. **STOP and VALIDATE** — invoke `/speckit.run` against a synthetic fixture; verify the BLOCKING-everywhere posture (SC-006), abort latency (SC-007), and intervention count (SC-001)
5. PR4 (T037–T042) closes the smoke tier and updates CLAUDE.md

### Incremental Delivery

US-1 alone is shippable. US-2 ships free with US-1's `run-validate-entry.sh` + `run-serialize.sh` — Phase 4's tasks are scenario verification, not new implementation. US-4 likewise verifies behavior already implemented in `run-decide-next.sh` (resume-scan filter is part of T017's contract). Phase 6 (smoke) is the only phase that can be deferred — but it should land before /speckit.run is dogfooded for SC-008's 30-day evaluation, since smoke catches LLM-boundary regressions Tier 1 cannot.

### SC-008 Dogfooding Gate

Per ADR-015 amendment, V1 ships and is evaluated over ≥5 full runs in ≥30 days. SC-008 (a) never met across that window ⇒ retire `/speckit.run` (LOG-005 stage-pair runner becomes V1.5). SC-008 (b) violated even once ⇒ re-evaluate BLOCKING-everywhere posture before any V2 expansion. The dogfooding measurement is a feature-level outcome, not a task — it informs whether to spawn an `011-` follow-up.

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks at the time of execution
- [Story] label maps task to specific user story for traceability; Setup, Foundational, and Polish phases carry no story label
- US-3 is DEFERRED to V2 per ADR-015; no tasks generated
- Tests use bats-core; install locally per `tests/README.md` (T002)
- Per Principle III, tests MUST FAIL before their corresponding helper is implemented; commit ordering enforces this (test commit precedes helper commit in every pair)
- Per project convention (`.claude/rules/conventions.md`): commit after each completed task; PRs target ≤300 LOC except PR2b which is a documented constitutional exception (~500–600 LOC)
- Per `.claude/rules/conventions.md`: no `.decisions/`, `phi/`, or `cdrs/` directories — meta-patterns belong in oracle bank, not this repo
- The orchestrator never modifies `.gitignore` at runtime (FR-020); the `.run/` ignore was landed at template-setup time per ADR-012 amendment
