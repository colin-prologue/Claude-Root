#!/usr/bin/env bats

# T035 — US-4 Acceptance Scenario 1: complete artifacts detected, next stage identified.
# run-completeness.sh detects spec.md + plan.md as complete (FR-026);
# next stage (tasks) detected as incomplete; artifact mtimes unchanged (SC-003).
# Source of truth: spec.md US-4 Scenario 1; FR-007; FR-026; SC-003.

setup() {
    REPO_ROOT_FIXTURE="$(mktemp -d)"
    cd "$REPO_ROOT_FIXTURE"
    mkdir -p .specify/scripts/bash specs/001-foo
    for h in run-common run-completeness; do
        cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/$h.sh" .specify/scripts/bash/
    done
    COMPLETE=".specify/scripts/bash/run-completeness.sh"
    FEATURE="$REPO_ROOT_FIXTURE/specs/001-foo"
}

teardown() {
    rm -rf "$REPO_ROOT_FIXTURE"
}

write_complete_spec() {
    cat > "$FEATURE/spec.md" <<'EOF'
## User Scenarios & Testing

At least one story.

## Requirements

At least one requirement.

## Success Criteria

At least one criterion.
EOF
}

write_complete_plan() {
    cat > "$FEATURE/plan.md" <<'EOF'
## Summary

High-level approach.

## Technical Context

Relevant context.

## Project Structure

Directory layout.
EOF
}

@test "Scenario 1: complete spec.md → run-completeness specify returns complete" {
    write_complete_spec
    result="$("$COMPLETE" "$FEATURE" specify)"
    [ "$result" = "complete" ]
}

@test "Scenario 1: complete plan.md → run-completeness plan returns complete" {
    write_complete_plan
    result="$("$COMPLETE" "$FEATURE" plan)"
    [ "$result" = "complete" ]
}

@test "Scenario 1: no tasks.md → run-completeness tasks returns incomplete (identifies next stage)" {
    write_complete_spec
    write_complete_plan
    result="$("$COMPLETE" "$FEATURE" tasks)"
    [ "$result" = "incomplete" ]
}

@test "SC-003: spec.md mtime unchanged after run-completeness read (resume does not touch artifacts)" {
    write_complete_spec
    before="$(stat -f %m "$FEATURE/spec.md")"
    "$COMPLETE" "$FEATURE" specify >/dev/null
    after="$(stat -f %m "$FEATURE/spec.md")"
    [ "$before" = "$after" ]
}

@test "SC-003: plan.md mtime unchanged after run-completeness read (resume does not touch artifacts)" {
    write_complete_plan
    before="$(stat -f %m "$FEATURE/plan.md")"
    "$COMPLETE" "$FEATURE" plan >/dev/null
    after="$(stat -f %m "$FEATURE/plan.md")"
    [ "$before" = "$after" ]
}
