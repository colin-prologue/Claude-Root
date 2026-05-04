#!/usr/bin/env bats

# T015 — run-emit-event.sh: ADR-020 sidecar JSONL + ADR-022 receipt validation.
# Source of truth:
#   contracts/sidecar-event.md (wire format, required fields per event type)
#   contracts/helper-contracts.md §run-emit-event.sh
#   ADR-022 (verdict-receipt enforcement)
#   FR-024 (stage-skip MUST carry non-empty criterion)
#
# V1 routing-decision set: {route, stage-skip, abort}. The `halt-*` family
# named in ADR-022 is deferred to V2 sidecar (LOG-025) — V1 records halts
# via the canonical decisions-log path only.

setup() {
    REPO_ROOT_FIXTURE="$(mktemp -d)"
    cd "$REPO_ROOT_FIXTURE"
    mkdir -p .specify/scripts/bash specs/001-foo
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-common.sh"        .specify/scripts/bash/
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-lock.sh"          .specify/scripts/bash/
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-decide-next.sh"   .specify/scripts/bash/
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-emit-event.sh"    .specify/scripts/bash/ 2>/dev/null || true
    EMIT=".specify/scripts/bash/run-emit-event.sh"
    DECIDE=".specify/scripts/bash/run-decide-next.sh"
    LOCK=".specify/scripts/bash/run-lock.sh"
    FEATURE="$REPO_ROOT_FIXTURE/specs/001-foo"
    LOG="$FEATURE/decisions-log.md"
    SIDECAR="$FEATURE/.run/control-flow.log"
    RECEIPT="$FEATURE/.run/last-verdict"
    "$LOCK" acquire "$FEATURE"
    RUN_ID="$(grep -E '^run_id=' "$FEATURE/.run/run-lock" | cut -d= -f2-)"
}

teardown() {
    rm -rf "$REPO_ROOT_FIXTURE"
}

# Seed a halt=false subagent-record so decide-next mints a `continue` verdict.
seed_continue_state() {
    cat >> "$LOG" <<EOF
## subagent-record:plan · 2026-04-26T20:14:12Z

- author: subagent:plan
- status: success
- run_id: $RUN_ID

ok.

### artifacts_written

- specs/001-foo/plan.md

### decisions_made

-

### halt_directive

- halt: false

EOF
}

# Seed and mint a continue verdict (receipt is non-empty after this).
seed_and_mint_continue() {
    seed_continue_state
    "$DECIDE" "$FEATURE" >/dev/null
}

# Surgically rewrite the verdict field of an existing receipt, preserving
# run_id / input_hash / ts. Used to test verdict↔event mapping paths whose
# verdicts (skip:X, etc.) decide-next produces only from specific log shapes.
rewrite_verdict() {
    local new_verdict="$1"
    local fields="$(cat "$RECEIPT")"
    local rid="$(printf '%s' "$fields" | cut -f2)"
    local h="$(printf '%s' "$fields" | cut -f3)"
    local ts="$(printf '%s' "$fields" | cut -f4)"
    printf '%s\t%s\t%s\t%s' "$new_verdict" "$rid" "$h" "$ts" > "$RECEIPT"
}

# ----- routing-decision set: route -----

@test "matched route consumes receipt and appends a JSONL line" {
    seed_and_mint_continue
    [ -s "$RECEIPT" ]
    run "$EMIT" "$FEATURE" route from=plan to=tasks reason=target-pipeline
    [ "$status" -eq 0 ]
    [ -s "$SIDECAR" ]
    # Receipt consumed (truncated to 0 bytes).
    [ ! -s "$RECEIPT" ]
    # Last line parses as JSON with required fields.
    last="$(tail -n1 "$SIDECAR")"
    echo "$last" | grep -q '"event":"route"'
    echo "$last" | grep -q "\"run_id\":\"$RUN_ID\""
    echo "$last" | grep -q '"from":"plan"'
    echo "$last" | grep -q '"to":"tasks"'
    echo "$last" | grep -q '"reason":"target-pipeline"'
    # ts is ISO-8601 UTC.
    echo "$last" | grep -qE '"ts":"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"'
}

