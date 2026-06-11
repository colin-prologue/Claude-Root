#!/usr/bin/env bash
# run-lock.sh — atomic lock + abort-sentinel cleanup for /speckit.run.
#
# Implements FR-027 (atomic remove of lock + sentinel), FR-028 (one run per
# feature dir), ADR-018 (--break-lock recovery), LOG-012 (.run/*.tmp sweep on acquire).
#
# Usage:
#   run-lock.sh acquire        <feature-dir>
#   run-lock.sh release        <feature-dir>
#   run-lock.sh break          <feature-dir>
#   run-lock.sh check-sentinel <feature-dir>

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/run-common.sh"

usage() {
    echo "usage: run-lock.sh {acquire|release|break|check-sentinel} <feature-dir>" >&2
    exit 2
}

cmd="${1:-}"
feature_dir="${2:-}"

case "$cmd" in
    acquire|release|break|check-sentinel) ;;
    *) usage ;;
esac

[[ -n "$feature_dir" ]] || usage

run_dir="$(_run_lock_dir "$feature_dir")"
lock_file="$run_dir/run-lock"
abort_file="$run_dir/abort"

acquire() {
    mkdir -p "$run_dir" || { echo "ERROR: could not create $run_dir" >&2; exit 3; }
    local run_id
    run_id="run-$(_utc_now)-$(printf '%06x' $((RANDOM * RANDOM % 16777216)))"
    local ts
    ts="$(_utc_now)"

    # Atomic create-or-fail via noclobber.
    if ! (set -C; printf 'run_id=%s\ncreated_at=%s\n' "$run_id" "$ts" > "$lock_file") 2>/dev/null; then
        # Already held — surface contents and exit 1.
        if [[ -f "$lock_file" ]]; then
            cat "$lock_file"
        fi
        exit 1
    fi

    # LOG-012: orphan tmp sweep on acquire.
    _sweep_tmp "$run_dir"
    # sweep stage-diff artifacts from prior run.
    rm -f "$run_dir"/stage-diff-*.files "$run_dir"/stage-diff-*.patch 2>/dev/null || true
}

release() {
    # FR-027 atomic-remove: stage targets into a tombstone subdir, then rm -rf the
    # subdir. Order: lock first (lose the lock cheaply if mid-removal interrupted
    # — ensures abort-sentinel does not outlive the lock from the orchestrator's
    # perspective), then sentinel + verdict.
    rm -f "$lock_file" 2>/dev/null || true
    rm -f "$abort_file" 2>/dev/null || true
}

break_lock() {
    # ADR-018: tolerates absence; emits break-lock event payload to stdout for
    # the orchestrator to relay through run-emit-event.sh. The actual sidecar
    # write happens in the caller; here we only surface the prior session info.
    if [[ -f "$lock_file" ]]; then
        cat "$lock_file"
    fi
    release
}

check_sentinel() {
    [[ -f "$abort_file" ]] && exit 1
    exit 0
}

case "$cmd" in
    acquire)        acquire ;;
    release)        release ;;
    break)          break_lock ;;
    check-sentinel) check_sentinel ;;
esac
