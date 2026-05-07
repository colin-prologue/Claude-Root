#!/usr/bin/env bats

# T016 — run-serialize.sh: ADR-016 MUST-coalesce + ADR-022 step-6 invariant.
# Source of truth:
#   contracts/helper-contracts.md §run-serialize.sh
#   ADR-016 (decision-log canonical/derivative model)
#   ADR-022 step 6 (pipeline completeness invariant — termination-time)

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
    RECEIPT="$FEATURE/.run/last-verdict"
    "$LOCK" acquire "$FEATURE"
    RUN_ID="$(grep -E '^run_id=' "$FEATURE/.run/run-lock" | cut -d= -f2-)"
}

teardown() {
    rm -rf "$REPO_ROOT_FIXTURE"
}

# ----- helpers -----

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
    # Append a route JSONL line to the sidecar — bypasses run-emit-event.sh
    # so we can construct the exact sidecar state under test.
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
    [ ! -e "$LOG" ]
    emit_route_event plan tasks
    write_subagent_record plan
    # Decisions-log got created by write_subagent_record; remove it to truly cold-start.
    rm -f "$LOG"
    run "$SERIALIZE" "$FEATURE" clean
    [ "$status" -eq 0 ]
    [ -f "$LOG" ]
    grep -qE '^## ' "$LOG"
    grep -q 'clean' "$LOG"
}

@test "clean: appends coalesced summary via stage-then-rename (existing log)" {
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

@test "empty sidecar tolerated: summary appends with empty/no-event content" {
    : > "$SIDECAR"
    write_subagent_record plan
    # Provide a route so the per-stage record is covered (avoids invariant-b).
    emit_route_event plan tasks
    run "$SERIALIZE" "$FEATURE" clean
    [ "$status" -eq 0 ]
}

@test "missing sidecar tolerated as empty: summary still appends" {
    [ ! -e "$SIDECAR" ]
    # No subagent records ⇒ invariant-b vacuous.
    run "$SERIALIZE" "$FEATURE" clean
    [ "$status" -eq 0 ]
    grep -q 'clean' "$LOG"
}

# ----- termination kinds in summary -----

@test "termination kind appears in coalesced summary" {
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

# ----- invariant branch (a): non-empty receipt at termination -----

@test "invariant-a: continue verdict in receipt at clean termination ⇒ pipeline-incomplete" {
    write_subagent_record plan
    emit_route_event plan tasks
    # Receipt still bears 'continue' — orchestrator forgot to consume.
    printf 'continue\t%s\tabc\t2026-04-26T20:00:00Z' "$RUN_ID" > "$RECEIPT"
    "$SERIALIZE" "$FEATURE" clean
    grep -qE '^## pipeline-incomplete:' "$LOG"
    # Coalesced summary still appended afterward (invariant violation surfaces
    # in audit trail; does not block termination per ADR-022 step 6).
    [ "$(grep -c '^## ' "$LOG")" -ge 2 ]
}

@test "invariant-a: skip:X verdict in receipt at clean termination ⇒ pipeline-incomplete" {
    write_subagent_record plan
    emit_route_event plan tasks
    printf 'skip:clarify\t%s\tabc\t2026-04-26T20:00:00Z' "$RUN_ID" > "$RECEIPT"
    "$SERIALIZE" "$FEATURE" clean
    grep -qE '^## pipeline-incomplete:' "$LOG"
}

@test "invariant-a: empty receipt at clean termination ⇒ no pipeline-incomplete" {
    write_subagent_record plan
    emit_route_event plan tasks
    [ ! -s "$RECEIPT" ] || : > "$RECEIPT"
    "$SERIALIZE" "$FEATURE" clean
    ! grep -qE '^## pipeline-incomplete:' "$LOG"
}

@test "invariant-a: halt:* in receipt at halt termination is allowed" {
    write_subagent_record plan true subagent-halt-directive
    printf 'halt:subagent-halt-directive\t%s\tabc\t2026-04-26T20:00:00Z' "$RUN_ID" > "$RECEIPT"
    "$SERIALIZE" "$FEATURE" halt
    ! grep -qE '^## pipeline-incomplete:' "$LOG"
}

@test "invariant-a: continue verdict at halt termination still violates" {
    # halt termination_kind doesn't excuse a continue verdict — that means the
    # orchestrator routed past the last stage but then halted without consuming.
    write_subagent_record plan
    printf 'continue\t%s\tabc\t2026-04-26T20:00:00Z' "$RUN_ID" > "$RECEIPT"
    "$SERIALIZE" "$FEATURE" halt
    grep -qE '^## pipeline-incomplete:' "$LOG"
}

# ----- invariant branch (b): subagent-record without sidecar coverage -----

@test "invariant-b: subagent-record:plan with no route from=plan ⇒ pipeline-incomplete" {
    write_subagent_record plan
    # No route event in sidecar → coverage gap.
    "$SERIALIZE" "$FEATURE" clean
    grep -qE '^## pipeline-incomplete:' "$LOG"
}

@test "invariant-b: pipeline-incomplete entry names the missing-event stage(s)" {
    write_subagent_record plan
    write_subagent_record tasks
    emit_route_event plan tasks
    # tasks has subagent-record but no route from=tasks → covered=plan, missing=tasks.
    "$SERIALIZE" "$FEATURE" clean
    grep -A 20 '^## pipeline-incomplete:' "$LOG" | grep -q 'tasks'
}

@test "invariant-b: every stage covered ⇒ no pipeline-incomplete" {
    write_subagent_record plan
    emit_route_event plan tasks
    write_subagent_record tasks
    emit_route_event tasks analyze
    "$SERIALIZE" "$FEATURE" clean
    ! grep -qE '^## pipeline-incomplete:' "$LOG"
}

@test "invariant-b: last halt-marked subagent-record exempt under halt termination" {
    # Last stage halted; no route from=tasks expected. Earlier stages must
    # still have routes.
    write_subagent_record plan
    emit_route_event plan tasks
    write_subagent_record tasks true subagent-halt-directive
    "$SERIALIZE" "$FEATURE" halt
    ! grep -qE '^## pipeline-incomplete:' "$LOG"
}

# ----- both branches simultaneously -----

@test "both invariant branches violated: pipeline-incomplete written once, summary follows" {
    write_subagent_record plan
    # No route → branch (b) violation.
    printf 'continue\t%s\tabc\t2026-04-26T20:00:00Z' "$RUN_ID" > "$RECEIPT"  # branch (a)
    "$SERIALIZE" "$FEATURE" clean
    pi_count=$(grep -c '^## pipeline-incomplete:' "$LOG")
    [ "$pi_count" = "1" ]
    # The summary heading still follows.
    [ "$(grep -c '^## ' "$LOG")" -ge 3 ]
}

# ----- sidecar unparseable -----

@test "sidecar unparseable (invalid JSON, not just truncated) ⇒ exit 1" {
    write_subagent_record plan
    emit_route_event plan tasks
    # Inject a fully unparseable, complete-looking line (not just truncation —
    # readers tolerate truncation per ADR-020 §truncation recovery).
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

@test "valid termination kinds: clean / halt / abort / permission-failure all exit 0 on clean state" {
    write_subagent_record plan
    emit_route_event plan tasks
    for kind in clean halt abort permission-failure; do
        # Reset between runs by removing any pipeline-incomplete entries — we're
        # only checking the helper accepts each kind without a usage error.
        run "$SERIALIZE" "$FEATURE" "$kind"
        [ "$status" -eq 0 ]
    done
}
