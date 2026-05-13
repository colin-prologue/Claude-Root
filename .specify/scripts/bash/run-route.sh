#!/usr/bin/env bash
# run-route.sh — atomic routing: read log, decide verdict, emit sidecar event.
# ADR-019 routing core + ADR-022 rev.1 (single-helper; no verdict-receipt).
#
# Source of truth:
#   contracts/helper-contracts.md §run-route.sh
#   ADR-019 (deterministic core), ADR-022 rev.1 (single-helper routing)
#   data-model.md §E-7 (routing matrix)
#
# Usage:
#   run-route.sh <feature-dir> [key=value]...
#
# Required key=value by verdict:
#   continue: from=<stage>  to=<stage>  reason=<text>
#   skip:X:   stage=<stage> criterion=<text>
#   abort:    triggered_by=<text>
#   halt:X:   (no required fields — halt info lives in subagent canonical log)
#
# Outputs (stdout): continue | halt:<reason> | skip:<stage> | abort
#
# Exit codes:
#   0 — routing action completed (event emitted for continue/skip/abort;
#       nothing emitted for halt but verdict on stdout)
#   1 — semantic failure (log unreadable, no routable anchor)
#   2 — usage error (missing args, missing required key=value for verdict)

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/run-common.sh"

usage() {
    echo "usage: run-route.sh <feature-dir> [key=value]..." >&2
    exit 2
}

[[ $# -ge 1 ]] || usage
feature_dir="$1"; shift
[[ -d "$feature_dir" ]] || { echo "ERROR: feature-dir not found: $feature_dir" >&2; exit 2; }

run_dir="$(_run_lock_dir "$feature_dir")"
log="$feature_dir/decisions-log.md"
sidecar="$run_dir/control-flow.log"
abort_sentinel="$run_dir/abort"

run_id="$(_run_id_of_lock "$feature_dir")" || exit 1

# ----- parse key=value args -----
declare -a KEYS=() VALS=()
for kv in "$@"; do
    [[ "$kv" == *=* ]] || { echo "ERROR: arg '$kv' not in key=value form" >&2; exit 2; }
    KEYS+=("${kv%%=*}")
    VALS+=("${kv#*=}")
done

get_arg() {
    local k="$1" i
    for i in "${!KEYS[@]}"; do
        [[ "${KEYS[$i]}" == "$k" ]] && { printf '%s' "${VALS[$i]}"; return 0; }
    done
    return 1
}
has_arg() {
    local k="$1" i
    for i in "${!KEYS[@]}"; do
        [[ "${KEYS[$i]}" == "$k" ]] && return 0
    done
    return 1
}
require_arg() {
    local k="$1" v
    if ! has_arg "$k"; then
        echo "ERROR: missing required field '$k' for this routing verdict" >&2
        exit 2
    fi
    v="$(get_arg "$k")"
    if [[ -z "$v" ]]; then
        echo "ERROR: field '$k' must be non-empty for this routing verdict" >&2
        exit 2
    fi
}

# ----- derive verdict -----
verdict=""

if [[ -e "$abort_sentinel" ]]; then
    verdict="abort"
else
    anchor="$(_latest_routable_anchor "$feature_dir")" || {
        echo "ERROR: decisions-log.md has no routable entry" >&2
        exit 1
    }
    entry_type="${anchor%%:*}"
    rest="${anchor#*:}"
    stage="${rest%%:*}"
    latest_lineno="${rest##*:}"

    case "$entry_type" in
        subagent-record)
            slice="$(tail -n +"$latest_lineno" "$log" | awk '
                NR == 1 { print; next }
                /^## / { exit }
                { print }
            ')"
            hd_block="$(printf '%s\n' "$slice" | awk '
                /^### halt_directive$/ { collecting=1; next }
                collecting && /^### / { exit }
                collecting { print }
            ')"
            halt_val="$(printf '%s\n' "$hd_block" | awk '/^- halt:/ { sub(/^- halt:[ ]*/,"",$0); print; exit }')"
            if [[ "$halt_val" == "true" ]]; then
                reason="$(printf '%s\n' "$hd_block" | awk '/^- reason:/ { sub(/^- reason:[ ]*/,"",$0); print; exit }')"
                if [[ -z "$reason" ]]; then
                    verdict="halt:unspecified"
                else
                    verdict="halt:$reason"
                fi
            else
                verdict="continue"
            fi
            ;;
        abort)       verdict="abort" ;;
        stage-skip)  verdict="skip:$stage" ;;
        *)           verdict="continue" ;;
    esac
fi

# ----- validate required fields for verdict; emit event -----
ts="$(_utc_now)"
mkdir -p "$run_dir"

case "$verdict" in
    continue)
        require_arg to
        require_arg reason
        from="$(get_arg from)"
        to="$(get_arg to)"
        reason_val="$(get_arg reason)"
        jq -cn \
            --arg ts "$ts" --arg event "route" --arg run_id "$run_id" \
            --arg from "$from" --arg to "$to" --arg reason "$reason_val" \
            '{ts:$ts, event:$event, run_id:$run_id, from:$from, to:$to, reason:$reason}' \
            >> "$sidecar" || { echo "ERROR: append to $sidecar failed" >&2; exit 2; }
        ;;
    skip:*)
        skipped="${verdict#skip:}"
        require_arg criterion
        stage_val="$(get_arg stage)"
        [[ -n "$stage_val" ]] || stage_val="$skipped"
        criterion_val="$(get_arg criterion)"
        jq -cn \
            --arg ts "$ts" --arg event "stage-skip" --arg run_id "$run_id" \
            --arg stage "$stage_val" --arg criterion "$criterion_val" \
            '{ts:$ts, event:$event, run_id:$run_id, stage:$stage, criterion:$criterion}' \
            >> "$sidecar" || { echo "ERROR: append to $sidecar failed" >&2; exit 2; }
        ;;
    abort)
        require_arg triggered_by
        triggered_by="$(get_arg triggered_by)"
        jq -cn \
            --arg ts "$ts" --arg event "abort" --arg run_id "$run_id" \
            --arg triggered_by "$triggered_by" \
            '{ts:$ts, event:$event, run_id:$run_id, triggered_by:$triggered_by}' \
            >> "$sidecar" || { echo "ERROR: append to $sidecar failed" >&2; exit 2; }
        ;;
    halt:*)
        # No sidecar event for halt — subagent canonical log is the record.
        ;;
esac

printf '%s\n' "$verdict"
exit 0
