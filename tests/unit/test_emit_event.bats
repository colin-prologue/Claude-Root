#!/usr/bin/env bats

# T015r — run-emit-event.sh: non-routing sidecar event emitter.
# Routing decisions (route, stage-skip, abort) moved to run-route.sh (ADR-022 rev.1).
# This file covers only the three non-routing events: stage-start, break-lock,
# budget-exhausted.
#
# Source of truth:
#   contracts/sidecar-event.md (wire format, required fields per event type)
#   contracts/helper-contracts.md §run-emit-event.sh

setup() {
    REPO_ROOT_FIXTURE="$(mktemp -d)"
    cd "$REPO_ROOT_FIXTURE"
    mkdir -p .specify/scripts/bash specs/001-foo
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-common.sh"     .specify/scripts/bash/
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-lock.sh"       .specify/scripts/bash/
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-emit-event.sh" .specify/scripts/bash/
    EMIT=".specify/scripts/bash/run-emit-event.sh"
    LOCK=".specify/scripts/bash/run-lock.sh"
    FEATURE="$REPO_ROOT_FIXTURE/specs/001-foo"
    SIDECAR="$FEATURE/.run/control-flow.log"
    "$LOCK" acquire "$FEATURE"
    RUN_ID="$(grep -E '^run_id=' "$FEATURE/.run/run-lock" | cut -d= -f2-)"
}

teardown() {
    rm -rf "$REPO_ROOT_FIXTURE"
}

# ----- non-routing events -----

@test "stage-start emits JSONL line with correct fields" {
    run "$EMIT" "$FEATURE" stage-start stage=plan
    [ "$status" -eq 0 ]
    [ -s "$SIDECAR" ]
    last="$(tail -n1 "$SIDECAR")"
    echo "$last" | grep -q '"event":"stage-start"'
    echo "$last" | grep -q '"stage":"plan"'
    echo "$last" | grep -q "\"run_id\":\"$RUN_ID\""
    echo "$last" | grep -qE '"ts":"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"'
}

@test "break-lock emits JSONL line with prior_session and prior_ts" {
    run "$EMIT" "$FEATURE" break-lock prior_session=run-stale prior_ts=2026-04-26T18:00:00Z
    [ "$status" -eq 0 ]
    last="$(tail -n1 "$SIDECAR")"
    echo "$last" | grep -q '"event":"break-lock"'
    echo "$last" | grep -q '"prior_session":"run-stale"'
    echo "$last" | grep -q '"prior_ts":"2026-04-26T18:00:00Z"'
}

@test "budget-exhausted emits JSONL line with tier and tokens" {
    run "$EMIT" "$FEATURE" budget-exhausted tier=run tokens=51234
    [ "$status" -eq 0 ]
    last="$(tail -n1 "$SIDECAR")"
    echo "$last" | grep -q '"event":"budget-exhausted"'
    echo "$last" | grep -q '"tier":"run"'
    echo "$last" | grep -q '"tokens":"51234"'
}

# ----- routing events now belong to run-route.sh -----

@test "route is a routing event handled by run-route.sh — exits 2" {
    run "$EMIT" "$FEATURE" route from=plan to=tasks reason=target-pipeline
    [ "$status" -eq 2 ]
}

# ----- truncation tolerance -----

@test "truncation tolerance: append succeeds when prior last line lacks newline" {
    mkdir -p "$FEATURE/.run"
    # Write a truncated last line (no trailing newline).
    printf '{"ts":"2026-04-26T20:00:00Z","event":"stage-start","run_id":"x"' > "$SIDECAR"
    run "$EMIT" "$FEATURE" stage-start stage=tasks
    [ "$status" -eq 0 ]
    # New event is present as a valid separate line.
    grep -q '"event":"stage-start"' "$SIDECAR"
    grep -q '"stage":"tasks"' "$SIDECAR"
}

# ----- usage / validation errors -----

@test "missing feature-dir arg exits 2" {
    run "$EMIT"
    [ "$status" -eq 2 ]
}

@test "unknown event name exits 2" {
    run "$EMIT" "$FEATURE" not-a-real-event
    [ "$status" -eq 2 ]
}

@test "no run-lock present exits non-zero" {
    rm -f "$FEATURE/.run/run-lock"
    run "$EMIT" "$FEATURE" stage-start stage=plan
    [ "$status" -ne 0 ]
}

@test "stage-start without stage= exits 2" {
    run "$EMIT" "$FEATURE" stage-start
    [ "$status" -eq 2 ]
}
