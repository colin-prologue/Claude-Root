#!/usr/bin/env bats

# T012 — run-validate-entry.sh: schema validation per FR-006.
# Source of truth: contracts/decision-log-entry.md §Validation contract.

setup() {
    REPO_ROOT_FIXTURE="$(mktemp -d)"
    cd "$REPO_ROOT_FIXTURE"
    mkdir -p .specify/scripts/bash specs/001-foo
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-common.sh"          .specify/scripts/bash/
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-validate-entry.sh"  .specify/scripts/bash/ 2>/dev/null || true
    VALIDATE=".specify/scripts/bash/run-validate-entry.sh"
    FEATURE="$REPO_ROOT_FIXTURE/specs/001-foo"
    LOG="$FEATURE/decisions-log.md"
}

teardown() {
    rm -rf "$REPO_ROOT_FIXTURE"
}

# Write a single entry to $LOG and echo the byte-offset of its start (always 0 here).
write_entry() {
    printf '%s' "$1" > "$LOG"
    echo 0
}

# ----- valid entries -----

@test "valid orchestrator stage-end entry passes" {
    off=$(write_entry "## stage-end:plan · 2026-04-26T20:14:12Z

- author: orchestrator
- status: success
- run_id: run-2026-04-26T20:00:00Z-a1b2c3

ok
")
    run "$VALIDATE" "$LOG" "$off"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "valid subagent-record with halt=false passes" {
    off=$(write_entry "## subagent-record:plan · 2026-04-26T20:14:12Z

- author: subagent:plan
- status: success
- run_id: run-x

rationale text

### artifacts_written

- specs/001-foo/plan.md

### decisions_made

-

### halt_directive

- halt: false
")
    run "$VALIDATE" "$LOG" "$off"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "valid subagent-record with halt=true and required reason+failure_class passes" {
    off=$(write_entry "## subagent-record:implement · 2026-04-26T20:14:12Z

- author: subagent:implement
- status: halt
- run_id: run-x

text

### artifacts_written

-

### decisions_made

-

### halt_directive

- halt: true
- reason: tests failing in target module
- failure_class: semantic
")
    run "$VALIDATE" "$LOG" "$off"
    [ "$status" -eq 0 ]
}

# ----- heading violations -----

@test "heading without '## ' prefix fails with diagnostic" {
    off=$(write_entry "# stage-end:plan · 2026-04-26T20:14:12Z

- author: orchestrator
- status: success
- run_id: run-x
")
    run "$VALIDATE" "$LOG" "$off"
    [ "$status" -eq 1 ]
    [[ "$output" == *"field: heading"* ]]
}

@test "heading with unknown entry_type fails" {
    off=$(write_entry "## frobnicate:plan · 2026-04-26T20:14:12Z

- author: orchestrator
- status: success
- run_id: run-x
")
    run "$VALIDATE" "$LOG" "$off"
    [ "$status" -eq 1 ]
    [[ "$output" == *"field: heading"* ]]
}

@test "heading with non-canonical stage fails" {
    off=$(write_entry "## stage-end:frobnicate · 2026-04-26T20:14:12Z

- author: orchestrator
- status: success
- run_id: run-x
")
    run "$VALIDATE" "$LOG" "$off"
    [ "$status" -eq 1 ]
    [[ "$output" == *"field: heading"* ]]
}

@test "heading with missing timestamp fails" {
    off=$(write_entry "## stage-end:plan

- author: orchestrator
- status: success
- run_id: run-x
")
    run "$VALIDATE" "$LOG" "$off"
    [ "$status" -eq 1 ]
    [[ "$output" == *"field: heading"* ]]
}

# ----- required fields -----

@test "missing author fails" {
    off=$(write_entry "## stage-end:plan · 2026-04-26T20:14:12Z

- status: success
- run_id: run-x
")
    run "$VALIDATE" "$LOG" "$off"
    [ "$status" -eq 1 ]
    [[ "$output" == *"field: author"* ]]
}

@test "missing status fails" {
    off=$(write_entry "## stage-end:plan · 2026-04-26T20:14:12Z

- author: orchestrator
- run_id: run-x
")
    run "$VALIDATE" "$LOG" "$off"
    [ "$status" -eq 1 ]
    [[ "$output" == *"field: status"* ]]
}

@test "missing run_id fails" {
    off=$(write_entry "## stage-end:plan · 2026-04-26T20:14:12Z

- author: orchestrator
- status: success
")
    run "$VALIDATE" "$LOG" "$off"
    [ "$status" -eq 1 ]
    [[ "$output" == *"field: run_id"* ]]
}

# ----- enum / regex violations -----

@test "status outside enum fails" {
    off=$(write_entry "## stage-end:plan · 2026-04-26T20:14:12Z

- author: orchestrator
- status: maybe
- run_id: run-x
")
    run "$VALIDATE" "$LOG" "$off"
    [ "$status" -eq 1 ]
    [[ "$output" == *"field: status"* ]]
}

@test "author with bad subagent stage fails" {
    off=$(write_entry "## stage-end:plan · 2026-04-26T20:14:12Z

- author: subagent:frobnicate
- status: success
- run_id: run-x
")
    run "$VALIDATE" "$LOG" "$off"
    [ "$status" -eq 1 ]
    [[ "$output" == *"field: author"* ]]
}

# ----- subagent-record sub-blocks -----

@test "subagent-record missing artifacts_written sub-block fails" {
    off=$(write_entry "## subagent-record:plan · 2026-04-26T20:14:12Z

- author: subagent:plan
- status: success
- run_id: run-x

text

### decisions_made

-

### halt_directive

- halt: false
")
    run "$VALIDATE" "$LOG" "$off"
    [ "$status" -eq 1 ]
    [[ "$output" == *"artifacts_written"* ]]
}

@test "subagent-record missing decisions_made sub-block fails" {
    off=$(write_entry "## subagent-record:plan · 2026-04-26T20:14:12Z

- author: subagent:plan
- status: success
- run_id: run-x

text

### artifacts_written

-

### halt_directive

- halt: false
")
    run "$VALIDATE" "$LOG" "$off"
    [ "$status" -eq 1 ]
    [[ "$output" == *"decisions_made"* ]]
}

@test "subagent-record missing halt_directive sub-block fails" {
    off=$(write_entry "## subagent-record:plan · 2026-04-26T20:14:12Z

- author: subagent:plan
- status: success
- run_id: run-x

text

### artifacts_written

-

### decisions_made

-
")
    run "$VALIDATE" "$LOG" "$off"
    [ "$status" -eq 1 ]
    [[ "$output" == *"halt_directive"* ]]
}

# ----- halt_directive halt=true requirements (FR-019) -----

@test "halt=true with empty reason fails" {
    off=$(write_entry "## subagent-record:implement · 2026-04-26T20:14:12Z

- author: subagent:implement
- status: halt
- run_id: run-x

text

### artifacts_written

-

### decisions_made

-

### halt_directive

- halt: true
- reason:
- failure_class: semantic
")
    run "$VALIDATE" "$LOG" "$off"
    [ "$status" -eq 1 ]
    [[ "$output" == *"reason"* ]]
}

@test "halt=true with missing failure_class fails (FR-019)" {
    off=$(write_entry "## subagent-record:implement · 2026-04-26T20:14:12Z

- author: subagent:implement
- status: halt
- run_id: run-x

text

### artifacts_written

-

### decisions_made

-

### halt_directive

- halt: true
- reason: thing broke
")
    run "$VALIDATE" "$LOG" "$off"
    [ "$status" -eq 1 ]
    [[ "$output" == *"failure_class"* ]]
}

@test "halt=true with unrecognized failure_class fails (FR-019)" {
    off=$(write_entry "## subagent-record:implement · 2026-04-26T20:14:12Z

- author: subagent:implement
- status: halt
- run_id: run-x

text

### artifacts_written

-

### decisions_made

-

### halt_directive

- halt: true
- reason: thing broke
- failure_class: cosmic-rays
")
    run "$VALIDATE" "$LOG" "$off"
    [ "$status" -eq 1 ]
    [[ "$output" == *"failure_class"* ]]
}

# ----- byte-offset entry selection -----

@test "byte-offset selects correct entry in multi-entry log (second entry valid)" {
    cat > "$LOG" <<'EOF'
## stage-end:specify · 2026-04-26T20:00:00Z

- author: orchestrator
- status: maybe
- run_id: run-x

text
EOF
    bad_len=$(wc -c < "$LOG" | tr -d ' ')
    cat >> "$LOG" <<'EOF'

## stage-end:plan · 2026-04-26T20:14:12Z

- author: orchestrator
- status: success
- run_id: run-x

ok
EOF
    # Validate the second entry (valid) — should pass even though first is bad.
    run "$VALIDATE" "$LOG" "$bad_len"
    [ "$status" -eq 0 ]
}

# ----- usage errors -----

@test "missing log file exits 2" {
    run "$VALIDATE" "$FEATURE/no-such-file.md" 0
    [ "$status" -eq 2 ]
}

@test "missing args exits 2" {
    run "$VALIDATE"
    [ "$status" -eq 2 ]
}

@test "non-numeric byte offset exits 2" {
    : > "$LOG"
    run "$VALIDATE" "$LOG" abc
    [ "$status" -eq 2 ]
}
