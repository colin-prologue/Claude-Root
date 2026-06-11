#!/usr/bin/env bats

# T024 — speckit.run.md: hard LOC cap (≤250 lines).
# Source of truth: plan.md §PR3b-i (hard cap as a file-length constraint, not a PR-budget constraint)

@test "speckit.run.md exists and is at most 250 lines" {
    repo_root="$(git -C "$BATS_TEST_DIRNAME" rev-parse --show-toplevel)"
    cmd_file="$repo_root/.claude/commands/speckit.run.md"
    [ -f "$cmd_file" ]
    loc=$(wc -l < "$cmd_file")
    [ "$loc" -le 250 ]
}
