#!/usr/bin/env bats

# T014 — run-decide-next.sh: ADR-019 routing core + ADR-022 verdict-receipt mint.
# Source of truth:
#   contracts/helper-contracts.md §run-decide-next.sh
#   ADR-019 (deterministic core), ADR-022 (verdict-receipt protocol)
#   data-model.md §E-7 (routing matrix)
#   FR-021 (multi-blocker), FR-023 (resume-scan), FR-025 (below-threshold-continue)

setup() {
    REPO_ROOT_FIXTURE="$(mktemp -d)"
    cd "$REPO_ROOT_FIXTURE"
    mkdir -p .specify/scripts/bash specs/001-foo
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-common.sh"  .specify/scripts/bash/
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-lock.sh"    .specify/scripts/bash/
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-decide-next.sh" .specify/scripts/bash/ 2>/dev/null || true
    DECIDE=".specify/scripts/bash/run-decide-next.sh"
    LOCK=".specify/scripts/bash/run-lock.sh"
    FEATURE="$REPO_ROOT_FIXTURE/specs/001-foo"
    LOG="$FEATURE/decisions-log.md"
    RECEIPT="$FEATURE/.run/last-verdict"
    # Acquire a real lock so .run/ exists with a run_id receipt can reference.
    "$LOCK" acquire "$FEATURE"
    RUN_ID="$(grep -E '^run_id=' "$FEATURE/.run/run-lock" | cut -d= -f2-)"
}

teardown() {
    rm -rf "$REPO_ROOT_FIXTURE"
}

# ----- helpers -----

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

# write_orchestrator_entry <entry_type> <stage> [reason]
# Used to seed verdict-mismatch / verdict-omitted / pipeline-incomplete entries
# that the resume-scan filter MUST skip (FR-023, RC-5).
write_orchestrator_entry() {
    local etype="$1" stage="$2" reason="${3:-orchestrator-authored canonical exception}"
    cat >> "$LOG" <<EOF
## $etype:$stage · 2026-04-26T20:15:00Z

- author: orchestrator
- status: halt
- run_id: $RUN_ID

$reason

EOF
}

# ----- continue path -----

@test "continue: latest entry is success subagent-record with halt=false" {
    write_subagent_record plan false
    run "$DECIDE" "$FEATURE"
    [ "$status" -eq 0 ]
    [ "$output" = "continue" ]
}

