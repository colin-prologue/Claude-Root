#!/usr/bin/env bats

# T026 — static-grep guard: speckit.run.md invokes run-route.sh at every routing point.
# ADR-022 rev.1 mitigation: verdict-receipt protocol eliminated in LOG-026; run-route.sh
# is the sole routing helper. This test catches authoring drift before runtime.
# Source of truth: contracts/helper-contracts.md §run-route.sh (ADR-022 rev.1)

@test "speckit.run.md invokes run-route.sh at the completeness-skip routing point" {
    repo_root="$(git -C "$BATS_TEST_DIRNAME" rev-parse --show-toplevel)"
    grep -q 'run-route\.sh.*stage=.*criterion=' "$repo_root/.claude/commands/speckit.run.md"
}

@test "speckit.run.md invokes run-route.sh at the subagent-complete routing point" {
    repo_root="$(git -C "$BATS_TEST_DIRNAME" rev-parse --show-toplevel)"
    grep -q 'run-route\.sh.*from=.*to=.*reason=' "$repo_root/.claude/commands/speckit.run.md"
}

@test "speckit.run.md does not invoke run-decide-next.sh (eliminated in LOG-026)" {
    repo_root="$(git -C "$BATS_TEST_DIRNAME" rev-parse --show-toplevel)"
    ! grep -q 'run-decide-next\.sh' "$repo_root/.claude/commands/speckit.run.md"
}
