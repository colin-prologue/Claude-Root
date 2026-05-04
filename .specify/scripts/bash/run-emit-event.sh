#!/usr/bin/env bash
# run-emit-event.sh — ADR-020 sidecar JSONL emitter + ADR-022 receipt validation.
#
# Source of truth:
#   contracts/sidecar-event.md  (wire format, required fields per event type)
#   contracts/helper-contracts.md §run-emit-event.sh
#   ADR-022 (verdict-receipt enforcement)
#
# Usage:
#   run-emit-event.sh <feature-dir> <event-name> [key=value]...
#
# Exit codes:
#   0 — JSONL line appended; receipt consumed if applicable.
#   1 — verdict-receipt mismatch or missing; verdict-mismatch canonical entry
#       written; orchestrator MUST halt.
#   2 — usage error or filesystem error.

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
    stage-start|stage-skip|route|abort|break-lock|budget-exhausted) ;;
    *) echo "ERROR: unknown event '$event_name'" >&2; exit 2 ;;
esac

run_dir="$(_run_lock_dir "$feature_dir")"
sidecar="$run_dir/control-flow.log"
receipt="$run_dir/last-verdict"

run_id="$(_run_id_of_lock "$feature_dir")" || exit 2

# ----- parse key=value args -----
declare -a KEYS=() VALS=()
for kv in "$@"; do
    [[ "$kv" == *=* ]] || { echo "ERROR: arg '$kv' not in key=value form" >&2; exit 2; }
    KEYS+=("${kv%%=*}")
    VALS+=("${kv#*=}")
done

get_arg() {
    # $1 = key; print value or empty.
    local k="$1" i
    for i in "${!KEYS[@]}"; do
        if [[ "${KEYS[$i]}" == "$k" ]]; then
            printf '%s' "${VALS[$i]}"
            return 0
        fi
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

# ----- required-field check per event type (sidecar-event.md) -----
require() {
    local k v
    for k in "$@"; do
        if ! has_arg "$k"; then
            echo "ERROR: event '$event_name' requires field '$k'" >&2
            exit 2
        fi
        v="$(get_arg "$k")"
        if [[ -z "$v" ]]; then
            echo "ERROR: event '$event_name' field '$k' must be non-empty" >&2
            exit 2
        fi
    done
}

case "$event_name" in
    stage-start)      require stage ;;
    stage-skip)       require stage criterion ;;
    route)            require from to reason ;;
    abort)            require triggered_by ;;
    break-lock)       require prior_session prior_ts ;;
    budget-exhausted) require tier tokens ;;
esac

# ----- verdict-receipt enforcement (ADR-022) — routing-decision set only -----
is_routing_decision=0
case "$event_name" in
    route|stage-skip|abort) is_routing_decision=1 ;;
esac

write_verdict_mismatch() {
    # $1 = diagnostic
    local diag="$1"
    local ts="$(_utc_now)"
    cat <<EOF | _emit_canonical_entry "$feature_dir"

## verdict-mismatch:orchestrator · $ts

- author: orchestrator
- status: halt
- run_id: $run_id

run-emit-event.sh refused to emit a $event_name event because the verdict
receipt did not validate (ADR-022). Diagnostic: $diag

EOF
    echo "ERROR: $diag" >&2
}

