#!/usr/bin/env bats

# T006 — run-lock.sh: acquire | release | break | check-sentinel
# Source of truth: helper-contracts.md §run-lock.sh, FR-027/FR-028, ADR-018, ADR-022, LOG-012.

setup() {
    REPO_ROOT_FIXTURE="$(mktemp -d)"
    cd "$REPO_ROOT_FIXTURE"
    mkdir -p .specify/scripts/bash specs/001-foo
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-common.sh" .specify/scripts/bash/
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-lock.sh"   .specify/scripts/bash/ 2>/dev/null || true
    LOCK=".specify/scripts/bash/run-lock.sh"
    FEATURE="$REPO_ROOT_FIXTURE/specs/001-foo"
}

teardown() {
    rm -rf "$REPO_ROOT_FIXTURE"
}

@test "acquire creates run-lock with run_id and created_at" {
    run "$LOCK" acquire "$FEATURE"
    [ "$status" -eq 0 ]
    [ -f "$FEATURE/.run/run-lock" ]
    grep -qE '^run_id=run-' "$FEATURE/.run/run-lock"
    grep -qE '^created_at=' "$FEATURE/.run/run-lock"
}

@test "second acquire on a held lock exits 1 and prints lock contents" {
    "$LOCK" acquire "$FEATURE"
    run "$LOCK" acquire "$FEATURE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"run_id=run-"* ]]
}

@test "release removes run-lock atomically along with abort sentinel" {
    "$LOCK" acquire "$FEATURE"
    : > "$FEATURE/.run/abort"
    run "$LOCK" release "$FEATURE"
    [ "$status" -eq 0 ]
    [ ! -e "$FEATURE/.run/run-lock" ]
    [ ! -e "$FEATURE/.run/abort" ]
}

@test "release also wipes last-verdict (ADR-022 cleanup)" {
    "$LOCK" acquire "$FEATURE"
    printf 'continue\trun-x\thash\t2026-04-26T20:00:00Z' > "$FEATURE/.run/last-verdict"
    "$LOCK" release "$FEATURE"
    [ ! -e "$FEATURE/.run/last-verdict" ]
}

@test "break tolerates absence of active session and emits break-lock event" {
    # No prior lock; break should still succeed.
    run "$LOCK" break "$FEATURE"
    [ "$status" -eq 0 ]
}

@test "break clears an existing stale lock" {
    "$LOCK" acquire "$FEATURE"
    run "$LOCK" break "$FEATURE"
    [ "$status" -eq 0 ]
    [ ! -e "$FEATURE/.run/run-lock" ]
}

@test "acquire wipes stale last-verdict (ADR-022 step 6)" {
    mkdir -p "$FEATURE/.run"
    printf 'stale\trun-old\thash\tts' > "$FEATURE/.run/last-verdict"
    "$LOCK" acquire "$FEATURE"
    [ ! -s "$FEATURE/.run/last-verdict" ] || [ ! -e "$FEATURE/.run/last-verdict" ]
}

@test "acquire sweeps orphan .tmp files (LOG-012)" {
    mkdir -p "$FEATURE/.run"
    : > "$FEATURE/.run/decisions-log.md.run-x.tmp"
    : > "$FEATURE/.run/control-flow.log.run-y.tmp"
    "$LOCK" acquire "$FEATURE"
    [ ! -e "$FEATURE/.run/decisions-log.md.run-x.tmp" ]
    [ ! -e "$FEATURE/.run/control-flow.log.run-y.tmp" ]
}

@test "check-sentinel exit 0 when no abort file" {
    "$LOCK" acquire "$FEATURE"
    run "$LOCK" check-sentinel "$FEATURE"
    [ "$status" -eq 0 ]
}

@test "check-sentinel exit 1 when abort file present" {
    "$LOCK" acquire "$FEATURE"
    : > "$FEATURE/.run/abort"
    run "$LOCK" check-sentinel "$FEATURE"
    [ "$status" -eq 1 ]
}

@test "usage error exits 2 (unknown command)" {
    run "$LOCK" frobnicate "$FEATURE"
    [ "$status" -eq 2 ]
}

@test "usage error exits 2 (missing feature-dir)" {
    run "$LOCK" acquire
    [ "$status" -eq 2 ]
}