@test "second route emission without fresh verdict refuses with verdict-mismatch" {
    seed_and_mint_continue
    "$EMIT" "$FEATURE" route from=plan to=tasks reason=target-pipeline
    # Receipt is now empty; second emission should refuse identically to missing receipt.
    run "$EMIT" "$FEATURE" route from=tasks to=analyze reason=target-pipeline
    [ "$status" -eq 1 ]
    grep -qE '^## verdict-mismatch:' "$LOG"
    # Sidecar still has only the first line.
    [ "$(wc -l < "$SIDECAR" | tr -d ' ')" = "1" ]
}

@test "missing receipt is treated identically to mismatched receipt" {
    # No decide-next called; receipt absent.
    [ ! -e "$RECEIPT" ]
    run "$EMIT" "$FEATURE" route from=plan to=tasks reason=target-pipeline
    [ "$status" -eq 1 ]
    grep -qE '^## verdict-mismatch:' "$LOG"
    # Sidecar not written.
    [ ! -e "$SIDECAR" ] || [ "$(wc -l < "$SIDECAR" | tr -d ' ')" = "0" ]
}

@test "stale cross-run receipt fails on run_id mismatch" {
    seed_continue_state
    # Forge a receipt with a different run_id.
    printf 'continue\trun-stale-9999\tabc123\t2026-04-26T19:00:00Z' > "$RECEIPT"
    run "$EMIT" "$FEATURE" route from=plan to=tasks reason=target-pipeline
    [ "$status" -eq 1 ]
    grep -qE '^## verdict-mismatch:' "$LOG"
}

@test "verdict-mismatch entry includes orchestrator author and halt status" {
    seed_continue_state
    printf 'continue\trun-stale\tabc\t2026-04-26T19:00:00Z' > "$RECEIPT"
    "$EMIT" "$FEATURE" route from=plan to=tasks reason=target-pipeline || true
    grep -qE '^- author: orchestrator$' "$LOG"
    grep -qE '^- status: halt$' "$LOG"
}

# ----- routing-decision set: stage-skip + FR-024 -----

@test "stage-skip with non-empty criterion: matched verdict consumes receipt" {
    # Mint continue; rewrite to skip:clarify so the receipt's run_id/input_hash
    # remain canonical (the matched-skip path under test).
    seed_and_mint_continue
    rewrite_verdict skip:clarify
    run "$EMIT" "$FEATURE" stage-skip stage=clarify criterion="no [NEEDS CLARIFICATION] markers"
    [ "$status" -eq 0 ]
    [ ! -s "$RECEIPT" ]
    last="$(tail -n1 "$SIDECAR")"
    echo "$last" | grep -q '"event":"stage-skip"'
    echo "$last" | grep -q '"stage":"clarify"'
    echo "$last" | grep -q '"criterion":"no \[NEEDS CLARIFICATION\] markers"'
}

@test "FR-024: stage-skip without criterion exits 2 (silent skips fail)" {
    seed_and_mint_continue
    rewrite_verdict skip:clarify
    run "$EMIT" "$FEATURE" stage-skip stage=clarify
    [ "$status" -eq 2 ]
    # No sidecar line written; receipt unchanged (still bears the verdict).
    [ ! -e "$SIDECAR" ] || [ "$(wc -l < "$SIDECAR" | tr -d ' ')" = "0" ]
    [ -s "$RECEIPT" ]
}

@test "FR-024: stage-skip with empty-string criterion exits 2" {
    seed_and_mint_continue
    rewrite_verdict skip:clarify
    run "$EMIT" "$FEATURE" stage-skip stage=clarify criterion=""
    [ "$status" -eq 2 ]
}

# ----- routing-decision set: abort -----

