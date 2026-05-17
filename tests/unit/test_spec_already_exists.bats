#!/usr/bin/env bats

# T030 — FR-023: spec.md-already-exists semantics and resume-scan filter.
# Scenarios: (1) spec.md complete → completeness returns complete (resume path);
# (2) decisions-log with pipeline-incomplete entry → route finds real subagent anchor;
# (3) speckit.run.md documents the --force guard for the no-decisions-log case.
# Source of truth: spec.md FR-023; contracts/helper-contracts.md §run-route.sh

setup() {
    REPO_ROOT_FIXTURE="$(mktemp -d)"
    cd "$REPO_ROOT_FIXTURE"
    mkdir -p .specify/scripts/bash specs/001-foo
    for h in run-common run-lock run-completeness run-route; do
        cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/$h.sh" .specify/scripts/bash/
    done
    LOCK=".specify/scripts/bash/run-lock.sh"
    COMPLETE=".specify/scripts/bash/run-completeness.sh"
    ROUTE=".specify/scripts/bash/run-route.sh"
    FEATURE="$REPO_ROOT_FIXTURE/specs/001-foo"
    LOG="$FEATURE/decisions-log.md"
    "$LOCK" acquire "$FEATURE"
}

teardown() {
    rm -rf "$REPO_ROOT_FIXTURE"
}

@test "FR-023 resume: spec.md complete → run-completeness specify returns complete" {
    cat > "$FEATURE/spec.md" <<'EOF'
## User Stories

content

## Functional Requirements

content

## Success Criteria

content
EOF
    result="$("$COMPLETE" "$FEATURE" specify)"
    [ "$result" = "complete" ]
}

@test "FR-023 resume-scan: pipeline-incomplete entry is skipped; real subagent-record is the routing anchor" {
    # Write a canonical-exception entry (pipeline-incomplete) followed by a real subagent-record
    cat > "$LOG" <<'EOF'
## pipeline-incomplete:specify · 2026-04-26T20:00:00Z

- author: orchestrator
- status: error
- run_id: run-old

incomplete pipeline record (canonical exception — not a valid resume anchor per FR-023)

## subagent-record:specify · 2026-04-26T20:01:00Z

- author: subagent:specify
- status: success
- run_id: run-x

rationale

### artifacts_written

-

### decisions_made

-

### halt_directive

- halt: false
EOF
    # Route should use the subagent-record anchor (halt=false → continue), not pipeline-incomplete
    verdict="$("$ROUTE" "$FEATURE" from=specify to=plan reason="subagent complete")"
    [ "$verdict" = "continue" ]
}

@test "FR-023 --force guard: speckit.run.md documents the spec.md-exists / no-decisions-log halt" {
    repo_root="$(git -C "$BATS_TEST_DIRNAME" rev-parse --show-toplevel)"
    cmd="$repo_root/.claude/commands/speckit.run.md"
    grep -q 'decisions-log\.md' "$cmd"
    grep -q '\-\-force' "$cmd"
}
