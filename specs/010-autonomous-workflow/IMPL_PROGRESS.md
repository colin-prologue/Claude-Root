# Implementation Progress — `/speckit.run` (Spec 010)

**Branch**: `010-autonomous-workflow`
**Last update**: 2026-05-17 (PR4 complete — smoke harness + CLAUDE.md, all tasks done)

This file is the cross-session handoff for `/speckit.implement` on spec 010. It exists
because the implementation is multi-PR and a `/clear` between segments otherwise
discards in-flight context. Source of truth is still `tasks.md` — this file is just
a fast on-ramp.

---

## ✅ PR2b redesigned and ready to push

**Status**: PR2b was redesigned after parallel code-simplifier + devils-advocate review
identified the verdict-receipt protocol (ADR-022) as the primary LOC driver (~70% of
the overrun). Six redesign commits landed on top of the original PR2b commits.

**What changed (LOG-026):**
- `run-decide-next.sh` deleted; `run-route.sh` added (atomic decide+emit, no receipt)
- `run-emit-event.sh` slimmed from 251 → 106 LOC (non-routing events only)
- `run-serialize.sh` slimmed from 264 → 109 LOC (pipeline-completeness invariant removed)
- `run-common.sh` trimmed to 124 LOC (`_hash_input` removed)
- Helper total: 783 → 511 LOC; tests: 137 → 118

**Branch is clean, 19+ commits ahead of main, 118/118 green. Ready to push.**

---

## ✅ Done (PR0–PR3a, 148/148 bats green)

| Commit | PR | Tasks | What landed |
|---|---|---|---|
| `29229d2` | Phase 1 | T001, T002 | `tests/unit/`, `tests/smoke/fixtures/`, `tests/README.md` |
| `300295d` | PR0     | T003, T004 | `check-prerequisites.sh --feature-dir <path>` override |
| `bda3c6c` | Phase 2 | T005      | `run-common.sh` shared utilities (`_run_lock_dir`, `_atomic_rename_into`, `_emit_canonical_entry`, `_sweep_tmp`, `_run_id_of_lock`, `_hash_input`, `_utc_now`) |
| `b941691` | PR1     | T006–T011 | `run-lock.sh` (12 cases), `run-target.sh` (20 cases), `run-completeness.sh` (17 cases) |
| `ae99ac9` | PR2a    | T012, T013 | `run-validate-entry.sh` + `test_validate_entry.bats` (22 cases). LOG-024 filed. |
| `9925889` / `cd6b494` / `1e1a5d6` / `76a3011` | PR2b redesign | T014r–T019r | `run-route.sh` (172 LOC, 23 cases); `run-emit-event.sh` slimmed 251→106 LOC; `run-serialize.sh` slimmed 264→109 LOC; `run-decide-next.sh` deleted; LOG-026 filed (ADR-022 receipt protocol eliminated). |
| `39ff1fc` / `1b49733` | PR3a | T020, T021 | `run-check-sandbox.sh` + `test_check_sandbox.bats` (15 cases). |
| `caf2c30` / `cc91ba3` | PR3a | T022, T023 | `run-postcheck.sh` + `test_postcheck.bats` (15 cases). |

**bats install**: `brew install bats-core` (v1.13.0+).
**Smoke check**: `bats /Users/colindwan/Developer/Claude-Root/tests/unit/` → 183/183 ok.
The `cd /tmp` guard from earlier handoffs is stale — each test mktemps its own
fixture, so bats works from any CWD.

---

## ✅ PR3a complete (T020–T023, 30 new cases, 148/148 green)

| Commit | Tasks | What landed |
|---|---|---|
| `39ff1fc` / `1b49733` | T020, T021 | `run-check-sandbox.sh` + `test_check_sandbox.bats` (15 cases) |
| `caf2c30` / `cc91ba3` | T022, T023 | `run-postcheck.sh` + `test_postcheck.bats` (15 cases) |

`run-check-sandbox.sh`: diffs `git diff <pre-dispatch-head>..HEAD` + uncommitted changes against
FR-020 allowlist (`.gitignore`, `.github/`, `.claude/settings*.json`, `.claude/hooks/`, `.env*`,
main/master branch mutation). Pre-dispatch HEAD stored in `.run/pre-dispatch-head`.