@test "abort with matched verdict consumes receipt and writes sidecar line" {
    seed_continue_state
    : > "$FEATURE/.run/abort"
    "$DECIDE" "$FEATURE" >/dev/null  # mints abort verdict
    [ "$(cut -f1 "$RECEIPT")" = "abort" ]
    run "$EMIT" "$FEATURE" abort triggered_by=sentinel
    [ "$status" -eq 0 ]
    [ ! -s "$RECEIPT" ]
    last="$(tail -n1 "$SIDECAR")"
    echo "$last" | grep -q '"event":"abort"'
    echo "$last" | grep -q '"triggered_by":"sentinel"'
}

# ----- non-routing events emit without receipt requirement -----

@test "stage-start emits without receipt requirement" {
    [ ! -e "$RECEIPT" ]
    run "$EMIT" "$FEATURE" stage-start stage=plan
    [ "$status" -eq 0 ]
    last="$(tail -n1 "$SIDECAR")"
    echo "$last" | grep -q '"event":"stage-start"'
    echo "$last" | grep -q '"stage":"plan"'
}

@test "break-lock emits without receipt requirement" {
    [ ! -e "$RECEIPT" ]
    run "$EMIT" "$FEATURE" break-lock prior_session=run-stale prior_ts=2026-04-26T18:00:00Z
    [ "$status" -eq 0 ]
    last="$(tail -n1 "$SIDECAR")"
    echo "$last" | grep -q '"event":"break-lock"'
    echo "$last" | grep -q '"prior_session":"run-stale"'
}

@test "budget-exhausted emits without receipt requirement" {
    [ ! -e "$RECEIPT" ]
    run "$EMIT" "$FEATURE" budget-exhausted tier=run tokens=51234
    [ "$status" -eq 0 ]
    last="$(tail -n1 "$SIDECAR")"
    echo "$last" | grep -q '"event":"budget-exhausted"'
    echo "$last" | grep -q '"tier":"run"'
}

@test "stage-start does not consume an existing receipt (non-routing)" {
    seed_and_mint_continue
    [ -s "$RECEIPT" ]
    "$EMIT" "$FEATURE" stage-start stage=tasks
    # Receipt unchanged (non-routing events don't consume).
    [ -s "$RECEIPT" ]
}

# ----- verdict↔event-type mapping (routing-decision set) -----

@test "verdict=continue with mismatched event=stage-skip refuses" {
    # decide-next minted continue; emitter must reject stage-skip.
    seed_and_mint_continue
    run "$EMIT" "$FEATURE" stage-skip stage=tasks criterion=mismatch
    [ "$status" -eq 1 ]
    grep -qE '^## verdict-mismatch:' "$LOG"
}

@test "verdict=skip:clarify with mismatched skipped-stage refuses" {
    seed_and_mint_continue
    rewrite_verdict skip:clarify
    # Verdict says skip:clarify but emitter passes stage=analyze ⇒ mismatch.
    run "$EMIT" "$FEATURE" stage-skip stage=analyze criterion=ok
    [ "$status" -eq 1 ]
    grep -qE '^## verdict-mismatch:' "$LOG"
}

# ----- truncation tolerance -----

@test "truncation tolerance: append succeeds even when last line is malformed" {
    seed_and_mint_continue
    mkdir -p "$FEATURE/.run"
    # Write a truncated last line by hand.
    printf '{"ts":"2026-04-26T20:00:00Z","event":"stage-start"' > "$SIDECAR"
    # No trailing newline — file ends mid-JSON.
    run "$EMIT" "$FEATURE" route from=plan to=tasks reason=target-pipeline
    [ "$status" -eq 0 ]
    # New line is appended; the prior truncated line is left intact (writer
    # MUST NOT corrupt prior content; readers handle truncation per ADR-020).
    grep -q '"event":"route"' "$SIDECAR"
}

# ----- usage / filesystem errors -----

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

@test "stage-skip without stage= field exits 2" {
    seed_and_mint_continue
    rewrite_verdict skip:clarify
    run "$EMIT" "$FEATURE" stage-skip criterion=ok
    [ "$status" -eq 2 ]
}

@test "route without from/to/reason exits 2" {
    seed_and_mint_continue
    run "$EMIT" "$FEATURE" route from=plan
    [ "$status" -eq 2 ]
}
