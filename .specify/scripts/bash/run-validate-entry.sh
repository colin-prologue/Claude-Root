#!/usr/bin/env bash
# run-validate-entry.sh — FR-006 schema validation for canonical decisions-log entries.
#
# Source of truth: .specify/contracts/decision-log-entry.md §Validation contract.
#
# Usage:
#   run-validate-entry.sh <decisions-log.md> <byte-offset>
#
# Exit codes:
#   0 — entry passes; stdout empty.
#   1 — schema violation; one diagnostic per line on stdout
#       (`field: <name>; problem: <description>`).
#   2 — usage error.

set -uo pipefail

ENTRY_TYPES='stage-start|stage-end|stage-skip|escalate|route|abort|subagent-record'
CANONICAL_STAGES='specify|clarify|plan|tasks|analyze|implement|codereview|audit|review'
TS_RE='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'

usage() {
    echo "usage: run-validate-entry.sh <decisions-log.md> <byte-offset>" >&2
    exit 2
}

die_violation() {
    # $1 = field, $2 = problem
    printf 'field: %s; problem: %s\n' "$1" "$2"
    VIOLATIONS=$((VIOLATIONS + 1))
}

[[ $# -eq 2 ]] || usage
LOG="$1"
OFFSET="$2"
[[ "$OFFSET" =~ ^[0-9]+$ ]] || usage
[[ -f "$LOG" ]] || { echo "ERROR: log not found: $LOG" >&2; exit 2; }

# Slice from OFFSET to the next "\n## " boundary or EOF.
# tail -c +N is 1-indexed (skip N-1 bytes); use offset+1.
SKIP=$((OFFSET + 1))
SLICE="$(tail -c +"$SKIP" "$LOG")" || { echo "ERROR: read failed" >&2; exit 2; }
# Truncate at next "\n## " (start of subsequent entry).
ENTRY="$(printf '%s' "$SLICE" | awk '
    # Skip leading blank lines until the first content line.
    !started && /^[[:space:]]*$/ { next }
    !started { started=1; print; next }
    /^## / { exit }
    { print }
')"

VIOLATIONS=0

# ----- 1. Heading -----
HEADING="$(printf '%s\n' "$ENTRY" | head -n1)"
HEADING_RE="^## (${ENTRY_TYPES}):(${CANONICAL_STAGES}) [·-] ${TS_RE}$"
if [[ ! "$HEADING" =~ $HEADING_RE ]]; then
    die_violation "heading" "does not match required pattern '## <entry_type>:<stage> [·-] <ISO-8601-UTC>': '$HEADING'"
    # If heading is unparseable, downstream field checks are best-effort.
    ENTRY_TYPE=""
    STAGE=""
else
    # Extract entry_type and stage from the matched heading.
    ENTRY_TYPE="${HEADING#\#\# }"
    ENTRY_TYPE="${ENTRY_TYPE%%:*}"
    REST="${HEADING#\#\# *:}"
    STAGE="${REST%% *}"
fi

# ----- 2. Required key-value fields -----
get_field() {
    # Match lines like "- key: value" up to first blank line region; first match wins.
    local key="$1"
    printf '%s\n' "$ENTRY" | awk -v k="$key" '
        BEGIN { found=0 }
        $0 ~ "^- " k ":" {
            sub("^- " k ":[ ]*", "", $0)
            print
            found=1
            exit
        }
    '
}

has_field() {
    local key="$1"
    printf '%s\n' "$ENTRY" | grep -qE "^- ${key}:"
}

AUTHOR="$(get_field author)"
STATUS_VAL="$(get_field status)"
RUN_ID="$(get_field run_id)"

if ! has_field author; then
    die_violation "author" "missing required field"
elif [[ ! "$AUTHOR" =~ ^orchestrator$ ]] && [[ ! "$AUTHOR" =~ ^subagent:(${CANONICAL_STAGES})$ ]]; then
    die_violation "author" "must be 'orchestrator' or 'subagent:<canonical-stage>': '$AUTHOR'"
fi

if ! has_field status; then
    die_violation "status" "missing required field"
elif [[ ! "$STATUS_VAL" =~ ^(success|halt|error)$ ]]; then
    die_violation "status" "must be one of {success, halt, error}: '$STATUS_VAL'"
fi

if ! has_field run_id; then
    die_violation "run_id" "missing required field"
fi

# ----- 5/6. Subagent-record sub-blocks + halt_directive semantics -----
if [[ "$ENTRY_TYPE" == "subagent-record" ]]; then
    has_subblock() {
        printf '%s\n' "$ENTRY" | grep -qE "^### ${1}\$"
    }

    for sub in artifacts_written decisions_made halt_directive; do
        if ! has_subblock "$sub"; then
            die_violation "$sub" "subagent-record missing required sub-block '### $sub'"
        fi
    done

    # If halt_directive present, examine halt=true semantics.
    if has_subblock halt_directive; then
        # Capture lines after "### halt_directive" header.
        HD_BLOCK="$(printf '%s\n' "$ENTRY" | awk '
            /^### halt_directive$/ { collecting=1; next }
            collecting && /^### / { exit }
            collecting { print }
        ')"
        HALT_VAL="$(printf '%s\n' "$HD_BLOCK" | awk -F': *' '/^- halt:/ { sub(/^- halt:[ ]*/,"",$0); print; exit }')"
        if [[ "$HALT_VAL" == "true" ]]; then
            REASON_LINE="$(printf '%s\n' "$HD_BLOCK" | grep -E '^- reason:' | head -n1)"
            REASON_VAL="${REASON_LINE#- reason:}"
            REASON_VAL="${REASON_VAL# }"
            if [[ -z "$REASON_LINE" || -z "$REASON_VAL" ]]; then
                die_violation "halt_directive.reason" "halt=true requires non-empty reason"
            fi

            FC_LINE="$(printf '%s\n' "$HD_BLOCK" | grep -E '^- failure_class:' | head -n1)"
            FC_VAL="${FC_LINE#- failure_class:}"
            FC_VAL="${FC_VAL# }"
            if [[ -z "$FC_LINE" ]]; then
                die_violation "halt_directive.failure_class" "halt=true requires failure_class (FR-019)"
            elif [[ ! "$FC_VAL" =~ ^(temporal|semantic|permission)$ ]]; then
                die_violation "halt_directive.failure_class" "must be one of {temporal, semantic, permission} (FR-019): '$FC_VAL'"
            fi
        fi
    fi
fi

if (( VIOLATIONS > 0 )); then
    exit 1
fi
exit 0