`run-postcheck.sh`: invokes `check-adr-crossrefs.sh` + `check-prerequisites.sh --feature-dir`;
for `implement` adds `--require-tasks`; for `implement` also cross-checks claimed test files
(.bats, test_*, *_test.*, paths under tests/) in latest subagent-record against `git ls-files`.
Clean exit emits exactly `postcheck: no findings` (LOG-013 normative).

## ✅ PR3b-i complete (T024–T025, 1 new case, 149/149 green)

| Commit | Tasks | What landed |
|---|---|---|
| `346133a` | T024 | `test_command_loc.bats` (1 case: speckit.run.md ≤ 250 lines) |
| `bdfc29d` | T025 | `.claude/commands/speckit.run.md` (173 LOC) |

`speckit.run.md`: Parses `--target` / `--checkpoints` / `--force` / `--break-lock`; full
per-stage loop (completeness → stage-start → pre-dispatch HEAD → code-gate BLOCKING →
Task dispatch → sandbox+postcheck → run-route.sh → advance); TERMINATE protocol
(run-serialize → run-lock release on every path); self-contained halt messages for all
FR-019 failure classes. `run-route.sh` handles routing atomically (ADR-022 rev.1).

## ✅ PR3b-ii complete (T026–T030, 10 new cases, 159/159 green)

| Commit | Tasks | What landed |
|---|---|---|
| `6536d87` | T026, T027, T029, T030 | 4 test files (10 cases) + speckit.run.md skip-path fix |

Bug found + fixed: speckit.run.md completeness-skip path was calling `run-route.sh`
on an empty log. run-route.sh reads decisions-log.md to derive verdict; a `stage-skip`
entry must be written FIRST. Fix added the `printf ...` write step before
`run-route.sh ... stage= criterion=` in the skip branch. T027 test 5 exposed this.

## ✅ Phase 4 complete (T033–T034, 9 new cases, 168/168 green)

| Commit | Tasks | What landed |
|---|---|---|
| (this session) | T033, T034 | `test_log_chronological_order.bats` (3 cases); `test_log_audit_completeness.bats` (6 cases) |

`test_log_chronological_order.bats`: verifies ISO-8601 timestamps across a multi-stage
fixture run are monotonically increasing; verifies `stage-end:run` (run-serialize.sh
coalesced summary) appears after all `subagent-record` headings per ADR-016 tail-append.

`test_log_audit_completeness.bats`: verifies FR-024 criterion appears in `stage-skip`
entries (Scenario 1 — autonomous skip); verifies all three audit-trail components
(originating review halt, specify revision, second review success) are present in a
route-back-to-specify fixture log (Scenario 2).

## ✅ Phase 5 complete (T035–T036, 15 new cases, 183/183 green)

| Commit | Tasks | What landed |
|---|---|---|
| (this session) | T035, T036 | `test_resume_skip_complete_artifacts.bats` (5 cases); `test_resume_scan_filter.bats` (10 cases) |

`test_resume_skip_complete_artifacts.bats`: verifies run-completeness.sh detects complete
spec.md + plan.md (FR-026) and incomplete tasks.md (next stage to dispatch); SC-003
artifact mtime unchanged by completeness read.

`test_resume_scan_filter.bats`: FR-023 canonical-exception filter (pipeline-incomplete
and verdict-mismatch skipped as resume anchors); Scenario 2 mid-stage interruption
(stage-start present, plan.md absent → incomplete); Scenario 3 all three FR-019
failure classes (temporal/semantic/permission) return halt verdict + failure_class in
log + static grep verifies speckit.run.md documents all three halt message paths.

## ✅ PR4 complete (T037–T042, smoke harness + CLAUDE.md)

| Commit | Tasks | What landed |
|---|---|---|
| (this session) | T037–T042 | 2 fixture text files; `fixture_min_path.bats` (11 cases); `fixture_halt_on_specify.bats` (9 cases); CLAUDE.md update |

`fixture_min_path.bats`: skips cleanly if `SMOKE_FEATURE_DIR` not set; when set asserts
spec.md + plan.md produced, canonical-log has subagent-record:specify/plan, specify
halt=false, stage-end:run at tail, sidecar has route event, JSONL is valid, per-run
token cap ≤50K (skips if token-cost.txt absent).

