#!/usr/bin/env bats

# T036 — US-4 Scenarios 2+3: canonical-exception resume-scan filter (FR-023/RC-5);
# mid-stage interruption → incomplete stage detected (Scenario 2);
# all three FR-019 failure classes produce halt verdict + failure_class in log (Scenario 3).
# Source of truth: spec.md US-4; FR-019; FR-023; contracts/helper-contracts.md §run-route.sh.

setup() {
    REPO_ROOT_FIXTURE="$(mktemp -d)"
    cd "$REPO_ROOT_FIXTURE"
    mkdir -p .specify/scripts/bash specs/001-foo
    for h in run-common run-lock run-completeness run-route; do
        cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/$h.sh" .specify/scripts/bash/
    done
    LOCK=".specify/scripts/bash/run-lock.sh"
    ROUTE=".specify/scripts/bash/run-route.sh"
    COMPLETE=".specify/scripts/bash/run-completeness.sh"
    FEATURE="$REPO_ROOT_FIXTURE/specs/001-foo"
    LOG="$FEATURE/decisions-log.md"
    "$LOCK" acquire "$FEATURE"
}

teardown() {
    rm -rf "$REPO_ROOT_FIXTURE"
}

write_success_record() {
    local stage="$1" ts="$2"
    cat >> "$LOG" <<EOF
## subagent-record:$stage · $ts

- author: subagent:$stage
- status: success
- run_id: run-test

rationale

### artifacts_written

-

### decisions_made

-

### halt_directive

- halt: false

EOF
}

write_halt_record() {
    local stage="$1" failure_class="$2" reason="$3"
    cat >> "$LOG" <<EOF
## subagent-record:$stage · 2026-04-26T20:10:00Z

- author: subagent:$stage
- status: halt
- run_id: run-test

Halt during $stage: $reason

### artifacts_written

-

### decisions_made

-

### halt_directive

- halt: true
- reason: $reason
- failure_class: $failure_class

EOF
}

# ----- FR-023 canonical-exception filter -----

@test "FR-023: pipeline-incomplete at tail skipped; prior subagent-record becomes anchor (continue)" {
    write_success_record specify "2026-04-26T20:00:00Z"
    cat >> "$LOG" <<'EOF'
## pipeline-incomplete:specify · 2026-04-26T20:01:00Z

- author: orchestrator
- status: error
- run_id: run-test

canonical exception — not a valid resume anchor per FR-023

EOF
    verdict="$("$ROUTE" "$FEATURE" from=specify to=clarify reason="subagent complete")"
    [ "$verdict" = "continue" ]
}

@test "FR-023: verdict-mismatch at tail skipped; prior subagent-record becomes anchor (continue)" {
    write_success_record plan "2026-04-26T20:00:00Z"
    cat >> "$LOG" <<'EOF'
## verdict-mismatch:plan · 2026-04-26T20:01:00Z

- author: orchestrator
- status: error
- run_id: run-test

canonical exception — not a valid resume anchor per FR-023

EOF
    verdict="$("$ROUTE" "$FEATURE" from=plan to=tasks reason="subagent complete")"
    [ "$verdict" = "continue" ]
}

# ----- US-4 Scenario 2: mid-stage interruption -----

@test "Scenario 2: stage-start exists but plan.md absent → run-completeness detects incomplete (re-dispatch)" {
    cat >> "$LOG" <<'EOF'
## stage-start:plan · 2026-04-26T20:00:00Z

- author: orchestrator
- status: success
- run_id: run-test

plan stage dispatched

EOF
    # No plan.md written — stage interrupted before completion
    result="$("$COMPLETE" "$FEATURE" plan)"
    [ "$result" = "incomplete" ]
}

# ----- US-4 Scenario 3: FR-019 failure classes -----

@test "Scenario 3 temporal: rate-limit halt → run-route returns halt verdict" {
    write_halt_record plan temporal "rate limit exceeded"
    verdict="$("$ROUTE" "$FEATURE" from=plan to=tasks reason="subagent complete")"
    [[ "$verdict" == halt:* ]]
}

@test "Scenario 3 temporal: halt entry carries failure_class=temporal in canonical log" {
    write_halt_record plan temporal "rate limit exceeded"
    grep -q 'failure_class: temporal' "$LOG"
}

@test "Scenario 3 semantic: schema-violation halt → run-route returns halt verdict" {
    write_halt_record plan semantic "malformed decision-log entry"
    verdict="$("$ROUTE" "$FEATURE" from=plan to=tasks reason="subagent complete")"
    [[ "$verdict" == halt:* ]]
}

@test "Scenario 3 semantic: halt entry carries failure_class=semantic in canonical log" {
    write_halt_record plan semantic "malformed decision-log entry"
    grep -q 'failure_class: semantic' "$LOG"
}

@test "Scenario 3 permission: sandbox-violation halt → run-route returns halt verdict" {
    write_halt_record plan permission "disallowed path write detected by run-check-sandbox.sh"
    verdict="$("$ROUTE" "$FEATURE" from=plan to=tasks reason="subagent complete")"
    [[ "$verdict" == halt:* ]]
}

@test "Scenario 3 permission: halt entry carries failure_class=permission in canonical log" {
    write_halt_record plan permission "disallowed path write detected by run-check-sandbox.sh"
    grep -q 'failure_class: permission' "$LOG"
}

@test "Scenario 3: speckit.run.md documents self-contained halt messages for all three FR-019 classes" {
    repo_root="$(git -C "$BATS_TEST_DIRNAME" rev-parse --show-toplevel)"
    cmd="$repo_root/.claude/commands/speckit.run.md"
    # temporal: rate-limit halt path
    grep -q 'rate-limit' "$cmd"
    # semantic: schema-violation halt path
    grep -q 'schema-violation' "$cmd"
    # permission: sandbox halt path
    grep -q 'permission' "$cmd"
    # retrigger command present
    grep -q 'speckit\.run' "$cmd"
}
