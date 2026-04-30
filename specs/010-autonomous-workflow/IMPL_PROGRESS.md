# Implementation Progress — `/speckit.run` (Spec 010)

**Branch**: `010-autonomous-workflow`
**Last update**: 2026-04-30 (mid-implementation — PR2a complete, PR2b next)

This file is the cross-session handoff for `/speckit.implement` on spec 010. It exists
because the implementation is multi-PR and a `/clear` between segments otherwise
discards in-flight context. Source of truth is still `tasks.md` — this file is just
a fast on-ramp.

---

## ✅ Done (5 commits, 75/75 bats green)

| Commit | PR | Tasks | What landed |
|---|---|---|---|
| `29229d2` | Phase 1 | T001, T002 | `tests/unit/`, `tests/smoke/fixtures/`, `tests/README.md` (Tier 1 vs Tier 2 conventions) |
| `300295d` | PR0     | T003, T004 | `check-prerequisites.sh --feature-dir <path>` override (precursor for `run-postcheck.sh`) — 4 bats cases |
| `bda3c6c` | Phase 2 | T005      | `.specify/scripts/bash/run-common.sh` shared utilities (`_run_lock_dir`, `_atomic_rename_into`, `_emit_canonical_entry`, `_sweep_tmp`, `_run_id_of_lock`, `_hash_input`, `_utc_now`) |
| `b941691` | PR1     | T006–T011 | `run-lock.sh` (12 cases), `run-target.sh` (20 cases), `run-completeness.sh` (17 cases) |
| _next_   | PR2a    | T012, T013 | `run-validate-entry.sh` (153 LOC) + `test_validate_entry.bats` (22 cases). LOG-024 filed: `run_id` format check is presence-only; contract loose, deferred. |

**bats install**: `brew install bats-core` (already installed locally, v1.13.0).
**Smoke check**: `cd /tmp && bats /Users/colindwan/Developer/Claude-Root/tests/unit/` → 75/75 ok.

---

## ⏭ Next — PR2b (T014–T019) ~500–600 LOC, **CONSTITUTIONAL EXCEPTION**

Verdict-receipt triplet: `run-decide-next.sh` + `run-emit-event.sh` + `run-serialize.sh`. Per
plan.md PR2b and ADR-022, these three helpers + their tests ship as a coherent unit because the
verdict-receipt protocol's correctness is unverifiable in helper isolation. **PR description must
restate the exception**; if implementation lands above 600 LOC, **re-justify in PR description**
(plan.md M-2; LOG-014).

- **T014** `test_decide_next.bats` — covers ADR-019 routing matrix + ADR-022 receipt mint +
  sentinel fold-in; pre-flight omission check; resume-scan filter (skip `verdict-mismatch` /
  `verdict-omitted` / `pipeline-incomplete`); halt-reason enumeration; receipt format
  `<verdict>\t<run_id>\t<input_hash>\t<ts>`. **Folds in FR-021 + FR-025**.
- **T015** `test_emit_event.bats` — covers ADR-020 JSONL emission + ADR-022 receipt validation;
  matched route consumes receipt; mismatched/missing refuses + writes `verdict-mismatch`; second
  emission without fresh verdict identical refuse; cross-run `run_id` mismatch; `stage-start` /
  `break-lock` / `budget-exhausted` emit without receipt; **`stage-skip` MUST carry non-empty
  `criterion`** (FR-024). Truncation tolerance.
- **T016** `test_serialize.bats` — covers ADR-016 MUST-coalesce + ADR-022 step-6 completeness
  invariant: stage-then-rename success + cold-start; empty sidecar tolerated; sidecar unparseable
  → exit 1; invariant violation writes `pipeline-incomplete` then appends summary.
- **T017** implement `run-decide-next.sh` — pre-flight omission check, sentinel check, routing
  logic (continue / halt:* / skip:* / abort), resume-scan filter, side-effect: write
  `.run/last-verdict`.
- **T018** implement `run-emit-event.sh` — JSON line via `jq -cn` (printf fallback if no jq, per
  `setup-plan.sh` precedent), receipt validate for routing-decision events.
- **T019** implement `run-serialize.sh` — completeness invariant (a: receipt empty, b: sidecar
  has routing event for every per-stage record), stage-then-rename append.

**Per-helper commit ordering inside the PR is preserved** (test commit, then helper commit, ×3).

After PR2b: pause, eyeball commits, then continue PR3a → PR3b-i → PR3b-ii → Phase 4/5/6.

---

## ⏭ After PR2b — remaining roadmap

| PR | Tasks | LOC | Notes |
|---|---|---|---|
| PR3a | T020–T023 | ~190 | `run-check-sandbox.sh` + `run-postcheck.sh` (depends on PR0) |
| PR3b-i | T024–T025 | ~255 | `.claude/commands/speckit.run.md` (≤250 LOC hard cap) + `test_command_loc.bats` |
| PR3b-ii | T026, T027, T029, T030 | ~120 | static-grep guard + integration tests + FR-022 + FR-023 |
| Phase 4 | T033, T034 | small | US-2 audit-trail tests against canned fixtures |
| Phase 5 | T035, T036 | small | US-4 resume tests (covers all three FR-019 failure classes) |
| PR4 | T037–T042 | ~300 | smoke fixtures + harness, CLAUDE.md "Recent Changes" update |

---

## ⚠ Important context for the next segment

- **TDD ordering is NON-NEGOTIABLE** (Principle III): every test commit must land before its
  corresponding helper commit and verified to fail first. Tests typically fail with exit 127
  ("command not found") because the helper script is missing — this is the right kind of failure
  signal.
- **`tests/` fixture pattern**: each bats test creates a `mktemp -d` repo skeleton, copies the
  helpers under test into `.specify/scripts/bash/`, and points the helper at a `specs/<NNN>-<slug>/`
  feature dir under the temp root. Don't run bats from the project root — it'll pull the actual
  helpers. `cd /tmp && bats <test-file>` is the safe invocation pattern (already in use).
- **Bash 3.2 (macOS default)** — no `readarray`, no `${arr[-1]}`. `run-target.sh` already uses
  the manual loop pattern; keep that style for the rest of the helpers.
- **`set -uo pipefail` everywhere**, NOT `set -euo pipefail` — many helpers tolerate non-zero
  intermediate steps (e.g., grep -q, rm -f) and `-e` would force defensive `|| true` everywhere.
- **`_emit_canonical_entry` reads markdown on stdin** — this is the convention I picked in
  `run-common.sh`; PR2b's helpers should pipe their entry markdown into it.
- **`run-postcheck.sh` postcheck-banner** (LOG-013): clean exit MUST emit exactly the line
  `postcheck: no findings`. No iconography. No "✓". Static-grep test in PR3b-ii will assert this.
- **Plan.md PR3b-i scope** (M-7): that PR adds `speckit.run.md` and `test_command_loc.bats` ONLY.

---

## Resume protocol when continuing

1. Read this file first.
2. `git log --oneline -10` — confirm the last commit matches "Done" table tail.
3. `cd /tmp && bats /Users/colindwan/Developer/Claude-Root/tests/unit/` — confirm 53/53 still green
   before touching anything (or whatever count matches the next milestone).
4. Resume from "⏭ Next" section. Do not skip TDD ordering even when picking up mid-PR.