`fixture_halt_on_specify.bats`: skips if `SMOKE_HALT_FEATURE_DIR` not set; asserts
halt path (halt=true, no plan.md, coalesced summary mentions halt), per-run cap, and
combined per-merge cap (≤100K) reading both cost files.

`feature-min-path.txt`: ~250-word CLI feature (structured audit log writer) —
unambiguous, produces mandatory sections in spec.md + plan.md.
`feature-halt-on-specify.txt`: ~200-word feature (user preference sync) with
four deliberate ambiguities that the spec subagent must surface as [NEEDS CLARIFICATION].

CLAUDE.md: updated Recent Changes to record /speckit.run shipped; added tests/ subtree
to Directory Structure; added bats-core soft dependency note.

## ✅ IMPLEMENTATION COMPLETE — all 42 tasks done (T001–T042)

---

## ⏭ After PR3b-ii — remaining roadmap

| PR | Tasks | LOC | Notes |
|---|---|---|---|
| ~~PR3b-i~~ | ~~T024–T025~~ | ~~255~~ | ✅ done |
| ~~PR3b-ii~~ | ~~T026–T030~~ | ~~120~~ | ✅ done |
| Phase 4 | T033, T034 | small | US-2 audit-trail tests against canned fixtures |
| Phase 5 | T035, T036 | small | US-4 resume tests (covers all three FR-019 failure classes) |
| PR4 | T037–T042 | ~300 | smoke fixtures + harness, CLAUDE.md "Recent Changes" update |

---

## ⚠ Important context for the next segment

- **TDD ordering is NON-NEGOTIABLE** (Principle III): test commits land before
  helper commits and must be verified to fail first. Tests typically fail with
  exit 127 ("command not found") because the helper script is missing — that is
  the right kind of failure signal.
- **`tests/` fixture pattern**: each bats test creates a `mktemp -d` repo
  skeleton, copies the helpers under test into `.specify/scripts/bash/`, and
  points the helper at a `specs/<NNN>-<slug>/` feature dir under the temp root.
- **Bash 3.2 (macOS default)** — no `readarray`, no `${arr[-1]}`. Empty arrays
  under `set -u` need length-guarded iteration: `(( ${#arr[@]} > 0 )) && for x
  in "${arr[@]}"; do ...; done`. `${arr[@]:-}` produces a phantom empty element
  (caught us once in `run-serialize.sh`).
- **`set -uo pipefail` everywhere**, NOT `set -euo pipefail` — many helpers
  tolerate non-zero intermediate steps (e.g., `grep -q`, `rm -f`) and `-e`
  would force defensive `|| true` everywhere.
- **`_emit_canonical_entry` reads markdown on stdin** — convention from
  `run-common.sh`. The three orchestrator-authored canonical entries
  (`verdict-mismatch`, `verdict-omitted`, `pipeline-incomplete`) and the
  coalesced summary all use this path.
- **`run-postcheck.sh` postcheck-banner** (LOG-013): clean exit MUST emit
  exactly the line `postcheck: no findings`. No iconography. No "✓".
  Static-grep test in PR3b-ii will assert this.
- **Phase 4 + 5 (T033–T036)**: test-only tasks (bats against fixture logs). No new helpers.
  T033/T034 = audit-trail tests (chronological order + completeness).
  T035/T036 = resume tests (FR-019 failure classes).
- **PR4 (T037–T042)**: smoke fixtures + harness + CLAUDE.md update.
- **Trailing-newline detection** in bash: `$()` strips trailing newlines, so
  use the printf-sentinel idiom: `[[ "$(tail -c 1 file; printf x)" == $'\nx' ]]`.

---

## Resume protocol when continuing

1. Read this file first.
2. `git log --oneline -12` — confirm the last commit matches "Done" table tail.
3. `bats tests/unit/` — confirm 148/148 still green (or the new total once
   PR3b's tests land).
4. Resume from "⏭ Next" section. Do not skip TDD ordering even when picking up
   mid-PR.

---

## ⚠ Pre-dispatch HEAD protocol

`run-check-sandbox.sh` reads `.run/pre-dispatch-head` (a file written by the
orchestrator before each subagent dispatch). This file must be written by the
slash command markdown (`speckit.run.md`) immediately before each code-action
subagent dispatch. PR3b-i must include this step in the per-stage invocation
sequence.
