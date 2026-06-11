#!/usr/bin/env bats

# Tier 2 smoke — ADR-021 Fixture 1: green path (specify→plan).
#
# Prerequisites (manual — run before invoking this file):
#   1. In Claude Code, invoke:
#        /speckit.run --target specify→plan
#      using tests/smoke/fixtures/feature-min-path.txt as the feature description.
#   2. Export SMOKE_FEATURE_DIR=<path to the feature directory used in step 1>.
#
# Per-run token cap: 50,000 tokens (ADR-021).
# Token cost is read from $SMOKE_FEATURE_DIR/.run/token-cost.txt if present.
# Format: a single integer (total input+output tokens for the run).
#
# Per-merge cap enforcement is handled by summing costs across both smoke
# fixture files; see fixture_halt_on_specify.bats for the combined cap check.

PER_RUN_TOKEN_CAP=50000

# Skip all tests when SMOKE_FEATURE_DIR is not set (not a smoke environment).
setup() {
    if [[ -z "${SMOKE_FEATURE_DIR:-}" ]]; then
        skip "SMOKE_FEATURE_DIR not set — run /speckit.run on fixture-min-path first"
    fi
    [[ -d "$SMOKE_FEATURE_DIR" ]] || skip "SMOKE_FEATURE_DIR=$SMOKE_FEATURE_DIR not found"
    LOG="$SMOKE_FEATURE_DIR/decisions-log.md"
    SIDECAR="$SMOKE_FEATURE_DIR/.run/control-flow.log"
    COST_FILE="$SMOKE_FEATURE_DIR/.run/token-cost.txt"
}

# ----- artifact existence -----

@test "Fixture 1: spec.md produced by specify subagent" {
    [ -f "$SMOKE_FEATURE_DIR/spec.md" ]
}

@test "Fixture 1: plan.md produced by plan subagent" {
    [ -f "$SMOKE_FEATURE_DIR/plan.md" ]
}

@test "Fixture 1: decisions-log.md present (ADR-013 subagent-direct-write)" {
    [ -f "$LOG" ]
}

# ----- canonical-log conformance (FR-006 schema) -----

@test "Fixture 1: decisions-log.md contains a subagent-record:specify entry" {
    grep -q '^## subagent-record:specify' "$LOG"
}

@test "Fixture 1: specify entry has halt: false (green path)" {
    # Locate the specify record and check its halt_directive block
    awk '
        /^## subagent-record:specify/ { in_rec=1; next }
        in_rec && /^## / { in_rec=0 }
        in_rec && /^### halt_directive/ { in_hd=1; next }
        in_hd && /^### / { in_hd=0 }
        in_hd && /^- halt: false/ { found=1 }
        END { exit (found ? 0 : 1) }
    ' "$LOG"
}

@test "Fixture 1: decisions-log.md contains a subagent-record:plan entry" {
    grep -q '^## subagent-record:plan' "$LOG"
}

@test "Fixture 1: coalesced summary (stage-end:run) present at tail per ADR-016 MUST-coalesce" {
    grep -q '^## stage-end:run' "$LOG"
    # stage-end:run must be the last level-2 heading
    last_heading="$(grep -E '^## ' "$LOG" | tail -1)"
    [[ "$last_heading" == "## stage-end:run"* ]]
}

# ----- sidecar-canonical reconciliation (ADR-016) -----

@test "Fixture 1: sidecar (.run/control-flow.log) present and non-empty" {
    [ -f "$SIDECAR" ] && [ -s "$SIDECAR" ]
}

@test "Fixture 1: sidecar contains a route event (specify→plan transition recorded)" {
    grep -q '"event":"route"' "$SIDECAR"
}

@test "Fixture 1: sidecar events are valid JSONL (each line parses)" {
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        printf '%s\n' "$line" | jq -e . >/dev/null 2>&1
    done < "$SIDECAR"
}

# ----- token-cost cap (ADR-021) -----

@test "Fixture 1: per-run token cost under ${PER_RUN_TOKEN_CAP} (ADR-021)" {
    if [[ ! -f "$COST_FILE" ]]; then
        skip "token-cost.txt absent — cap check skipped (write cost to $COST_FILE to enforce)"
    fi
    cost="$(cat "$COST_FILE" | tr -d '[:space:]')"
    [[ "$cost" =~ ^[0-9]+$ ]] || { echo "token-cost.txt must contain a single integer"; return 1; }
    (( cost <= PER_RUN_TOKEN_CAP ))
}
