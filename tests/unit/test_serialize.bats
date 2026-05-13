#!/usr/bin/env bats

# T016r — run-serialize.sh: ADR-016 MUST-coalesce (pipeline-completeness
# invariant removed per ADR-022 rev.1 — receipt protocol eliminated).
# Source of truth:
#   contracts/helper-contracts.md §run-serialize.sh
#   ADR-016 (decision-log canonical/derivative model)

setup() {
    REPO_ROOT_FIXTURE="$(mktemp -d)"
    cd "$REPO_ROOT_FIXTURE"
    mkdir -p .specify/scripts/bash specs/001-foo
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-common.sh"     .specify/scripts/bash/
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-lock.sh"       .specify/scripts/bash/
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-serialize.sh"  .specify/scripts/bash/ 2>/dev/null || true
    SERIALIZE=".specify/scripts/bash/run-serialize.sh"
    LOCK=".specify/scripts/bash/run-lock.sh"
    FEATURE="$REPO_ROOT_FIXTURE/specs/001-foo"
    LOG="$FEATURE/decisions-log.md"
    SIDECAR="$FEATURE/.run/control-flow.log"
    "$LOCK" acquire "$FEATURE"
    RUN_ID="$(grep -E '^run_id=' "$FEATURE/.run/run-lock" | cut -d= -f2-)"
}

teardown() {
    rm -rf "$REPO_ROOT_FIXTURE"
}

write_subagent_record() {
    local stage="$1" halt="${2:-false}" reason="${3:-}"
    local hd
    if [[ "$halt" == "true" ]]; then
        hd=$'### halt_directive\n\n- halt: true\n- reason: '"$reason"$'\n- failure_class: semantic\n'
    else
        hd=$'### halt_directive\n\n- halt: false\n'
    fi
    cat >> "$LOG" <<EOF
## subagent-record:$stage · 2026-04-26T20:14:12Z

- author: subagent:$stage
- status: $([[ "$halt" == "true" ]] && echo halt || echo success)
- run_id: $RUN_ID

ok.

### artifacts_written

- specs/001-foo/$stage.md

### decisions_made

-

$hd
EOF
}

emit_route_event() {
    local from="$1" to="$2"
    mkdir -p "$FEATURE/.run"
    printf '{"ts":"2026-04-26T20:15:00Z","event":"route","run_id":"%s","from":"%s","to":"%s","reason":"target-pipeline"}\n' \
        "$RUN_ID" "$from" "$to" >> "$SIDECAR"
}

emit_abort_event() {
    mkdir -p "$FEATURE/.run"
    printf '{"ts":"2026-04-26T20:15:00Z","event":"abort","run_id":"%s","triggered_by":"sentinel"}\n' \
        "$RUN_ID" >> "$SIDECAR"
}

# ----- happy path: clean termination -----

@test "clean: cold start (no decisions-log.md) creates file with coalesced summary" {
    emit_route_event plan tasks
    run "$SERIALIZE" "$FEATURE" clean
    [ "$status" -eq 0 ]
    [ -f "$LOG" ]
    grep -qE '^## ' "$LOG"
    grep -q 'clean' "$LOG"
}

@test "clean: appends coalesced summary to existing log via stage-then-rename" {
    write_subagent_record plan
    emit_route_event plan tasks
    write_subagent_record tasks
    emit_route_event tasks analyze
    pre_size=$(wc -c < "$LOG" | tr -d ' ')
    run "$SERIALIZE" "$FEATURE" clean
    [ "$status" -eq 0 ]
    post_size=$(wc -c < "$LOG" | tr -d ' ')
    [ "$post_size" -gt "$pre_size" ]
    # No leftover staging tmp file.
    ! ls "$FEATURE"/decisions-log.md.*.tmp 2>/dev/null
}

@test "empty sidecar tolerated: coalesced summary appended" {
    : > "$SIDECAR"
    run "$SERIALIZE" "$FEATURE" clean
    [ "$status" -eq 0 ]
}

@test "missing sidecar tolerated: coalesced summary appended" {
    [ ! -e "$SIDECAR" ]
    run "$SERIALIZE" "$FEATURE" clean
    [ "$status" -eq 0 ]
    grep -q 'clean' "$LOG"
}

# ----- termination kinds in summary -----

@test "halt termination kind appears in coalesced summary" {
    write_subagent_record plan true subagent-halt-directive
    "$SERIALIZE" "$FEATURE" halt
    grep -qiE 'halt' "$LOG"
}

@test "abort termination kind appears in coalesced summary" {
    write_subagent_record plan
    emit_route_event plan tasks
    emit_abort_event
    "$SERIALIZE" "$FEATURE" abort
    grep -qiE 'abort' "$LOG"
}

# ----- pipeline-completeness invariant removed (ADR-022 rev.1) -----

@test "no pipeline-incomplete entry written — invariant removed in ADR-022 rev.1" {
    # Old design would emit pipeline-incomplete here because plan has no route.
    write_subagent_record plan
    "$SERIALIZE" "$FEATURE" clean
    ! grep -qE '^## pipeline-incomplete:' "$LOG"
}

# ----- sidecar unparseable -----

@test "sidecar unparseable (invalid JSON, not just truncated) ⇒ exit 1" {
    printf '{this is not valid json at all}\n' > "$SIDECAR"
    run "$SERIALIZE" "$FEATURE" clean
    [ "$status" -eq 1 ]
}

# ----- usage / args -----

@test "missing args exits 2" {
    run "$SERIALIZE"
    [ "$status" -eq 2 ]
}

@test "invalid termination_kind exits 2" {
    run "$SERIALIZE" "$FEATURE" not-a-real-kind
    [ "$status" -eq 2 ]
}

@test "all termination kinds accepted without usage error" {
    for kind in clean halt abort permission-failure; do
        run "$SERIALIZE" "$FEATURE" "$kind"
        [ "$status" -eq 0 ]
    done
}
