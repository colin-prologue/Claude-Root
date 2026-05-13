#!/usr/bin/env bash
# run-serialize.sh — ADR-016 MUST-coalesce: append coalesced summary to
# decisions-log.md at run termination.
#
# Pipeline-completeness invariant removed (ADR-022 rev.1 — receipt protocol
# eliminated; single-helper run-route.sh makes the receipt-vs-termination
# and stage-coverage checks vacuous).
#
# Source of truth:
#   contracts/helper-contracts.md §run-serialize.sh
#   ADR-016 (canonical/derivative model)
#
# Usage:
#   run-serialize.sh <feature-dir> <termination-kind>
#
# <termination-kind> ∈ {clean, halt, abort, permission-failure}
#
# Exit codes:
#   0 — coalesced summary appended; canonical log in consistent state.
#   1 — write failed or sidecar unparseable.
#   2 — usage error.

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/run-common.sh"

usage() {
    echo "usage: run-serialize.sh <feature-dir> <termination-kind>" >&2
    echo "       termination-kind ∈ {clean, halt, abort, permission-failure}" >&2
    exit 2
}

[[ $# -eq 2 ]] || usage
feature_dir="$1"
termination_kind="$2"
[[ -d "$feature_dir" ]] || { echo "ERROR: feature-dir not found: $feature_dir" >&2; exit 2; }

case "$termination_kind" in
    clean|halt|abort|permission-failure) ;;
    *) usage ;;
esac

run_dir="$(_run_lock_dir "$feature_dir")"
sidecar="$run_dir/control-flow.log"

run_id="$(_run_id_of_lock "$feature_dir" 2>/dev/null || echo "no-run")"

# ----- parse sidecar JSONL (truncation-tolerant per ADR-020) -----
declare -a EVENTS=()
parse_sidecar() {
    [[ -f "$sidecar" && -s "$sidecar" ]] || return 0
    if ! command -v jq >/dev/null 2>&1; then
        echo "ERROR: jq required to parse sidecar at $sidecar" >&2
        return 2
    fi
    local total has_trailing_nl i=0 line
    total="$(wc -l < "$sidecar" | tr -d ' ')"
    has_trailing_nl=0
    if [[ "$(tail -c 1 "$sidecar"; printf x)" == $'\nx' ]]; then
        has_trailing_nl=1
    fi
    while IFS= read -r line; do
        i=$((i + 1))
        if (( has_trailing_nl == 0 && i == total )); then
            continue
        fi
        [[ -z "$line" ]] && continue
        if ! printf '%s\n' "$line" | jq -e . >/dev/null 2>&1; then
            echo "ERROR: sidecar line $i not valid JSON: $line" >&2
            return 1
        fi
        EVENTS+=("$line")
    done < "$sidecar"
    return 0
}

parse_sidecar
parse_status=$?
if (( parse_status != 0 )); then
    exit "$parse_status"
fi

# ----- emit coalesced summary -----
ts="$(_utc_now)"
event_count="${#EVENTS[@]}"
{
    printf '\n## stage-end:run · %s\n\n' "$ts"
    printf -- '- author: orchestrator\n'
    case "$termination_kind" in
        clean) printf -- '- status: success\n' ;;
        *)     printf -- '- status: halt\n' ;;
    esac
    printf -- '- run_id: %s\n\n' "$run_id"
    printf 'Run terminated with kind=%s. Sidecar events coalesced: %d.\n\n' \
        "$termination_kind" "$event_count"
    if (( event_count > 0 )); then
        printf '### sidecar_events\n\n'
        (( ${#EVENTS[@]} > 0 )) && for line in "${EVENTS[@]}"; do
            printf -- '- %s\n' "$line"
        done
        printf '\n'
    fi
} | _emit_canonical_entry "$feature_dir" || {
    echo "ERROR: failed to write coalesced summary" >&2
    exit 1
}

exit 0
