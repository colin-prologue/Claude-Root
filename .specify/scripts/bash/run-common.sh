#!/usr/bin/env bash
# run-common.sh — shared utilities for the run-*.sh helper family.
#
# Sourced (never invoked directly) by other run-*.sh helpers via:
#   . "$(dirname "$0")/run-common.sh"
#
# Source of truth: specs/010-autonomous-workflow/contracts/helper-contracts.md §run-common.sh.
# Per ADR-019 single-purpose convention, run-common.sh has no dedicated bats file —
# it is covered indirectly through the helpers that source it.

set -o pipefail

# _run_lock_dir <feature-dir> — print the canonical .run/ directory path.
_run_lock_dir() {
    printf '%s/.run' "$1"
}

# _atomic_rename_into <src> <dst>
# Stage-then-rename (LOG-012). On macOS/Linux same-filesystem semantics, mv -f is atomic.
# stderr is preserved; non-zero exit propagates.
_atomic_rename_into() {
    local src="$1" dst="$2"
    if [[ -z "$src" || -z "$dst" ]]; then
        echo "ERROR: _atomic_rename_into requires <src> <dst>" >&2
        return 2
    fi
    mv -f "$src" "$dst"
}

# _emit_canonical_entry <feature-dir> <entry-markdown-on-stdin>
# Append a markdown section to decisions-log.md via stage-then-rename.
# Used by run-serialize.sh for the coalesced termination summary (ADR-016).
_emit_canonical_entry() {
    local feature_dir="$1"
    if [[ -z "$feature_dir" ]]; then
        echo "ERROR: _emit_canonical_entry requires <feature-dir>" >&2
        return 2
    fi
    local log="$feature_dir/decisions-log.md"
    local run_id
    run_id="$(_run_id_of_lock "$feature_dir" 2>/dev/null || echo "no-run")"
    local tmp="$log.$run_id.tmp"

    if [[ -f "$log" ]]; then
        cat "$log" > "$tmp" || return 3
    else
        : > "$tmp" || return 3
    fi
    # Read entry markdown from stdin and append.
    cat >> "$tmp" || return 3
    _atomic_rename_into "$tmp" "$log" || return 3
}

# _sweep_tmp <dir>
# Remove orphan *.tmp files left by an interrupted prior run. Silent on empty dir.
_sweep_tmp() {
    local dir="$1"
    [[ -d "$dir" ]] || return 0
    find "$dir" -maxdepth 1 -type f -name '*.tmp' -delete 2>/dev/null || true
}

# _run_id_of_lock <feature-dir>
# Read the run_id= line from the active run-lock and print the value. Exit 1 on absence.
_run_id_of_lock() {
    local lock="$(_run_lock_dir "$1")/run-lock"
    if [[ ! -f "$lock" ]]; then
        echo "ERROR: no run-lock at $lock" >&2
        return 1
    fi
    local id
    id="$(grep -E '^run_id=' "$lock" | head -n1 | cut -d= -f2-)"
    if [[ -z "$id" ]]; then
        echo "ERROR: run-lock at $lock is missing run_id" >&2
        return 1
    fi
    printf '%s' "$id"
}

# _utc_now — print ISO-8601 UTC with Z suffix (used for entry/event timestamps).
_utc_now() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# _latest_routable_anchor <feature-dir>
# Identify the latest entry in decisions-log.md that is a valid resume anchor.
# Skips orchestrator-authored canonical-exception entries (verdict-mismatch,
# verdict-omitted, pipeline-incomplete) per FR-023 / RC-5.
#
# Output (stdout): single line `<entry_type>:<stage>:<lineno>` on success.
# Exit codes: 0 — anchor found; 1 — no anchor (missing/empty log or all
# entries filtered); 2 — usage error.
#
# Used by run-decide-next.sh (to mint receipt input_hash) and run-emit-event.sh
# (to recompute input_hash for receipt validation). Sharing a single recipe
# guarantees both helpers compute the same hash from the same log state.
_latest_routable_anchor() {
    local feature_dir="$1"
    [[ -n "$feature_dir" ]] || { echo "ERROR: _latest_routable_anchor requires <feature-dir>" >&2; return 2; }
    local log="$feature_dir/decisions-log.md"
    [[ -f "$log" && -s "$log" ]] || return 1

    local latest_heading="" latest_lineno=0
    while IFS= read -r line_with_no; do
        local lineno="${line_with_no%%:*}"
        local line="${line_with_no#*:}"
        local tail_after="${line#\#\# }"
        local etype="${tail_after%%:*}"
        case "$etype" in
            verdict-mismatch|verdict-omitted|pipeline-incomplete) continue ;;
            stage-start|stage-end|stage-skip|escalate|route|abort|subagent-record)
                latest_heading="$line"
                latest_lineno="$lineno"
                ;;
            *) continue ;;
        esac
    done < <(grep -nE '^## ' "$log" || true)

    [[ -n "$latest_heading" ]] || return 1
    local heading_tail="${latest_heading#\#\# }"
    local entry_type="${heading_tail%%:*}"
    local rest="${heading_tail#*:}"
    local stage="${rest%% *}"
    printf '%s:%s:%s' "$entry_type" "$stage" "$latest_lineno"
}