@test "continue mints receipt with 4 tab-separated fields (verdict, run_id, input_hash, ts)" {
    write_subagent_record plan false
    "$DECIDE" "$FEATURE"
    [ -s "$RECEIPT" ]
    line="$(cat "$RECEIPT")"
    # Count tabs: tr -cd '\t' | wc -c → 3 tabs for 4 fields.
    tabs="$(printf '%s' "$line" | tr -cd '\t' | wc -c | tr -d ' ')"
    [ "$tabs" = "3" ]
    # Field 1 = verdict.
    verdict="$(printf '%s' "$line" | cut -f1)"
    [ "$verdict" = "continue" ]
    # Field 2 = run_id.
    rid="$(printf '%s' "$line" | cut -f2)"
    [ "$rid" = "$RUN_ID" ]
    # Field 3 = input_hash (non-empty).
    h="$(printf '%s' "$line" | cut -f3)"
    [ -n "$h" ]
    # Field 4 = ISO-8601 UTC ts.
    ts="$(printf '%s' "$line" | cut -f4)"
    [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

# ----- halt routing matrix -----

@test "halt:subagent-halt-directive when subagent emits halt with that reason" {
    write_subagent_record plan true "subagent-halt-directive" semantic
    run "$DECIDE" "$FEATURE"
    [ "$status" -eq 0 ]
    [ "$output" = "halt:subagent-halt-directive" ]
}

@test "halt:schema-violation reason flows through" {
    write_subagent_record plan true "schema-violation" semantic
    run "$DECIDE" "$FEATURE"
    [ "$status" -eq 0 ]
    [ "$output" = "halt:schema-violation" ]
}

@test "halt:code-gate-blocking (ADR-014) reason flows through" {
    write_subagent_record implement true "code-gate-blocking" permission
    run "$DECIDE" "$FEATURE"
    [ "$status" -eq 0 ]
    [ "$output" = "halt:code-gate-blocking" ]
}

@test "halt:multi-blocker-collected (FR-021) on review stage with that aggregated reason" {
    write_subagent_record review true "multi-blocker-collected" semantic
    run "$DECIDE" "$FEATURE"
    [ "$status" -eq 0 ]
    [ "$output" = "halt:multi-blocker-collected" ]
}

@test "halt:postcheck-failed (ADR-023) reason flows through" {
    write_subagent_record codereview true "postcheck-failed" semantic
    run "$DECIDE" "$FEATURE"
    [ "$status" -eq 0 ]
    [ "$output" = "halt:postcheck-failed" ]
}

@test "halt verdict is recorded verbatim in receipt (full halt:<reason>)" {
    write_subagent_record plan true "subagent-halt-directive" semantic
    "$DECIDE" "$FEATURE"
    verdict="$(cut -f1 "$RECEIPT")"
    [ "$verdict" = "halt:subagent-halt-directive" ]
}

# ----- below-threshold-continue (FR-025) -----

@test "below-threshold continue: review subagent without halt directive ⇒ continue" {
    # FR-025: review records may carry findings without halt_directive.halt=true;
    # decide-next outputs `continue`, findings remain in the subagent record.
    write_subagent_record review false
    run "$DECIDE" "$FEATURE"
    [ "$status" -eq 0 ]
    [ "$output" = "continue" ]
}

# ----- abort sentinel fold-in (ADR-019 b1 / FR-027) -----

@test "abort sentinel detected ⇒ abort verdict before any other routing logic" {
    # Even with a halt-true subagent record, abort takes precedence.
    write_subagent_record plan true "subagent-halt-directive" semantic
    : > "$FEATURE/.run/abort"
    run "$DECIDE" "$FEATURE"
    [ "$status" -eq 0 ]
    [ "$output" = "abort" ]
}

@test "abort verdict mints receipt normally (gated by receipt protocol like every other route)" {
    write_subagent_record plan false
    : > "$FEATURE/.run/abort"
    "$DECIDE" "$FEATURE"
    [ -s "$RECEIPT" ]
    [ "$(cut -f1 "$RECEIPT")" = "abort" ]
}

# ----- pre-flight omission check (ADR-022 step 5) -----

@test "pre-flight omission: non-empty receipt refuses to mint, exits 1" {
    write_subagent_record plan false
    printf 'continue\t%s\toldhash\t2026-04-26T19:00:00Z' "$RUN_ID" > "$RECEIPT"
    prior_size="$(wc -c < "$RECEIPT" | tr -d ' ')"
    run "$DECIDE" "$FEATURE"
    [ "$status" -eq 1 ]
    # Original receipt preserved (no fresh mint).
    new_size="$(wc -c < "$RECEIPT" | tr -d ' ')"
    [ "$new_size" = "$prior_size" ]
}

@test "pre-flight omission: writes verdict-omitted canonical entry to decisions-log.md" {
    write_subagent_record plan false
    printf 'continue\t%s\toldhash\t2026-04-26T19:00:00Z' "$RUN_ID" > "$RECEIPT"
    "$DECIDE" "$FEATURE" || true
    grep -qE '^## verdict-omitted:' "$LOG"
}

@test "pre-flight omission: no fresh verdict written even when sentinel present" {
    write_subagent_record plan false
    : > "$FEATURE/.run/abort"
    printf 'continue\t%s\toldhash\t2026-04-26T19:00:00Z' "$RUN_ID" > "$RECEIPT"
    run "$DECIDE" "$FEATURE"
    [ "$status" -eq 1 ]
    # Receipt unchanged — original 'continue' verdict still present, not 'abort'.
    [ "$(cut -f1 "$RECEIPT")" = "continue" ]
}

# ----- resume-scan filter (FR-023, RC-5) -----

@test "resume-scan skips verdict-mismatch as resume anchor" {
    # Latest stage record is a successful plan; a verdict-mismatch entry was
    # appended afterward by run-emit-event.sh on a refused emission. The
    # resume-scan MUST skip the mismatch record and route from the plan record.
    write_subagent_record plan false
    write_orchestrator_entry verdict-mismatch plan
    run "$DECIDE" "$FEATURE"
    [ "$status" -eq 0 ]
    [ "$output" = "continue" ]
}

@test "resume-scan skips verdict-omitted as resume anchor" {
    write_subagent_record plan false
    write_orchestrator_entry verdict-omitted plan
    run "$DECIDE" "$FEATURE"
    [ "$status" -eq 0 ]
    [ "$output" = "continue" ]
}

@test "resume-scan skips pipeline-incomplete as resume anchor" {
    # If the prior run terminated with pipeline-incomplete, that entry is
    # bookkeeping — not a routing anchor. Without the filter, --resume would
    # land on the wrong stage (Re-Review #2 RC-5).
    write_subagent_record plan false
    write_orchestrator_entry pipeline-incomplete plan
    run "$DECIDE" "$FEATURE"
    [ "$status" -eq 0 ]
    [ "$output" = "continue" ]
}

# ----- malformed / missing log -----

@test "missing decisions-log.md exits 1 (semantic failure per FR-019)" {
    [ ! -f "$LOG" ]
    run "$DECIDE" "$FEATURE"
    [ "$status" -eq 1 ]
}

@test "empty decisions-log.md exits 1 (no resume anchor)" {
    : > "$LOG"
    run "$DECIDE" "$FEATURE"
    [ "$status" -eq 1 ]
}

# ----- usage errors -----

@test "missing feature-dir arg exits 2" {
    run "$DECIDE"
    [ "$status" -eq 2 ]
}

@test "feature-dir without active run-lock exits non-zero" {
    write_subagent_record plan false
    rm -f "$FEATURE/.run/run-lock"
    run "$DECIDE" "$FEATURE"
    [ "$status" -ne 0 ]
}
