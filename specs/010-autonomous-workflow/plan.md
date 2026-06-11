# Implementation Plan: Autonomous Pipeline Orchestration

**Branch**: `010-autonomous-workflow` | **Date**: 2026-04-26 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/010-autonomous-workflow/spec.md`

## Summary

`/speckit.run` is a **slash command + bash-helper** orchestrator. The Claude Code main session, invoked through the slash command, dispatches a fresh subagent per pipeline stage (ADR-009), reads the canonical `decisions-log.md` written by each subagent (ADR-013/ADR-016), and routes via deterministic bash helpers (ADR-019). All control-flow primitives — lock acquisition, completeness predicates, target-pipeline validation, sentinel checking, schema validation, sidecar emission, route decisions — live in `.specify/scripts/bash/run-*.sh` so that Tier 1 unit tests (ADR-017) cover the orchestrator's full deterministic surface. The LLM's only non-deterministic responsibility is dispatching subagents and presenting BLOCKING checkpoints to the developer (ADR-014).

V1 ships single-mode BLOCKING-everywhere (ADR-014, ADR-015), single-session lifecycle, in-session resume only, and `--break-lock` as the sole stale-lock recovery (ADR-018). Cross-session resume, OBSERVING mode, and the learning-loop checkpoint files are deferred to V2.

## Decision Records

| # | Type | File | Title | Status |
|---|---|---|---|---|
| ADR-008 | Decision | ADR_008_speckit-run-trigger.md | `/speckit.run` as orchestrator trigger | Accepted |
| ADR-009 | Decision | ADR_009_subagent-per-stage-execution.md | Subagent-per-stage execution model | Accepted |
| ADR-010 | Decision | ADR_010_decision-log-threshold.md | Stage-boundary threshold for decision log | Accepted (amended by ADR-013) |
| ADR-011 | Decision | ADR_011_failure-handling-three-class.md | Three-class failure handling | Accepted (amended by ADR-015) |
| ADR-012 | Decision | ADR_012_branch-scoped-sandbox.md | Branch-scoped sandbox + `.run/` runtime placement | Accepted |
| ADR-013 | Decision | ADR_013_subagent-writes-decision-log.md | Subagent writes decision-log entry directly to disk | Proposed (refined by ADR-016) |
| ADR-014 | Decision | ADR_014_blocking-by-default-code-gates.md | BLOCKING-by-default at code-action gates in V1 | Proposed |
| ADR-015 | Decision | ADR_015_v1-scope-boundary.md | V1 scope boundary — trust first, defer learning loop | Proposed |
| ADR-016 | Decision | ADR_016_decision-log-canonical-derivative.md | Decision-log canonical/derivative model | Proposed |
| ADR-017 | Decision | ADR_017_tdd-strategy-hybrid.md | Hybrid test strategy for non-deterministic dispatcher | Proposed (closes LOG-006) |
| ADR-018 | Decision | ADR_018_stale-lock-recovery-break-lock.md | Stale-lock recovery — `--break-lock` only in V1 | Proposed (closes LOG-009) |
| ADR-019 | Decision | ADR_019_deterministic-orchestrator-core.md | Bash-helper-driven deterministic orchestrator core | Proposed (this plan) |
| ADR-020 | Decision | ADR_020_sidecar-format-jsonl.md | Sidecar format — JSONL for `.run/control-flow.log` | Proposed (this plan; closes ADR-016 follow-on) |
| ADR-021 | Decision | ADR_021_smoke-tier-fixture-budget.md | Smoke-tier fixture selection and cost cap | Proposed (this plan; closes ADR-017 follow-on; revised post-plan-review) |
| ADR-022 | Decision | ADR_022_verdict-receipt-enforcement.md | Verdict-receipt enforcement between decide-next and emit-event | Proposed (post-plan-review revision; closes F-01 helper-bypass) |
| ADR-023 | Decision | ADR_023_pre-route-linter-postcheck.md | Pre-route linter postcheck on subagent artifacts | Proposed (post-plan-review revision; closes F-09 BLOCKING-rubber-stamping for code-action stages) |
| ADR-030 | Decision | ADR_030_pre-dispatch-head-baseline.md | Pre-dispatch HEAD as per-stage diff baseline for independent auditing | Accepted (post-audit addition) |
| LOG-004 | Question | LOG_004_per-stage-context-overhead-breakdown.md | Granular per-stage context overhead breakdown | Open (deferred to V2) |
| LOG-005 | Challenge | LOG_005_stage-pair-runner-fallback.md | Stage-pair runner as V1.5 fallback | Open |
| LOG-006 | Question | LOG_006_tdd-strategy-non-deterministic-dispatcher.md | TDD strategy for non-deterministic LLM dispatcher | Resolved → ADR-017 |
| LOG-007 | Question | LOG_007_codereview-model-class-diversity.md | Codereview model-class diversity | Open (V1 dogfooding measurement) |
| LOG-008 | Challenge | LOG_008_decision-log-unbounded-growth.md | Decision log unbounded growth across runs | Open (deferred to V2) |
| LOG-009 | Question | LOG_009_stale-lock-recovery-policy.md | Stale-lock recovery policy | Resolved → ADR-018 |
| LOG-010 | Challenge | LOG_010_non-code-stage-artifact-validation.md | Non-code-stage claimed-vs-actual artifact validation deferred | Deferred (V2 follow-on for ADR-023) |
| LOG-011 | Challenge | LOG_011_blocking-gate-rubber-stamping.md | BLOCKING-gate rubber-stamping risk | Open (V1 mitigation: ADR-023; SC-008 measurement) |
| LOG-012 | Challenge | LOG_012_jsonl-truncation-vs-coalesced-summaries.md | JSONL truncation tolerance vs MUST-coalesce on halt/abort | Open (V1 mitigation: stage-then-rename) |
| LOG-013 | Challenge | LOG_013_rubber-stamp-dogfooding-risk.md | "✓ all checks passed" prompt may worsen rubber-stamping vs honest signal | Open (V1 mitigations only — neutral phrasing + SPECKIT_POSTCHECK_BANNER=off escape hatch; measurement deferred to V2 per Re-Review #2 SR-1) |
| LOG-014 | Challenge | LOG_014_pr2b-loc-estimation-pattern.md | PR2b LOC estimation pattern — three upward revisions signal method, not luck | Open (V1 mitigation: 600-LOC re-justification gate; constitutional-exception lifecycle question deferred) |

## Technical Context

**Language/Version**: Bash 3.2+ (macOS default), POSIX where possible (`set -euo pipefail`); orchestrator surface lives in Markdown (`.claude/commands/speckit.run.md`)
**Primary Dependencies**: Claude Code (Task tool for subagent dispatch); `jq` (already a soft-dep in `setup-plan.sh` with a printf fallback) for JSONL emission and validation
**Storage**: Filesystem only. Canonical: `specs/[###]/decisions-log.md` (markdown). Runtime: `specs/[###]/.run/run-lock`, `specs/[###]/.run/abort`, `specs/[###]/.run/control-flow.log` (JSONL — ADR-020). All under the existing `.run/` gitignore from ADR-012.
**Testing**: bats-core for both tiers. Tier 1 (unit, pre-commit) — runs against canned `decisions-log.md` fixtures and filesystem state, asserts helper output. Tier 2 (smoke, pre-merge) — exercises `/speckit.run` against one synthetic fixture (ADR-021), real subagent dispatches, token-cost cap.
**Target Platform**: Developer macOS / Linux (single-machine, single-session V1 — ADR-015). No remote execution; no CI runs of Tier 2.
**Project Type**: Slash-command orchestrator + bash helpers (single project; no app/server)
**Performance Goals**: Per-stage orchestrator overhead (lock acquisition + completeness check + route decision + sidecar emission) < 1s wall time, dominated by `bash` startup. Subagent latency is unbounded by design (per-stage cold start is the cost of decision independence — ADR-009).
**Constraints**: Lock file write/remove must be atomic with the abort-sentinel cleanup (FR-027). All subagent dispatches must respect the FR-020 sandbox allowlist; the sandbox check is enforced by the subagent system prompt and verified by `run-check-sandbox.sh` after every code-action dispatch. Code-action dispatches additionally invoke `run-postcheck.sh` (ADR-023) before routing — `check-sandbox` audits "what was touched"; `postcheck` audits "do claimed artifacts match reality." Both are independent gates. Route events are gated by the verdict-receipt protocol (ADR-022): `run-decide-next.sh` writes `.run/last-verdict`; `run-emit-event.sh` refuses mismatched route emissions.
**Scale/Scope**: One run per feature directory; concurrent invocations forbidden (FR-028). Feature directories typically contain ≤10 stage records per run; `decisions-log.md` size dominated by subagent narrative content, not structural overhead.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Three passes completed:
- [X] **Pass 1 — Assumptions**: Every spec-level assumption was already challenged across two `/speckit.review` rounds (Phase A→B→C twice; FR-021..028 promoted from misclassified Edge Cases). Plan-level assumptions: (a) bash helpers can express the deterministic surface — verified by enumerating each FR against a candidate helper; (b) Markdown-with-key-value entries plus a JSONL sidecar avoid concurrent-write protocols — verified against ADR-016; (c) one fixture is enough for V1 smoke coverage — accepted with SC-008's 30-day evaluation as the kill switch.
- [X] **Pass 2 — Research**: Sources verified — Bash atomic-rename idiom is portable (`mv -f` is atomic on the same filesystem on macOS/Linux); `jq` install is a soft dep with documented printf fallback; bats-core is a known dependency-free test runner. No contradictions found.
- [X] **Pass 3 — Plan scrutiny**: Riskiest decision is **ADR-019 (deterministic orchestrator core)** — if the LLM-driven slash command bypasses helpers in practice, Tier 1 tests are theatre. Mitigation: the slash-command markdown explicitly invokes helpers as the only legal routing path, and Tier 2 smoke runs assert that `decisions-log.md` records match what helpers would have decided (i.e., post-hoc detect bypass).

- [X] Principle I: Spec approved through two review rounds; all clarifications resolved; FR-021..028 added in revision; Open Questions for Plan Phase resolved by ADR-017/018/019/020/021.
- [X] Principle II: No speculative abstractions. The 7 helper scripts each map 1:1 to an FR or ADR-mandated primitive (no "framework" layer). The slash-command markdown is the orchestrator — there is no separate process.
- [X] Principle III: TDD honored via ADR-017 hybrid; the deterministic surface is genuinely TDD-tested (Tier 1), the LLM call boundary is bounded by Tier 2 smoke. ADR-019 enlarges the Tier 1 surface.
- [X] Principle IV: User stories US-1, US-2, US-4 are independently deliverable; US-3 explicitly deferred to V2 (ADR-015). US-1 alone (single-trigger pipeline + BLOCKING checkpoints) is shippable without US-2 (decision-log review) — though US-2 ships free with FR-005/FR-006.
- [X] PR Policy: Feature scope estimate — 1 markdown command file (≤250 LOC, **hard cap as a file-length constraint, not a PR-budget constraint** — see PR3b-i), 9 bash helpers (~50–100 LOC each, ~600 LOC total — `run-lock.sh`, `run-completeness.sh`, `run-target.sh`, `run-decide-next.sh`, `run-emit-event.sh`, `run-validate-entry.sh`, `run-check-sandbox.sh`, `run-postcheck.sh`, `run-serialize.sh`, plus shared `run-common.sh`), bats unit tests (~900–1100 LOC including verdict-receipt + postcheck + serialize + invocation-order static-grep coverage — see Re-Review #2 PR2/PR3b re-derivation), smoke harness + 2 fixtures (~300 LOC), 1 precursor commit (~30 LOC, `check-prerequisites.sh --feature-dir`). Total ~2050 LOC.

**Splits into 7 PRs** (Re-Review #2 RC-3/RC-4 split applied):

0. **PR0 — Precursor: `check-prerequisites.sh --feature-dir` flag** (~30 LOC, ~50 LOC with tests): single commit extending `.specify/scripts/bash/check-prerequisites.sh` and `common.sh::find_feature_dir_by_prefix()` to accept `--feature-dir <path>` overriding the branch-name-derived default. **DoD**: (a) `check-prerequisites.sh --feature-dir <path> --json` exits 0 and emits FEATURE_DIR matching `<path>` regardless of `git branch`; (b) unknown-arg behavior preserved for non-`--feature-dir` flags; (c) Tier 1 bats coverage (`test_check_prereqs_feature_dir_flag.bats`, ~3 cases: flag honored on matching dir, flag honored on non-matching branch, missing-path errors with exit 1). Files touched: `.specify/scripts/bash/check-prerequisites.sh`, `.specify/scripts/bash/common.sh`, `tests/unit/test_check_prereqs_feature_dir_flag.bats`. **Required before PR3a** because `run-postcheck.sh`'s contract (helper-contracts.md L204) invokes `check-prerequisites.sh --feature-dir <feature-dir>` and would silently validate the wrong directory under `/speckit.run --resume --feature-dir=...` from a non-matching branch. No dependencies.

1. **PR1 — Foundation helpers + tests** (~280 LOC): `run-common.sh`, `run-lock.sh`, `run-target.sh`, `run-completeness.sh` plus their bats files. Independently mergeable: helpers are usable from outside `/speckit.run` (e.g., LOG-005 stage-pair-runner reuses them). Depends on nothing.

2. **PR2a — Schema validation helper + tests** (~150 LOC): `run-validate-entry.sh` (FR-006 schema enforcement) plus `test_validate_entry.bats` (~6–10 cases at 15–20 LOC each). Independently mergeable: schema validation is consumed by `run-emit-event.sh` and `run-decide-next.sh` but does not depend on either. Depends on PR1 (sources `run-common.sh`).

3. **PR2b — Verdict-receipt triplet + tests** (~500–600 LOC, **constitutional exception, supersedes prior 450 LOC estimate**): `run-decide-next.sh` (with verdict-receipt write + sentinel fold-in per ADR-019 amendment + pre-flight omission check + resume-scan filter per RC-5), `run-emit-event.sh` (with verdict-receipt validation + missing-receipt = mismatched-receipt semantics), `run-serialize.sh` (stage-then-rename + completeness invariant assertion) plus their bats files (~20–24 cases covering matched emission, mismatched emission, second-emission-without-fresh-verdict, stale cross-run receipt, pre-flight omission detection, sentinel-fold-in routing, halt-reason enumeration, completeness-invariant two branches, coalesce write success/empty/failure). **LOC re-derivation (Re-Review #3 M-2)**: ADR-022 amendments added Decision steps 5 (`verdict-omitted` refusal) and 6 (`pipeline-incomplete` two-branch invariant) after the original 450 LOC estimate; per-case LOC at 15–20 × 20–24 cases (300–480 LOC of bats) plus three helpers at ~50–100 LOC each (150–300 LOC) yields a realistic 500–600 LOC range. The prior 450 floor is superseded; if implementation lands above 600, re-justify the exception in PR description before merge rather than expanding silently. **Constitutional exception rationale**: the verdict-receipt protocol's correctness depends on the three helpers + their tests landing as a coherent unit — splitting helpers from tests violates TDD ordering (Principle III); splitting helpers from each other (e.g., `run-decide-next.sh` alone) leaves `run-emit-event.sh`'s receipt-validation contract unverifiable in isolation. Per Principle II's "complexity MUST be justified," this PR documents the constraint in its PR description and is reviewed as a single unit. Depends on PR2a (uses `run-validate-entry.sh`) and PR1 (sources `run-common.sh`). LOC-estimation pattern (3× upward revisions) tracked in LOG-014.

4. **PR3a — Code-action helpers + tests** (~190 LOC): `run-check-sandbox.sh`, `run-postcheck.sh` plus their bats files. Depends on PR2b (uses `run-decide-next.sh` invocation-order assumptions in tests) and PR0 (`check-prerequisites.sh --feature-dir`).

5. **PR3b-i — Slash-command markdown + LOC test** (~255 LOC, **markdown file hard cap**): `.claude/commands/speckit.run.md` (~250 LOC) + `tests/unit/test_command_loc.bats` (~5 LOC, asserts `speckit.run.md` ≤250 LOC; per Re-Review #3 M-1 the test is co-located with the artifact it constrains to satisfy Principle III TDD ordering — not by CI infrastructure, this project has no CI per Re-Review #2 SR-4). **Scope: this PR adds `speckit.run.md` and `test_command_loc.bats` only; no other files** (per Re-Review #3 M-7). Depends on PR3a.

6. **PR3b-ii — Integration tests + static-grep guard** (~195 LOC): integration bats covering the full per-stage invocation sequence (lock → completeness → dispatch → validate → postcheck → decide-next → emit), AND the Tier 1 static-grep test asserting `.claude/commands/speckit.run.md` invokes `run-decide-next.sh` and `run-emit-event.sh` for every routing point in the prescribed sequence (catches authoring drift before runtime per ADR-022 step 6 mitigation). The `test_command_loc.bats` LOC-cap enforcement landed in PR3b-i alongside the artifact (M-1). Depends on PR3b-i.

7. **PR4 — Smoke harness + 2 fixtures + cost-cap enforcement + CLAUDE.md update** (~300 LOC): `tests/smoke/fixture_min_path.bats`, `tests/smoke/fixture_halt_on_specify.bats`, fixture descriptions, smoke harness with token-cost reading and per-merge cap enforcement, plus the CLAUDE.md "Recent Changes" entry recording `/speckit.run` shipping. Depends on PR3b-ii.

**Intra-PR commit discipline**: each PR is composed of small commits (typically <100 LOC each) under the conventional-commits scheme (`feat:`, `test:`, `refactor:`); the PR description summarizes the cumulative diff against the constitutional 300-LOC limit. PR1's commits land helpers and tests in pairs (`feat: add run-lock.sh` followed by `test: add bats coverage for run-lock.sh acquire/release/break`) so reviewers can read each helper's contract against its tests in a single hunk. PR2b's commit discipline groups by helper-then-test (decide-next + its tests, then emit-event + its tests, then serialize + its tests) so reviewers can read each helper's contract against its tests despite the larger PR size; the constitutional-exception rationale is restated in the PR description.

**FR-traceability fold-ins** (post-`/speckit.analyze` consolidation): FR-021 (multi-blocker-collected halt aggregation) and FR-025 (below-threshold-continue routing) are covered by T014's halt-reason enumeration in PR2b — no separate test tasks because the helper-level coverage subsumes the FR-acceptance assertion (per Principle II: "three similar lines is better than premature abstraction" applied to tests). FR-024 (empty-output `stage-skip` with criterion field) is folded into T015's `run-emit-event.sh` test in PR2b. Standalone test tasks for these FRs were removed from PR3b-ii. FR-022 (clarification serialization) and FR-023 (`spec.md`-already-exists + `--force`) remain in PR3b-ii because they exercise cross-stage / slash-command surfaces beyond any single helper.

## Project Structure

### Documentation (this feature)

```text
specs/010-autonomous-workflow/
├── spec.md              # Feature specification (already exists)
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output — entity definitions
├── quickstart.md        # Phase 1 output — `/speckit.run` invocation guide
├── contracts/
│   ├── decision-log-entry.md      # FR-006 schema (canonical markdown record)
│   ├── sidecar-event.md           # ADR-020 JSONL event schema
│   └── helper-contracts.md        # Output contract for each run-*.sh helper
└── tasks.md             # Phase 2 output (NOT created here)
```

### Source Code (repository root)

This feature ships as configuration/script files, not application code. The "source tree" is:

```text
.claude/commands/
└── speckit.run.md                          # Orchestrator slash command (LLM behavior spec)

.specify/scripts/bash/
├── common.sh                                # (existing — unchanged; not sourced by run-* helpers)
├── run-common.sh                            # shared utilities for run-* helpers (atomic-rename, canonical-entry append, tmp sweep)
├── run-lock.sh                              # acquire | release | break — atomic w/ abort sentinel (FR-027, FR-028); wipes verdict + sweeps tmp on acquire
├── run-completeness.sh                      # FR-026 per-stage predicate
├── run-target.sh                            # FR-009 contiguous-subset validation + review-contiguity grammar (data-model E-6)
├── run-decide-next.sh                       # ADR-019 — read latest log entry, output route|halt|skip|abort; writes .run/last-verdict (ADR-022)
├── run-emit-event.sh                        # ADR-020 JSONL emission + ADR-022 verdict-receipt validation; refuses mismatched route events
├── run-validate-entry.sh                    # FR-006 — schema validation on a markdown entry section
├── run-check-sandbox.sh                     # FR-020 — post-run audit of subagent file actions (path allowlist)
├── run-postcheck.sh                         # ADR-023 — pre-route linter postcheck on code-action stages (composes existing project linters)
└── run-serialize.sh                         # ADR-016 MUST-coalesce — append coalesced summary to decisions-log.md via stage-then-rename (LOG-012)

tests/
├── unit/                                    # bats — Tier 1 (ADR-017)
│   ├── test_lock.bats                       # FR-027/FR-028 + ADR-018 break-lock
│   ├── test_completeness.bats               # FR-026 each stage
│   ├── test_target.bats                     # FR-009 contiguity
│   ├── test_decide_next.bats                # ADR-019 routing matrix
│   ├── test_emit_event.bats                 # ADR-020 JSONL emission
│   ├── test_validate_entry.bats             # FR-006 schema
│   ├── test_check_sandbox.bats              # FR-020 allowlist
│   ├── test_multi_blocker.bats              # FR-021 (covered through decide-next)
│   ├── test_clarification_serial.bats       # FR-022
│   ├── test_spec_already_exists.bats        # FR-023
│   ├── test_empty_stage_logging.bats        # FR-024
│   └── test_below_threshold_continue.bats   # FR-025
├── smoke/                                   # bats + real subagents — Tier 2
│   ├── fixture_min_path.bats                # ADR-021 Fixture 1 — green path, specify→plan
│   ├── fixture_halt_on_specify.bats         # ADR-021 Fixture 2 — halt path, verifies MUST-coalesce + verdict-receipt
│   └── fixtures/
│       ├── feature-min-path.txt             # synthetic feature description (green path)
│       └── feature-halt-on-specify.txt      # synthetic feature description (halt path; spec subagent emits halt_directive=true)
└── README.md                                # how to run tiers locally
```

**Structure Decision**: Existing repo layout is preserved. New artifacts land in three directories: `.claude/commands/` (the orchestrator), `.specify/scripts/bash/` (the deterministic core), and a new `tests/` root (the project's first test directory; previously absent). No `src/` is introduced because there is no application code — the orchestrator's behavior IS the slash-command markdown plus the helpers.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No principle violations. Complexity table empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
