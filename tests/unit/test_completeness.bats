#!/usr/bin/env bats

# T010 — run-completeness.sh: V1 per-stage completeness predicates.
# Source of truth: helper-contracts.md §run-completeness.sh, FR-026, data-model.md E-7.

setup() {
    REPO_ROOT_FIXTURE="$(mktemp -d)"
    cd "$REPO_ROOT_FIXTURE"
    mkdir -p .specify/scripts/bash specs/001-foo
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-common.sh"        .specify/scripts/bash/
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-completeness.sh"  .specify/scripts/bash/ 2>/dev/null || true
    COMP=".specify/scripts/bash/run-completeness.sh"
    FEATURE="$REPO_ROOT_FIXTURE/specs/001-foo"
}

teardown() {
    rm -rf "$REPO_ROOT_FIXTURE"
}

# Helper — write a "complete-shaped" spec.md with mandatory sections.
write_complete_spec() {
    cat > "$FEATURE/spec.md" <<'EOF'
# Feature

## User Stories

US-1 ...

## Functional Requirements

FR-001 ...

## Success Criteria

SC-001 ...
EOF
}

# Helper — write a "complete-shaped" plan.md.
write_complete_plan() {
    cat > "$FEATURE/plan.md" <<'EOF'
# Plan

## Summary

x

## Technical Context

x

## Project Structure

x
EOF
}

# Helper — append a stage-end entry to decisions-log.md for the named stage.
append_stage_end() {
    local stage="$1"
    cat >> "$FEATURE/decisions-log.md" <<EOF

## stage-end:${stage} · 2026-04-26T20:00:00Z

- author: subagent:${stage}
- status: success
- run_id: run-x

ok
EOF
}

# ----- specify -----

@test "specify: complete when spec.md has mandatory sections + no [NEEDS CLARIFICATION]" {
    write_complete_spec
    run "$COMP" "$FEATURE" specify
    [ "$status" -eq 0 ]
    [ "$output" = "complete" ]
}

@test "specify: incomplete when spec.md missing" {
    run "$COMP" "$FEATURE" specify
    [ "$status" -eq 0 ]
    [ "$output" = "incomplete" ]
}

@test "specify: incomplete when spec.md has [NEEDS CLARIFICATION] marker" {
    write_complete_spec
    echo "[NEEDS CLARIFICATION]" >> "$FEATURE/spec.md"
    run "$COMP" "$FEATURE" specify
    [ "$status" -eq 0 ]
    [ "$output" = "incomplete" ]
}

@test "specify: incomplete when spec.md missing a mandatory section" {
    cat > "$FEATURE/spec.md" <<'EOF'
# Feature
## User Stories
x
EOF
    run "$COMP" "$FEATURE" specify
    [ "$status" -eq 0 ]
    [ "$output" = "incomplete" ]
}

# ----- plan -----

@test "plan: complete when plan.md has mandatory sections" {
    write_complete_plan
    run "$COMP" "$FEATURE" plan
    [ "$status" -eq 0 ]
    [ "$output" = "complete" ]
}

@test "plan: incomplete when plan.md missing" {
    run "$COMP" "$FEATURE" plan
    [ "$status" -eq 0 ]
    [ "$output" = "incomplete" ]
}

# ----- tasks -----

@test "tasks: complete when tasks.md has at least one task block" {
    cat > "$FEATURE/tasks.md" <<'EOF'
# Tasks
- [ ] T001 do the thing
EOF
    run "$COMP" "$FEATURE" tasks
    [ "$status" -eq 0 ]
    [ "$output" = "complete" ]
}

@test "tasks: incomplete when tasks.md has no task lines" {
    cat > "$FEATURE/tasks.md" <<'EOF'
# Tasks
no tasks here
EOF
    run "$COMP" "$FEATURE" tasks
    [ "$status" -eq 0 ]
    [ "$output" = "incomplete" ]
}

# ----- review / clarify / analyze -----

@test "review: complete when decisions-log.md has matching stage-end" {
    append_stage_end review
    run "$COMP" "$FEATURE" review
    [ "$status" -eq 0 ]
    [ "$output" = "complete" ]
}

@test "review: incomplete when decisions-log.md absent" {
    run "$COMP" "$FEATURE" review
    [ "$status" -eq 0 ]
    [ "$output" = "incomplete" ]
}

@test "clarify: complete when decisions-log.md has matching stage-end" {
    append_stage_end clarify
    run "$COMP" "$FEATURE" clarify
    [ "$status" -eq 0 ]
    [ "$output" = "complete" ]
}

@test "analyze: complete when decisions-log.md has matching stage-end" {
    append_stage_end analyze
    run "$COMP" "$FEATURE" analyze
    [ "$status" -eq 0 ]
    [ "$output" = "complete" ]
}

# ----- code-action stages -----

@test "implement: incomplete unconditionally (always re-runs)" {
    write_complete_plan
    run "$COMP" "$FEATURE" implement
    [ "$status" -eq 0 ]
    [ "$output" = "incomplete" ]
}

@test "codereview: incomplete unconditionally" {
    run "$COMP" "$FEATURE" codereview
    [ "$status" -eq 0 ]
    [ "$output" = "incomplete" ]
}

@test "audit: incomplete unconditionally" {
    run "$COMP" "$FEATURE" audit
    [ "$status" -eq 0 ]
    [ "$output" = "incomplete" ]
}

# ----- usage -----

@test "unknown stage exits 2" {
    run "$COMP" "$FEATURE" frobnicate
    [ "$status" -eq 2 ]
}

@test "missing args exits 2" {
    run "$COMP" "$FEATURE"
    [ "$status" -eq 2 ]
}