if (( is_routing_decision )); then
    if [[ ! -s "$receipt" ]]; then
        write_verdict_mismatch "missing or empty .run/last-verdict (no fresh verdict from run-decide-next.sh)"
        exit 1
    fi
    line="$(cat "$receipt")"
    r_verdict="$(printf '%s' "$line" | cut -f1)"
    r_runid="$(printf '%s' "$line" | cut -f2)"
    r_hash="$(printf '%s' "$line" | cut -f3)"

    if [[ "$r_runid" != "$run_id" ]]; then
        write_verdict_mismatch "receipt run_id '$r_runid' does not match active lock '$run_id'"
        exit 1
    fi

    # Verdict↔event-type mapping (V1 routing-decision set: route, stage-skip,
    # abort; halt-* deferred to V2 — LOG-025).
    case "$r_verdict" in
        continue)
            if [[ "$event_name" != "route" ]]; then
                write_verdict_mismatch "verdict 'continue' requires event='route' (got '$event_name')"
                exit 1
            fi
            ;;
        abort)
            if [[ "$event_name" != "abort" ]]; then
                write_verdict_mismatch "verdict 'abort' requires event='abort' (got '$event_name')"
                exit 1
            fi
            ;;
        skip:*)
            skipped_stage="${r_verdict#skip:}"
            if [[ "$event_name" != "stage-skip" ]]; then
                write_verdict_mismatch "verdict '$r_verdict' requires event='stage-skip' (got '$event_name')"
                exit 1
            fi
            evt_stage="$(get_arg stage)"
            if [[ "$evt_stage" != "$skipped_stage" ]]; then
                write_verdict_mismatch "verdict '$r_verdict' requires stage='$skipped_stage' (got '$evt_stage')"
                exit 1
            fi
            ;;
        halt:*)
            # Reserved for V2 — V1 records halt via decisions-log canonical path
            # (subagent-record halt_directive + run-serialize coalesce). LOG-025.
            write_verdict_mismatch "verdict '$r_verdict' has no V1 sidecar event (halt-* deferred to V2; see LOG-025)"
            exit 1
            ;;
        *)
            write_verdict_mismatch "unrecognized verdict '$r_verdict'"
            exit 1
            ;;
    esac

    # input_hash check — recompute from current log state and compare. The
    # shared _latest_routable_anchor recipe guarantees decide-next and emit-event
    # see the same input under single-writer-at-a-time semantics (ADR-016).
    cur_anchor="$(_latest_routable_anchor "$feature_dir")" || {
        write_verdict_mismatch "decisions-log.md no longer has a routable anchor"
        exit 1
    }
    cur_hash="$(_hash_input "$cur_anchor")"
    if [[ "$cur_hash" != "$r_hash" ]]; then
        write_verdict_mismatch "input_hash mismatch: receipt '$r_hash' vs current '$cur_hash'"
        exit 1
    fi
fi

# ----- build JSON line + append + (if routing) consume receipt -----
ts="$(_utc_now)"
mkdir -p "$run_dir" || { echo "ERROR: cannot create $run_dir" >&2; exit 2; }

build_json() {
    # Build {ts, event, run_id, ...kv} via jq -cn; printf fallback if no jq.
    if command -v jq >/dev/null 2>&1; then
        local jq_args=(-cn --arg ts "$ts" --arg event "$event_name" --arg run_id "$run_id")
        local filter='{ts:$ts, event:$event, run_id:$run_id'
        local i
        for i in "${!KEYS[@]}"; do
            jq_args+=(--arg "k$i" "${KEYS[$i]}" --arg "v$i" "${VALS[$i]}")
            filter+=", (\$k$i): \$v$i"
        done
        filter+='}'
        jq "${jq_args[@]}" "$filter"
    else
        # Minimal printf fallback. Quotes embedded backslash and double-quote
        # in values; sufficient for V1 smoke fixtures (LOG-009 budgets the
        # JSON surface narrow enough that `jq` should always be available).
        local out="{\"ts\":\"$ts\",\"event\":\"$event_name\",\"run_id\":\"$run_id\""
        local i k v
        for i in "${!KEYS[@]}"; do
            k="${KEYS[$i]}"
            v="${VALS[$i]//\\/\\\\}"
            v="${v//\"/\\\"}"
            out+=",\"$k\":\"$v\""
        done
        out+='}'
        printf '%s' "$out"
    fi
}

json_line="$(build_json)" || { echo "ERROR: failed to build JSON line" >&2; exit 2; }

# Ensure prior file (if any) ends in a newline before appending. Truncation
# tolerance per ADR-020: readers drop the last malformed line silently; the
# writer MUST NOT corrupt prior content. If the existing file does not end
# in `\n`, prepend one to our line so the new entry parses cleanly.
prefix=""
if [[ -s "$sidecar" ]]; then
    last_byte="$(tail -c 1 "$sidecar")"
    if [[ "$last_byte" != $'\n' ]]; then
        prefix=$'\n'
    fi
fi

printf '%s%s\n' "$prefix" "$json_line" >> "$sidecar" || {
    echo "ERROR: append to $sidecar failed" >&2
    exit 2
}

# Consume receipt only AFTER successful append (ADR-022 step 3). Reverse
# order would lose the invariant if the append failed.
if (( is_routing_decision )); then
    : > "$receipt" || {
        echo "ERROR: failed to truncate $receipt (event landed; next emit will refuse)" >&2
        exit 2
    }
fi

exit 0
