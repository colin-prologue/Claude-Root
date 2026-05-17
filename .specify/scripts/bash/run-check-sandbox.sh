#!/usr/bin/env bash
# run-check-sandbox.sh — post-dispatch sandbox audit (FR-020 allowlist).
#
# Invocation: run-check-sandbox.sh <feature-dir> <stage>
#
# Reads git diff between the pre-dispatch HEAD (stored in .run/pre-dispatch-head
# by the orchestrator before each subagent dispatch) and the current HEAD, plus
# any uncommitted changes. Reports disallowed path modifications.
#
# Source of truth: contracts/helper-contracts.md §run-check-sandbox.sh
# FR-020: sandbox allowlist; data-model.md §E-8.

set -uo pipefail

. "$(dirname "$0")/run-common.sh"

feature_dir="${1:-}"
stage="${2:-}"

if [[ -z "$feature_dir" || -z "$stage" ]]; then
    echo "usage: run-check-sandbox.sh <feature-dir> <stage>" >&2
    exit 2
fi

if [[ ! -d "$feature_dir" ]]; then
    echo "ERROR: feature-dir '$feature_dir' not found" >&2
    exit 2
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "ERROR: not in a git repository" >&2
    exit 2
fi

# -------------------------------------------------------------------
# Collect changed paths since pre-dispatch-head + uncommitted changes
# -------------------------------------------------------------------

pre_dispatch_file="$(_run_lock_dir "$feature_dir")/pre-dispatch-head"

declare -a raw_paths=()

if [[ -f "$pre_dispatch_file" && -s "$pre_dispatch_file" ]]; then
    pre_head="$(cat "$pre_dispatch_file")"
    while IFS= read -r p; do
        [[ -n "$p" ]] && raw_paths+=("$p")
    done < <(git diff --name-only "$pre_head"..HEAD 2>/dev/null || true)
fi

# Uncommitted modifications (staged or working tree vs HEAD)
while IFS= read -r p; do
    [[ -n "$p" ]] && raw_paths+=("$p")
done < <(git diff --name-only HEAD 2>/dev/null || true)

if (( ${#raw_paths[@]} == 0 )); then
    exit 0
fi

# Deduplicate via sort -u (Bash 3.2 compatible — no associative arrays)
declare -a changed_paths=()
while IFS= read -r p; do
    [[ -n "$p" ]] && changed_paths+=("$p")
done < <(printf '%s\n' "${raw_paths[@]}" | sort -u)

# -------------------------------------------------------------------
# Main-branch detection: running on main/master is a violation for all changes
# -------------------------------------------------------------------

current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
on_main=false
[[ "$current_branch" == "main" || "$current_branch" == "master" ]] && on_main=true

# -------------------------------------------------------------------
# Allowlist check
# -------------------------------------------------------------------

# is_disallowed_reason <path> — print reason string and return 0 if disallowed;
# return 1 if allowed. Uses case-pattern matching (Bash 3.2 compatible).
is_disallowed_reason() {
    local path="$1"
    local base="${path##*/}"

    if $on_main; then
        printf 'main branch mutation'
        return 0
    fi

    case "$path" in
        .gitignore)
            printf 'protected system file'; return 0 ;;
        .github | .github/*)
            printf 'CI/CD configuration'; return 0 ;;
        .claude/hooks | .claude/hooks/*)
            printf 'hook outside feature scope'; return 0 ;;
        .claude/settings*.json)
            printf 'settings file outside feature scope'; return 0 ;;
    esac

    # .env* basename check: any file whose name starts with .env
    case "$base" in
        .env*)
            printf 'secrets-bearing pattern'; return 0 ;;
    esac

    return 1
}

# -------------------------------------------------------------------
# Report violations
# -------------------------------------------------------------------

violations=0
for path in "${changed_paths[@]}"; do
    reason="$(is_disallowed_reason "$path")" || continue
    printf '%s: %s\n' "$path" "$reason"
    violations=$((violations + 1))
done

(( violations > 0 )) && exit 1
exit 0
