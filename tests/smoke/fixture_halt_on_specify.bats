#!/usr/bin/env bats

# Tier 2 smoke — ADR-021 Fixture 2: halt path (specify emits halt_directive=true).
#
# Prerequisites (manual — run before invoking this file):
#   1. In Claude Code, invoke:
#        /speckit.run --target specify,plan
#      using tests/smoke/fixtures/feature-halt-on-specify.txt as the feature description.
#   2. Export SMOKE_HALT_FEATURE_DIR=<path to the feature directory used in step 1>.
#
# This fixture verifies:
#   - The specify subagent emits halt_directive=true (deliberate ambiguity in description)
#   - The orchestrator does NOT dispatch the plan stage after halt
#   - ADR-016 MUST-coalesce: coalesced summary appended on halt termination
#   - Token cost within per-run cap (ADR-021)
#
# Per-merge cap: the combined cost of Fixture 1 + Fixture 2 must be ≤ 100,000 tokens.
# Enforcement: this file reads both cost files and checks the combined total.

PER_RUN_TOKEN_CAP=50000
PER_MERGE_TOKEN_CAP=100000

setup() {
    if [[ -z "${SMOKE_HALT_FEATURE_DIR:-}" ]]; then
        skip "SMOKE_HALT_FEATURE_DIR not set — run /speckit.run on fixture-halt-on-specify first"
    fi
    [[ -d "$SMOKE_HALT_FEATURE_DIR" ]] || skip "SMOKE_HALT_FEATURE_DIR=$SMOKE_HALT_FEATURE_DIR not found"
    LOG="$SMOKE_HALT_FEATURE_DIR/decisions-log.md"
    COST_FILE="$SMOKE_HALT_FEATURE_DIR/.run/token-cost.txt"
}

# ----- halt-path artifact assertions -----

@test "Fixture 2: decisions-log.md present (specify ran and wrote its record)" {
    [ -f "$LOG" ]
}

@test "Fixture 2: spec.md present (specify wrote artifact before halting)" {
    # specify may write spec.md even when halting — the halt_directive surfaces after
    # the artifact is written per ADR-013
    [ -f "$SMOKE_HALT_FEATURE_DIR/spec.md" ]
}

@test "Fixture 2: plan.md absent (plan stage never dispatched after halt)" {
    [ ! -f "$SMOKE_HALT_FEATURE_DIR/plan.md" ]
}

# ----- canonical-log conformance on halt path -----

@test "Fixture 2: decisions-log.md contains a subagent-record:specify entry" {
    grep -q '^## subagent-record:specify' "$LOG"
}

@test "Fixture 2: specify entry has halt: true (halt path)" {
    awk '
        /^## subagent-record:specify/ { in_rec=1; next }
        in_rec && /^## / { in_rec=0 }
        in_rec && /^### halt_directive/ { in_hd=1; next }
        in_hd && /^### / { in_hd=0 }
        in_hd && /^- halt: true/ { found=1 }
        END { exit (found ? 0 : 1) }
    ' "$LOG"
}

@test "Fixture 2: coalesced summary (stage-end:run) appended on halt — ADR-016 MUST-coalesce" {
    grep -q '^## stage-end:run' "$LOG"
    last_heading="$(grep -E '^## ' "$LOG" | tail -1)"
    [[ "$last_heading" == "## stage-end:run"* ]]
}

@test "Fixture 2: coalesced summary records termination kind=halt" {
    # stage-end:run entry body should mention 'halt'
    awk '
        /^## stage-end:run/ { in_rec=1; next }
        in_rec && /^## / { exit }
        in_rec && /halt/ { found=1 }
        END { exit (found ? 0 : 1) }
    ' "$LOG"
}

# ----- token-cost cap: per-run (Fixture 2) -----

@test "Fixture 2: per-run token cost under ${PER_RUN_TOKEN_CAP} (ADR-021)" {
    if [[ ! -f "$COST_FILE" ]]; then
        skip "token-cost.txt absent — cap check skipped (write cost to $COST_FILE to enforce)"
    fi
    cost="$(cat "$COST_FILE" | tr -d '[:space:]')"
    [[ "$cost" =~ ^[0-9]+$ ]] || { echo "token-cost.txt must contain a single integer"; return 1; }
    (( cost <= PER_RUN_TOKEN_CAP ))
}

# ----- token-cost cap: per-merge combined (ADR-021) -----

@test "Combined Fixture 1+2 token cost under ${PER_MERGE_TOKEN_CAP} (ADR-021 per-merge cap)" {
    f1_cost_file="${SMOKE_FEATURE_DIR:-}/.run/token-cost.txt"
    f2_cost_file="$COST_FILE"
    if [[ ! -f "$f1_cost_file" || ! -f "$f2_cost_file" ]]; then
        skip "one or both token-cost.txt files absent — per-merge cap check skipped"
    fi
    f1="$(cat "$f1_cost_file" | tr -d '[:space:]')"
    f2="$(cat "$f2_cost_file" | tr -d '[:space:]')"
    [[ "$f1" =~ ^[0-9]+$ && "$f2" =~ ^[0-9]+$ ]] || {
        echo "token-cost.txt files must each contain a single integer"; return 1
    }
    total=$(( f1 + f2 ))
    (( total <= PER_MERGE_TOKEN_CAP ))
}
