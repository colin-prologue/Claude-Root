#!/usr/bin/env bash
# run-serialize.sh — ADR-016 MUST-coalesce + ADR-022 step-6 invariant.
#
# Source of truth:
#   contracts/helper-contracts.md §run-serialize.sh
#   ADR-016 (canonical/derivative model), ADR-022 step 6 (pipeline completeness)
#
# Usage:
#   run-serialize.sh <feature-dir> <termination-kind>
#
# <termination-kind> ∈ {clean, halt, abort, permission-failure}
#
# Exit codes:
#   0 — coalesced summary appended; canonical log in consistent state.
#   1 — write failed (filesystem error, mv failed, sidecar unparseable past
#       the truncation-tolerance window). Caller MUST proceed to lock release.
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
log="$feature_dir/decisions-log.md"
sidecar="$run_dir/control-flow.log"
receipt="$run_dir/last-verdict"

run_id="$(_run_id_of_lock "$feature_dir" 2>/dev/null || echo "no-run")"

# ----- parse sidecar JSONL (truncation-tolerant per ADR-020) -----
declare -a EVENTS=()
parse_sidecar() {
    [[ -f "$sidecar" && -s "$sidecar" ]] || return 0
    if ! command -v jq >/dev/null 2>&1; then
        echo "ERROR: jq required to parse sidecar at $sidecar" >&2
        return 2
    fi
    local total
    total="$(wc -l < "$sidecar" | tr -d ' ')"
    # If file does not end in newline, the "last line" is partial — readers
    # silently drop it (truncation tolerance). Command substitution strips
    # trailing newlines, so use a sentinel to detect the actual final byte.
    local has_trailing_nl=0
    if [[ "$(tail -c 1 "$sidecar"; printf x)" == $'\nx' ]]; then
        has_trailing_nl=1
    fi

    local i=0 line
    while IFS= read -r line; do
        i=$((i + 1))
        # Drop the trailing partial line silently (i == total when no trailing
        # newline; the partial line is the last one read).
        if (( has_trailing_nl == 0 && i == total )); then
            continue
        fi
        # Empty lines: skip.
        [[ -z "$line" ]] && continue
        # Validate parse; non-last-line failures are fatal.
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

# ----- enumerate subagent-record stages from decisions-log -----
declare -a SUBAGENT_STAGES=()
declare -a SUBAGENT_HALT=()  # parallel array: 1 if halt=true, else 0
if [[ -f "$log" ]]; then
    # Walk the log, collect subagent-record:<stage> headings and their halt flag.
    awk '
        function flush() {
            if (in_record) {
                print current_stage "\t" halt
            }
            in_record = 0
            in_hd = 0
            halt = 0
            current_stage = ""
        }
        /^## subagent-record:/ {
            flush()
            line = $0
            sub(/^## subagent-record:/, "", line)
            stage = line
            sub(/[ ·-].*$/, "", stage)
            current_stage = stage
            in_record = 1
            next
        }
        /^## / {
            flush()
            next
        }
        in_record && /^### halt_directive$/ {
            in_hd = 1
            next
        }
        in_record && in_hd && /^### / {
            in_hd = 0
        }
        in_record && in_hd && /^- halt:[[:space:]]*true/ {
            halt = 1
        }
        END {
            flush()
        }
    ' "$log" > "$run_dir/.serialize.stages.tmp" 2>/dev/null || true

    if [[ -s "$run_dir/.serialize.stages.tmp" ]]; then
        while IFS=$'\t' read -r stage halt_flag; do
            SUBAGENT_STAGES+=("$stage")
            SUBAGENT_HALT+=("${halt_flag:-0}")
        done < "$run_dir/.serialize.stages.tmp"
    fi
    rm -f "$run_dir/.serialize.stages.tmp"
fi

# ----- enumerate covered stages from sidecar route events -----
declare -a COVERED_STAGES=()
if (( ${#EVENTS[@]} > 0 )); then
    for line in "${EVENTS[@]}"; do
        [[ -z "$line" ]] && continue
        et="$(printf '%s' "$line" | jq -r '.event // empty')"
        case "$et" in
            route)
                from="$(printf '%s' "$line" | jq -r '.from // empty')"
                [[ -n "$from" ]] && COVERED_STAGES+=("$from")
                ;;
        esac
    done
fi

is_covered() {
    local needle="$1" s
    (( ${#COVERED_STAGES[@]} > 0 )) || return 1
    for s in "${COVERED_STAGES[@]}"; do
        [[ "$s" == "$needle" ]] && return 0
    done
    return 1
}

# ----- invariant (a): receipt vs termination_kind -----
verdict_in_receipt=""
if [[ -s "$receipt" ]]; then
    verdict_in_receipt="$(cut -f1 < "$receipt")"
fi

receipt_ok_for_kind() {
    case "$verdict_in_receipt" in
        "")            return 0 ;;
        halt:*)
            case "$termination_kind" in
                halt|abort|permission-failure) return 0 ;;
                clean) return 1 ;;
            esac
            ;;
        abort)
            [[ "$termination_kind" == "abort" ]] && return 0
            return 1
            ;;
        continue|skip:*) return 1 ;;
        *)               return 1 ;;
    esac
}

# ----- invariant (b): subagent-record stages without route coverage -----
declare -a MISSING_STAGES=()
if (( ${#SUBAGENT_STAGES[@]} > 0 )); then
    last_idx=$(( ${#SUBAGENT_STAGES[@]} - 1 ))
    for i in "${!SUBAGENT_STAGES[@]}"; do
        s="${SUBAGENT_STAGES[$i]}"
        halt_flag="${SUBAGENT_HALT[$i]}"
        if is_covered "$s"; then
            continue
        fi
        # Last-halt-exemption for non-clean termination: if this is the last
        # subagent-record AND it carries halt=true AND termination is non-clean,
        # the run terminated on this stage — no route from=stage is expected.
        if (( i == last_idx )) && [[ "$halt_flag" == "1" ]] && [[ "$termination_kind" != "clean" ]]; then
            continue
        fi
        MISSING_STAGES+=("$s")
    done
fi

# ----- emit pipeline-incomplete (if any invariant violated) -----
declare -a violations=()
if ! receipt_ok_for_kind; then
    violations+=("receipt verdict '$verdict_in_receipt' not consumed at termination_kind='$termination_kind'")
fi
if (( ${#MISSING_STAGES[@]} > 0 )); then
    violations+=("missing routing event for stages: ${MISSING_STAGES[*]}")
fi

ts="$(_utc_now)"

if (( ${#violations[@]} > 0 )); then
    {
        printf '\n## pipeline-incomplete:orchestrator · %s\n\n' "$ts"
        printf -- '- author: orchestrator\n'
        printf -- '- status: halt\n'
        printf -- '- run_id: %s\n\n' "$run_id"
        printf 'Pipeline completeness invariant violated at termination (ADR-022 step 6).\n\n'
        for v in "${violations[@]}"; do
            printf -- '- %s\n' "$v"
        done
        printf '\n'
    } | _emit_canonical_entry "$feature_dir" || {
        echo "ERROR: failed to write pipeline-incomplete entry" >&2
        exit 1
    }
fi

# ----- emit coalesced summary -----
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
        for line in "${EVENTS[@]}"; do
            printf -- '- %s\n' "$line"
        done
        printf '\n'
    fi
} | _emit_canonical_entry "$feature_dir" || {
    echo "ERROR: failed to write coalesced summary" >&2
    exit 1
}

exit 0
