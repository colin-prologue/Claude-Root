#!/usr/bin/env bats

# T029 — FR-022: clarification serialization at the helper layer.
# When clarify stage halts, run-route.sh outputs halt — preventing dispatch of the next
# stage. When resolved (halt=false), run-route outputs continue, allowing the next stage.
# Source of truth: spec.md FR-022; contracts/helper-contracts.md §run-route.sh

setup() {
    REPO_ROOT_FIXTURE="$(mktemp -d)"
    cd "$REPO_ROOT_FIXTURE"
    mkdir -p .specify/scripts/bash specs/001-foo
    for h in run-common run-lock run-route; do
        cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/$h.sh" .specify/scripts/bash/
    done
    LOCK=".specify/scripts/bash/run-lock.sh"
    ROUTE=".specify/scripts/bash/run-route.sh"
    FEATURE="$REPO_ROOT_FIXTURE/specs/001-foo"
    LOG="$FEATURE/decisions-log.md"
    "$LOCK" acquire "$FEATURE"
}

teardown() {
    rm -rf "$REPO_ROOT_FIXTURE"
}

write_clarify_record() {
    local halt="$1"
    local hd
    if [[ "$halt" == "true" ]]; then
        hd=$'### halt_directive\n\n- halt: true\n- reason: open questions require input\n- failure_class: semantic\n'
    else
        hd=$'### halt_directive\n\n- halt: false\n'
    fi
    cat > "$LOG" <<EOF
## subagent-record:clarify · 2026-04-26T20:00:00Z

- author: subagent:clarify
- status: success
- run_id: run-x

rationale

### artifacts_written

-

### decisions_made

-

$hd
EOF
}

@test "FR-022: clarify halt=true → run-route outputs halt, preventing next stage dispatch" {
    write_clarify_record true
    verdict="$("$ROUTE" "$FEATURE" from=clarify to=plan reason="subagent complete")"
    [[ "$verdict" == halt:* ]]
    # Sidecar NOT written on halt (next stage is never dispatched)
    [ ! -f "$FEATURE/.run/control-flow.log" ] || ! grep -q '"event":"route"' "$FEATURE/.run/control-flow.log"
}

@test "FR-022: clarify halt=false → run-route outputs continue, next stage can be dispatched" {
    write_clarify_record false
    verdict="$("$ROUTE" "$FEATURE" from=clarify to=plan reason="subagent complete")"
    [ "$verdict" = "continue" ]
}
