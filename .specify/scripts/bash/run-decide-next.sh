#!/usr/bin/env bash
# run-decide-next.sh — ADR-019 routing core + ADR-022 verdict-receipt mint.
#
# Source of truth:
#   contracts/helper-contracts.md §run-decide-next.sh
#   ADR-019 (deterministic core), ADR-022 (verdict-receipt protocol)
#   data-model.md §E-7 (routing matrix)
#
# Usage:
#   run-decide-next.sh <feature-dir>
#
# Outputs (stdout, single line): one of
#   continue | halt:<reason> | skip:<stage> | abort
#
# Side effect: writes <feature-dir>/.run/last-verdict as
#   <verdict>\t<run_id>\t<input_hash>\t<ts>
# unless the pre-flight omission check fires (ADR-022 step 5).
#
# Exit codes:
#   0 — verdict on stdout AND receipt minted; LLM MUST invoke run-emit-event.sh next.
#   1 — log unreadable / malformed beyond recovery (FR-019 semantic failure), OR
#       pre-flight omission detected (verdict-omitted entry written, receipt
#       preserved as evidence).
#   2 — usage error.

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/run-common.sh"

usage() {
    echo "usage: run-decide-next.sh <feature-dir>" >&2
    exit 2
}

[[ $# -eq 1 ]] || usage
feature_dir="$1"
[[ -d "$feature_dir" ]] || { echo "ERROR: feature-dir not found: $feature_dir" >&2; exit 2; }

run_dir="$(_run_lock_dir "$feature_dir")"
log="$feature_dir/decisions-log.md"
receipt="$run_dir/last-verdict"
abort_sentinel="$run_dir/abort"

run_id="$(_run_id_of_lock "$feature_dir")" || exit 1

# ----- Step 1: pre-flight omission check (ADR-022 step 5) -----
# If a prior verdict was minted but never consumed by run-emit-event.sh,
# refuse to mint a new one. The unconsumed receipt remains as evidence.
if [[ -s "$receipt" ]]; then
    ts="$(_utc_now)"
    cat <<EOF | _emit_canonical_entry "$feature_dir"

## verdict-omitted:orchestrator · $ts

- author: orchestrator
- status: halt
- run_id: $run_id

A prior verdict was minted by run-decide-next.sh but never consumed by
run-emit-event.sh. The pre-flight omission check refused to mint a new
verdict; the original receipt is preserved as evidence (ADR-022 step 5).

EOF
    echo "ERROR: unconsumed verdict in $receipt — refusing to mint" >&2
    exit 1
fi

# ----- Step 2: log presence -----
if [[ ! -f "$log" || ! -s "$log" ]]; then
    echo "ERROR: decisions-log.md missing or empty: $log" >&2
    exit 1
fi

# ----- Step 3: locate latest resume-anchor entry (FR-023 / RC-5 filter) -----
# Shared with run-emit-event.sh via _latest_routable_anchor (run-common.sh).
anchor="$(_latest_routable_anchor "$feature_dir")" || {
    echo "ERROR: decisions-log.md has no routable entry (filtered scan empty)" >&2
    exit 1
}
entry_type="${anchor%%:*}"
rest="${anchor#*:}"
stage="${rest%%:*}"
latest_lineno="${rest##*:}"

# ----- Step 4: derive verdict (sentinel takes precedence) -----
verdict=""

if [[ -e "$abort_sentinel" ]]; then
    # ADR-019 b1 sentinel fold-in: emit abort verdict ahead of any other routing.
    verdict="abort"
elif [[ "$entry_type" == "subagent-record" ]]; then
    # Read halt_directive from the entry body.
    # Slice from the heading line to EOF, then to next "## " boundary.
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
        # halt=false (or below-threshold continue per FR-025): proceed.
        verdict="continue"
    fi
elif [[ "$entry_type" == "abort" ]]; then
    verdict="abort"
elif [[ "$entry_type" == "stage-skip" ]]; then
    verdict="skip:$stage"
else
    # stage-start / stage-end / escalate / route — assume continue.
    # (escalate ⇒ developer already acknowledged; orchestrator resumes.)
    verdict="continue"
fi

# ----- Step 5: mint receipt + write stdout -----
ts="$(_utc_now)"
input_hash="$(_hash_input "$anchor")"
mkdir -p "$run_dir"
printf '%s\t%s\t%s\t%s' "$verdict" "$run_id" "$input_hash" "$ts" > "$receipt"

printf '%s\n' "$verdict"
exit 0
