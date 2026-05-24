#!/usr/bin/env bats

# T027 — integration: full per-stage helper sequence (lock→completeness→start→fixture-log→route).
# No real subagent dispatch — a fixture decisions-log entry stands in for subagent output.
# Tests the non-code (specify) stage path; sandbox+postcheck are covered by dedicated tests.
# Source of truth: contracts/helper-contracts.md; plan.md §PR3b-ii

setup() {
    REPO_ROOT_FIXTURE="$(mktemp -d)"
    cd "$REPO_ROOT_FIXTURE"
    mkdir -p .specify/scripts/bash specs/001-foo
    for h in run-common run-lock run-completeness run-emit-event run-route run-serialize; do
        cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/$h.sh" .specify/scripts/bash/
    done
    LOCK=".specify/scripts/bash/run-lock.sh"
    COMPLETE=".specify/scripts/bash/run-completeness.sh"
    START=".specify/scripts/bash/run-emit-event.sh"
    ROUTE=".specify/scripts/bash/run-route.sh"
    SERIALIZE=".specify/scripts/bash/run-serialize.sh"
    FEATURE="$REPO_ROOT_FIXTURE/specs/001-foo"
    LOG="$FEATURE/decisions-log.md"
    SIDECAR="$FEATURE/.run/control-flow.log"
    "$LOCK" acquire "$FEATURE"
}

teardown() {
    rm -rf "$REPO_ROOT_FIXTURE"
}

@test "specify stage happy path: incomplete→start→fixture-log→route outputs continue" {
    # completeness: spec.md absent → incomplete
    result="$("$COMPLETE" "$FEATURE" specify)"
    [ "$result" = "incomplete" ]

    # emit stage-start
    "$START" "$FEATURE" stage-start stage=specify

    # fixture subagent record (halt=false)
    cat > "$LOG" <<'EOF'
## subagent-record:specify · 2026-04-26T20:00:00Z

- author: subagent:specify
- status: success
- run_id: run-x

rationale

### artifacts_written

- specs/001-foo/spec.md

### decisions_made

-

### halt_directive

- halt: false
EOF

    # route: expect continue
    verdict="$("$ROUTE" "$FEATURE" from=specify to=plan reason="subagent complete")"
    [ "$verdict" = "continue" ]

    # sidecar has a route event
    grep -q '"event":"route"' "$SIDECAR"
}

@test "specify stage complete → write stage-skip entry + route emits stage-skip event in sidecar" {
    # Write a complete spec.md (all mandatory sections present)
    cat > "$FEATURE/spec.md" <<'EOF'
## User Scenarios & Testing

content

## Requirements

content

## Success Criteria

content
EOF

    result="$("$COMPLETE" "$FEATURE" specify)"
    [ "$result" = "complete" ]

    # orchestrator writes stage-skip decisions-log entry before calling run-route.sh
    run_id_val="$(grep '^run_id=' "$FEATURE/.run/run-lock" | cut -d= -f2-)"
    printf '## stage-skip:specify · 2026-04-26T20:00:00Z\n\n- author: orchestrator\n- status: success\n- run_id: %s\n\nArtifact present.\n\n' \
        "$run_id_val" >> "$LOG"

    # skip route
    "$ROUTE" "$FEATURE" stage=specify criterion="artifact already present"

    # sidecar has stage-skip event
    grep -q '"event":"stage-skip"' "$SIDECAR"
}
