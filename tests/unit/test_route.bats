#!/usr/bin/env bats

# T014r+T015r — run-route.sh: atomic routing-decision helper.
# Replaces two-step run-decide-next.sh + run-emit-event.sh receipt protocol
# (ADR-022 rev.1: single-process routing eliminates verdict-receipt).
#
# Source of truth:
#   contracts/helper-contracts.md §run-route.sh
#   ADR-019 (deterministic core), ADR-022 rev.1 (single-helper routing)
#   data-model.md §E-7 (routing matrix)
#   FR-021 (multi-blocker), FR-023 (resume-scan), FR-024 (stage-skip criterion),
#   FR-025 (below-threshold-continue)
#
# Key invariant under test: run-route.sh MUST NOT write a last-verdict receipt;
# sequential calls MUST succeed without pre-flight checks.

setup() {
    REPO_ROOT_FIXTURE="$(mktemp -d)"
    cd "$REPO_ROOT_FIXTURE"
    mkdir -p .specify/scripts/bash specs/001-foo
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-common.sh" .specify/scripts/bash/
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-lock.sh"   .specify/scripts/bash/
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-route.sh"  .specify/scripts/bash/ 2>/dev/null || true
    ROUTE=".specify/scripts/bash/run-route.sh"
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

# write_subagent_record <stage> <halt:true|false> [reason] [failure_class]
write_subagent_record() {
    local stage="$1" halt="$2" reason="${3:-}" fc="${4:-semantic}"
    local hd
    if [[ "$halt" == "true" ]]; then
        hd=$'### halt_directive\n\n- halt: true\n- reason: '"$reason"$'\n- failure_class: '"$fc"$'\n'
    else
        hd=$'### halt_directive\n\n- halt: false\n'
    fi
    cat >> "$LOG" <<EOF
## subagent-record:$stage · 2026-04-26T20:14:12Z

- author: subagent:$stage
- status: $([[ "$halt" == "true" ]] && echo halt || echo success)
- run_id: $RUN_ID

stage rationale.

### artifacts_written

- specs/001-foo/$stage.md

### decisions_made

-

$hd
EOF
}

# write a stage-skip log entry (as the orchestrator-authored canonical control-flow entry)
write_stage_skip_entry() {
    local stage="$1"
    cat >> "$LOG" <<EOF
## stage-skip:$stage · 2026-04-26T20:14:12Z

- author: orchestrator
- status: success
- run_id: $RUN_ID

Skipped stage $stage.

EOF
}

# ----- continue path -----

@test "continue: latest subagent-record halt=false emits route event, stdout=continue, exit 0" {
    write_subagent_record plan false
    run "$ROUTE" "$FEATURE" from=plan to=tasks reason=target-pipeline
    [ "$status" -eq 0 ]
    [ "$output" = "continue" ]
    [ -s "$SIDECAR" ]
}

@test "continue: route event has correct fields (event, from, to, reason, run_id, ts)" {
    write_subagent_record plan false
    "$ROUTE" "$FEATURE" from=plan to=tasks reason=target-pipeline
    last="$(tail -n1 "$SIDECAR")"
    echo "$last" | grep -q '"event":"route"'
    echo "$last" | grep -q '"from":"plan"'
    echo "$last" | grep -q '"to":"tasks"'
    echo "$last" | grep -q '"reason":"target-pipeline"'
    echo "$last" | grep -q "\"run_id\":\"$RUN_ID\""
    echo "$last" | grep -qE '"ts":"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"'
}

@test "continue: no receipt file written (key invariant of ADR-022 rev.1)" {
    write_subagent_record plan false
    "$ROUTE" "$FEATURE" from=plan to=tasks reason=target-pipeline
    [ ! -s "$RECEIPT" ]
}

@test "sequential routing calls succeed without error (no pre-flight omission check)" {
    write_subagent_record plan false
    "$ROUTE" "$FEATURE" from=plan to=tasks reason=first-call
    write_subagent_record tasks false
    run "$ROUTE" "$FEATURE" from=tasks to=implement reason=second-call
    [ "$status" -eq 0 ]
    [ "$output" = "continue" ]
}

# ----- halt path -----

@test "halt:subagent-halt-directive: stdout=halt:..., exit 0, sidecar NOT written" {
    write_subagent_record plan true "subagent-halt-directive" semantic
    run "$ROUTE" "$FEATURE" from=plan to=tasks reason=n/a
    [ "$status" -eq 0 ]
    [ "$output" = "halt:subagent-halt-directive" ]
    [ ! -s "$SIDECAR" ]
}

@test "halt: reason flows through verbatim (schema-violation)" {
    write_subagent_record plan true "schema-violation" semantic
    run "$ROUTE" "$FEATURE" from=plan to=tasks reason=n/a
    [ "$status" -eq 0 ]
    [ "$output" = "halt:schema-violation" ]
}

@test "halt: reason flows through verbatim (postcheck-failed)" {
    write_subagent_record codereview true "postcheck-failed" semantic
    run "$ROUTE" "$FEATURE" from=codereview to=audit reason=n/a
    [ "$status" -eq 0 ]
    [ "$output" = "halt:postcheck-failed" ]
}

@test "halt: unspecified reason when reason field is absent" {
    # halt=true but no - reason: line in halt_directive → halt:unspecified
    cat >> "$LOG" <<EOF
## subagent-record:plan · 2026-04-26T20:14:12Z

- author: subagent:plan
- status: halt
- run_id: $RUN_ID

rationale.

### artifacts_written

-

### decisions_made

-

### halt_directive

- halt: true

EOF
    run "$ROUTE" "$FEATURE" from=plan to=tasks reason=n/a
    [ "$status" -eq 0 ]
    [ "$output" = "halt:unspecified" ]
}

# ----- below-threshold-continue (FR-025) -----

@test "FR-025: review subagent with halt=false ⇒ continue (below-threshold)" {
    write_subagent_record review false
    run "$ROUTE" "$FEATURE" from=review to=implement reason=no-blockers
    [ "$status" -eq 0 ]
    [ "$output" = "continue" ]
}

# ----- abort sentinel (ADR-019 b1) -----

@test "abort sentinel: stdout=abort, exit 0, abort event emitted to sidecar" {
    write_subagent_record plan false
    : > "$FEATURE/.run/abort"
    run "$ROUTE" "$FEATURE" triggered_by=sentinel
    [ "$status" -eq 0 ]
    [ "$output" = "abort" ]
    [ -s "$SIDECAR" ]
    last="$(tail -n1 "$SIDECAR")"
    echo "$last" | grep -q '"event":"abort"'
    echo "$last" | grep -q '"triggered_by":"sentinel"'
}

@test "abort takes precedence over halt=true subagent record" {
    write_subagent_record plan true "subagent-halt-directive" semantic
    : > "$FEATURE/.run/abort"
    run "$ROUTE" "$FEATURE" triggered_by=sentinel
    [ "$status" -eq 0 ]
    [ "$output" = "abort" ]
}

# ----- stage-skip path (FR-024) -----

@test "stage-skip: latest anchor is stage-skip entry ⇒ stdout=skip:clarify, stage-skip event emitted" {
    write_stage_skip_entry clarify
    run "$ROUTE" "$FEATURE" stage=clarify criterion="no NEEDS CLARIFICATION markers"
    [ "$status" -eq 0 ]
    [ "$output" = "skip:clarify" ]
    [ -s "$SIDECAR" ]
    last="$(tail -n1 "$SIDECAR")"
    echo "$last" | grep -q '"event":"stage-skip"'
    echo "$last" | grep -q '"stage":"clarify"'
    echo "$last" | grep -q '"criterion":"no NEEDS CLARIFICATION markers"'
}

@test "FR-024: stage-skip without criterion= exits 2 (silent skips prohibited)" {
    write_stage_skip_entry clarify
    run "$ROUTE" "$FEATURE" stage=clarify
    [ "$status" -eq 2 ]
    [ ! -s "$SIDECAR" ]
}

@test "FR-024: stage-skip with empty criterion= exits 2" {
    write_stage_skip_entry clarify
    run "$ROUTE" "$FEATURE" stage=clarify criterion=""
    [ "$status" -eq 2 ]
}

# ----- resume-scan filter (FR-023) -----

@test "resume-scan: pipeline-incomplete orchestrator entry does not become routing anchor" {
    write_subagent_record plan false
    cat >> "$LOG" <<EOF

## pipeline-incomplete:orchestrator · 2026-04-26T20:15:00Z

- author: orchestrator
- status: halt
- run_id: $RUN_ID

Bookkeeping entry — not a routing anchor.

EOF
    run "$ROUTE" "$FEATURE" from=plan to=tasks reason=target-pipeline
    [ "$status" -eq 0 ]
    [ "$output" = "continue" ]
}

@test "resume-scan: second subagent-record is the routing anchor, not the first" {
    write_subagent_record plan false
    write_subagent_record tasks true "schema-violation" semantic
    run "$ROUTE" "$FEATURE" from=tasks to=implement reason=n/a
    [ "$status" -eq 0 ]
    [ "$output" = "halt:schema-violation" ]
}

# ----- malformed / missing log -----

@test "missing decisions-log.md exits 1" {
    [ ! -f "$LOG" ]
    run "$ROUTE" "$FEATURE" from=plan to=tasks reason=n/a
    [ "$status" -eq 1 ]
}

@test "empty decisions-log.md exits 1 (no routable anchor)" {
    : > "$LOG"
    run "$ROUTE" "$FEATURE" from=plan to=tasks reason=n/a
    [ "$status" -eq 1 ]
}

# ----- usage errors -----

@test "missing feature-dir arg exits 2" {
    run "$ROUTE"
    [ "$status" -eq 2 ]
}

@test "no run-lock present exits non-zero" {
    write_subagent_record plan false
    rm -f "$FEATURE/.run/run-lock"
    run "$ROUTE" "$FEATURE" from=plan to=tasks reason=n/a
    [ "$status" -ne 0 ]
}

@test "continue verdict without to= exits 2" {
    write_subagent_record plan false
    run "$ROUTE" "$FEATURE" from=plan reason=target-pipeline
    [ "$status" -eq 2 ]
}

@test "continue verdict without reason= exits 2" {
    write_subagent_record plan false
    run "$ROUTE" "$FEATURE" from=plan to=tasks
    [ "$status" -eq 2 ]
}

@test "abort verdict without triggered_by= exits 2" {
    write_subagent_record plan false
    : > "$FEATURE/.run/abort"
    run "$ROUTE" "$FEATURE"
    [ "$status" -eq 2 ]
}
