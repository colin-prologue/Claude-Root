---
name: LOG-028 Sandbox-check coverage gaps
description: run-check-sandbox.sh missing unit tests for two edge paths (on-main branch diff; absent pre-dispatch-head file)
type: open-question
cross-references:
  - specs/010-autonomous-workflow/contracts/helper-contracts.md §run-check-sandbox.sh
  - .specify/scripts/bash/run-check-sandbox.sh
  - tests/unit/test_check_sandbox.bats
---

# LOG-028: Sandbox-check coverage gaps

**Date**: 2026-05-22
**Status**: Open — deferred to follow-up task

## Observation

`run-check-sandbox.sh` has no unit tests covering two paths:
1. **on-main-branch path**: when `git merge-base HEAD main` equals `HEAD` (no commits since branching), `git diff main...HEAD` produces no output. The script may return no violations (vacuous pass) rather than raising an error or warning.
2. **absent pre-dispatch-head file**: the orchestrator writes `$FEATURE_DIR/.run/pre-dispatch-head` before dispatch; `run-check-sandbox.sh` reads it to scope the diff. If the file is absent (e.g., a crash between step c and step f), the script's behavior is undefined by the current test suite.

Both paths are reachable in practice: the on-main path occurs on the very first commit of a feature branch; the absent-file path occurs on any orchestrator crash between pre-dispatch-head write and sandbox check.

## Recommended fix

Add 2 bats tests to `tests/unit/test_check_sandbox.bats`:
- `@test "on-main branch: git diff produces empty output → sandbox passes vacuously"` — assert exit 0 and no violation output
- `@test "absent pre-dispatch-head → sandbox exits with error"` — assert exit 2 or 1 and an error message on stderr

Clarify the expected behavior in `helper-contracts.md §run-check-sandbox.sh` if it is not currently specified.
