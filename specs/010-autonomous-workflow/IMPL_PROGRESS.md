# Implementation Progress — `/speckit.run` (Spec 010)

**Branch**: `010-autonomous-workflow`
**Last update**: 2026-05-07 (PR2b complete locally — paused mid-decision on pre-push review)

This file is the cross-session handoff for `/speckit.implement` on spec 010. It exists
because the implementation is multi-PR and a `/clear` between segments otherwise
discards in-flight context. Source of truth is still `tasks.md` — this file is just
a fast on-ramp.

---

## 🟡 In-flight: pre-push review of PR2b

**Status**: PR2b's six commits are landed locally. Branch is twelve commits ahead of `main`,
clean tree, unpushed. A docs commit (`df1790a`) updates this file and `LOG_014` with the
landing tally.

**The open question:** the diff is 1,585 lines (helpers + tests + docs). The plan said
500–600 with a re-justification gate at 600. Helpers alone are 691 — about 15% over.
The user asked whether a fresh-perspective review could find a shorter path before we
open the PR.

**A draft PR description with a re-justification paragraph already exists.** It's not
written to a file yet — it's in the conversation history. If you `/clear` before pushing,
re-derive it from this state plus the commit messages of `77faf8d` through `bdc128e`
(the pattern is: what landed, why the size is justified, test plan, related ADRs/LOGs).

**Four paths under consideration:**

1. **Cold re-read by Claude first (recommended).** I re-read the three helper scripts
   side-by-side, looking for duplicated argument-parsing, defensive code that doesn't
   earn its place, and whether the 264-line termination check could be cut. Output is
   a list of safe cuts with line counts. Cheapest move; biased because I wrote the code,
   so unlikely to challenge the design itself.

2. **Two specialist sub-reviewers in parallel.** Dispatch a code-simplifier subagent
   (hunts duplication and dead defenses) and a devils-advocate subagent (challenges
   whether the protocol itself is necessary). Fresh perspective; ~5min per agent.
   Risks rubber-stamp if briefing prompts aren't adversarial enough — the mitigation
   is to give them the LOC tally and ask explicitly "what would you cut and why."

3. **Full `/speckit.codereview` panel.** Heavier — covers correctness, test quality,
   ADR compliance, and maintainability. Useful if we want bug-scrutiny too, but the
   user's question was about size, not correctness, so this is overkill for the ask.

4. **Skip review and push.** Open the PR with the re-justification paragraph and let
   the GitHub review process handle scope challenges. Fastest path to a reviewable
   diff; loses the "shorter path?" question.

**Recommended sequence:** Path 1 first as a pre-filter. If it surfaces 200+ lines of
safe cuts, push the smaller PR and skip the rest. If it surfaces nothing, escalate to
Path 2 (the design-level challenge is the actual question at that point). Skip Path 3
unless we explicitly want correctness scrutiny.

**Resume protocol for this decision specifically:**
1. Read this section.
2. `git log --oneline -13` — confirm `df1790a` (docs commit) is at HEAD; the six PR2b
   commits are immediately below it.
3. `bats tests/unit/` — confirm 137 cases still pass.
4. Ask the user which of the four paths to take. Default to Path 1 if no answer needed.

---

## ✅ Done (11 commits, 137/137 bats green)

| Commit | PR | Tasks | What landed |
|---|---|---|---|
| `29229d2` | Phase 1 | T001, T002 | `tests/unit/`, `tests/smoke/fixtures/`, `tests/README.md` |
| `300295d` | PR0     | T003, T004 | `check-prerequisites.sh --feature-dir <path>` override |
| `bda3c6c` | Phase 2 | T005      | `run-common.sh` shared utilities (`_run_lock_dir`, `_atomic_rename_into`, `_emit_canonical_entry`, `_sweep_tmp`, `_run_id_of_lock`, `_hash_input`, `_utc_now`) |
| `b941691` | PR1     | T006–T011 | `run-lock.sh` (12 cases), `run-target.sh` (20 cases), `run-completeness.sh` (17 cases) |
| `ae99ac9` | PR2a    | T012, T013 | `run-validate-entry.sh` + `test_validate_entry.bats` (22 cases). LOG-024 filed. |
| `77faf8d` / `139c845` | PR2b·1 | T014, T017 | `run-decide-next.sh` (134 LOC) + `test_decide_next.bats` (21 cases) |
| `e8e953f` / `b3706e9` | PR2b·2 | T015, T018 | `run-emit-event.sh` (251 LOC) + `test_emit_event.bats` (21 cases). Shared `_latest_routable_anchor` extracted into `run-common.sh`. LOG-025 filed (halt-* sidecar events deferred to V2). |
| `8449f72` / `bdc128e` | PR2b·3 | T016, T019 | `run-serialize.sh` (264 LOC) + `test_serialize.bats` (20 cases) |

**bats install**: `brew install bats-core` (v1.13.0+).
**Smoke check**: `bats /Users/colindwan/Developer/Claude-Root/tests/unit/` → 137/137 ok.
The `cd /tmp` guard from earlier handoffs is stale — each test mktemps its own
fixture, so bats works from any CWD.

---

## ⏭ Next — PR3a (T020–T023) ~190 LOC

Code-action helpers: `run-check-sandbox.sh` + `run-postcheck.sh`. Depends on PR0 (the
`check-prerequisites.sh --feature-dir` flag). Both run on every code-action stage
(`implement`, `codereview`, `audit`):

- `run-check-sandbox.sh` audits `git diff` against the FR-020 allowlist (no `main`
  mutations, no `.gitignore` / `.github/` / `.claude/settings*.json` / `.env*`).
  Exit 1 ⇒ permission failure halt.
- `run-postcheck.sh` runs the existing linters (`check-adr-crossrefs.sh`,
  `check-prerequisites.sh --feature-dir`) + claimed-test-files cross-check for
  `implement`. Clean exit MUST emit the literal line `postcheck: no findings`
  (no iconography — LOG-013 normative MUST). Exit 1 produces `halt:postcheck-failed`.

Per-helper TDD ordering inside the PR (test commit, then helper commit, ×2).

After PR3a: PR3b-i (slash command + 250-LOC cap) → PR3b-ii (static-grep guard +
integration tests) → Phase 4/5/6.

---

## ⏭ After PR3a — remaining roadmap

| PR | Tasks | LOC | Notes |
|---|---|---|---|
| PR3b-i | T024–T025 | ~255 | `.claude/commands/speckit.run.md` (≤250 LOC hard cap) + `test_command_loc.bats` |
| PR3b-ii | T026, T027, T029, T030 | ~120 | static-grep guard + integration tests (FR-022, FR-023) |
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
- **Plan.md PR3b-i scope** (M-7): that PR adds `speckit.run.md` and
  `test_command_loc.bats` ONLY.
- **Trailing-newline detection** in bash: `$()` strips trailing newlines, so
  use the printf-sentinel idiom: `[[ "$(tail -c 1 file; printf x)" == $'\nx' ]]`.

---

## Resume protocol when continuing

1. Read this file first.
2. `git log --oneline -12` — confirm the last commit matches "Done" table tail.
3. `bats tests/unit/` — confirm 137/137 still green (or the new total once
   PR3a's tests land).
4. Resume from "⏭ Next" section. Do not skip TDD ordering even when picking up
   mid-PR.
