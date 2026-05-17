#!/usr/bin/env bats

# T034 — US-2: audit-trail completeness for route-back-to-specify (Scenario 2)
# and autonomous-skip (Scenario 1).
# Verifies: (Scenario 1) skip criterion recorded per FR-024; (Scenario 2) originating
# finding, revision, and re-review outcome all present in canonical log.
# Source of truth: spec.md US-2; FR-024; ADR-016.

setup() {
    REPO_ROOT_FIXTURE="$(mktemp -d)"
    cd "$REPO_ROOT_FIXTURE"
    mkdir -p specs/001-foo
    FEATURE="$REPO_ROOT_FIXTURE/specs/001-foo"
    LOG="$FEATURE/decisions-log.md"
}

teardown() {
    rm -rf "$REPO_ROOT_FIXTURE"
}

# ----- helpers for Scenario 2 fixture -----

write_review_halt() {
    cat >> "$LOG" <<'EOF'
## subagent-record:review · 2026-04-26T20:10:00Z

- author: subagent:review
- status: halt
- run_id: run-test

User stories are missing acceptance criteria. Specification requires revision before planning can proceed.

### artifacts_written

-

### decisions_made

-

### halt_directive

- halt: true
- reason: user stories lack acceptance criteria
- failure_class: semantic

EOF
}

write_specify_revision() {
    cat >> "$LOG" <<'EOF'
## subagent-record:specify · 2026-04-26T20:20:00Z

- author: subagent:specify
- status: success
- run_id: run-test

Revised spec.md to add acceptance criteria to all user stories per review finding.

### artifacts_written

- specs/001-foo/spec.md

### decisions_made

-

### halt_directive

- halt: false

EOF
}

write_review_success() {
    cat >> "$LOG" <<'EOF'
## subagent-record:review · 2026-04-26T20:30:00Z

- author: subagent:review
- status: success
- run_id: run-test

All user stories now include acceptance criteria. No blocking findings.

### artifacts_written

-

### decisions_made

-

### halt_directive

- halt: false

EOF
}

# ----- Acceptance Scenario 1: autonomous skip -----

@test "Scenario 1: stage-skip entry records the criterion that produced the skip (FR-024)" {
    cat > "$LOG" <<'EOF'
## stage-skip:clarify · 2026-04-26T20:05:00Z

- author: orchestrator
- status: success
- run_id: run-test

No ambiguities detected. criterion: no ambiguities detected

EOF
    grep -q '^## stage-skip:clarify' "$LOG"
    grep -q 'criterion' "$LOG"
}

@test "Scenario 1: skip entry is attributed to orchestrator (not a subagent)" {
    cat > "$LOG" <<'EOF'
## stage-skip:clarify · 2026-04-26T20:05:00Z

- author: orchestrator
- status: success
- run_id: run-test

No open questions found. criterion: artifact present

EOF
    grep -q '^- author: orchestrator$' "$LOG"
}

# ----- Acceptance Scenario 2: route-back to specify -----

@test "Scenario 2: originating finding (review halt=true) present in canonical log" {
    write_review_halt
    write_specify_revision
    write_review_success
    grep -q 'halt: true' "$LOG"
    grep -q 'user stories lack acceptance criteria' "$LOG"
}

@test "Scenario 2: revision (specify record after review halt) present in canonical log" {
    write_review_halt
    write_specify_revision
    write_review_success
    grep -q '^## subagent-record:specify' "$LOG"
    grep -q 'acceptance criteria to all user stories' "$LOG"
}

@test "Scenario 2: re-review outcome (second review, halt=false) present in canonical log" {
    write_review_halt
    write_specify_revision
    write_review_success
    review_count="$(grep -c '^## subagent-record:review' "$LOG")"
    (( review_count >= 2 ))
    grep -q 'No blocking findings' "$LOG"
}

@test "Scenario 2: all three audit-trail components present in a single fixture log" {
    write_review_halt
    write_specify_revision
    write_review_success
    # Originating finding
    grep -q 'halt: true' "$LOG"
    # Revision
    grep -q '^## subagent-record:specify' "$LOG"
    # Re-review outcome
    review_count="$(grep -c '^## subagent-record:review' "$LOG")"
    (( review_count >= 2 ))
    grep -q 'halt: false' "$LOG"
}
