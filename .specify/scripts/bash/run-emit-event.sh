#!/usr/bin/env bash
# run-emit-event.sh — non-routing sidecar event emitter.
# Handles: stage-start, break-lock, budget-exhausted.
# Routing decisions (route, stage-skip, abort) moved to run-route.sh (ADR-022 rev.1).
#
# Source of truth:
#   contracts/sidecar-event.md (wire format, required fields per event type)
#   contracts/helper-contracts.md §run-emit-event.sh
#
# Usage:
#   run-emit-event.sh <feature-dir> <event-name> [key=value]...
#
# Exit codes:
#   0 — JSONL line appended to sidecar.
#   2 — usage error, unknown event, or missing required field.

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/run-common.sh"

usage() {
    echo "usage: run-emit-event.sh <feature-dir> <event-name> [key=value]..." >&2
    exit 2
}

[[ $# -ge 2 ]] || usage
feature_dir="$1"; shift
event_name="$1"; shift
[[ -d "$feature_dir" ]] || { echo "ERROR: feature-dir not found: $feature_dir" >&2; exit 2; }

case "$event_name" in
    stage-start|break-lock|budget-exhausted) ;;
    *) echo "ERROR: unknown event '$event_name' (routing events handled by run-route.sh)" >&2; exit 2 ;;
esac

run_dir="$(_run_lock_dir "$feature_dir")"
sidecar="$run_dir/control-flow.log"

run_id="$(_run_id_of_lock "$feature_dir")" || exit 2

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
require() {
    local k v
    for k in "$@"; do
        if ! has_arg "$k"; then
            echo "ERROR: event '$event_name' requires field '$k'" >&2; exit 2
        fi
        v="$(get_arg "$k")"
        if [[ -z "$v" ]]; then
            echo "ERROR: event '$event_name' field '$k' must be non-empty" >&2; exit 2
        fi
    done
}

case "$event_name" in
    stage-start)      require stage ;;
    break-lock)       require prior_session prior_ts ;;
    budget-exhausted) require tier tokens ;;
esac

ts="$(_utc_now)"
mkdir -p "$run_dir" || { echo "ERROR: cannot create $run_dir" >&2; exit 2; }

# ----- build JSON line -----
jq_args=(-cn --arg ts "$ts" --arg event "$event_name" --arg run_id "$run_id")
filter='{ts:$ts, event:$event, run_id:$run_id'
for i in "${!KEYS[@]}"; do
    jq_args+=(--arg "k$i" "${KEYS[$i]}" --arg "v$i" "${VALS[$i]}")
    filter+=", (\$k$i): \$v$i"
done
filter+='}'

json_line="$(jq "${jq_args[@]}" "$filter")" || { echo "ERROR: failed to build JSON line" >&2; exit 2; }

# ----- append (truncation-tolerant per ADR-020) -----
prefix=""
if [[ -s "$sidecar" ]]; then
    if [[ "$(tail -c 1 "$sidecar"; printf x)" != $'\nx' ]]; then
        prefix=$'\n'
    fi
fi
printf '%s%s\n' "$prefix" "$json_line" >> "$sidecar" || { echo "ERROR: append to $sidecar failed" >&2; exit 2; }

exit 0
