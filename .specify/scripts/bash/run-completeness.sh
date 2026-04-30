#!/usr/bin/env bash
# run-completeness.sh — FR-026 V1 per-stage completeness predicate.
#
# Source of truth: helper-contracts.md §run-completeness.sh, data-model.md E-7.
#
# Usage:
#   run-completeness.sh <feature-dir> <stage>
#
# Output: single token `complete` or `incomplete` on stdout.
# Exit codes: 0 success, 2 usage error.

set -uo pipefail

usage() {
    echo "usage: run-completeness.sh <feature-dir> <stage>" >&2
    exit 2
}

feature_dir="${1:-}"
stage="${2:-}"
[[ -n "$feature_dir" && -n "$stage" ]] || usage

spec="$feature_dir/spec.md"
plan="$feature_dir/plan.md"
tasks="$feature_dir/tasks.md"
log="$feature_dir/decisions-log.md"

# Mandatory section heuristics: a level-2 heading "## <name>" with at least one
# non-blank body line before the next heading or EOF.
has_section_with_body() {
    local file="$1" heading="$2"
    [[ -f "$file" ]] || return 1
    awk -v h="## $heading" '
        BEGIN { found=0; in_section=0; has_body=0 }
        $0 == h { in_section=1; next }
        in_section && /^## / { exit }
        in_section && /[^[:space:]]/ { has_body=1 }
        END { exit (has_body ? 0 : 1) }
    ' "$file"
}

predicate_specify() {
    [[ -f "$spec" ]] || { echo incomplete; return 0; }
    if grep -qF '[NEEDS CLARIFICATION]' "$spec"; then echo incomplete; return 0; fi
    for h in "User Stories" "Functional Requirements" "Success Criteria"; do
        if ! has_section_with_body "$spec" "$h"; then echo incomplete; return 0; fi
    done
    echo complete
}

predicate_plan() {
    [[ -f "$plan" ]] || { echo incomplete; return 0; }
    for h in "Summary" "Technical Context" "Project Structure"; do
        if ! has_section_with_body "$plan" "$h"; then echo incomplete; return 0; fi
    done
    echo complete
}

predicate_tasks() {
    [[ -f "$tasks" ]] || { echo incomplete; return 0; }
    if grep -qE '^- \[' "$tasks"; then echo complete; else echo incomplete; fi
}

# Stages whose completeness is anchored by a `stage-end:<stage>` markdown
# section in decisions-log.md.
predicate_log_stage_end() {
    local s="$1"
    [[ -f "$log" ]] || { echo incomplete; return 0; }
    if grep -qE "^## stage-end:${s} " "$log"; then echo complete; else echo incomplete; fi
}

case "$stage" in
    specify)                     predicate_specify ;;
    plan)                        predicate_plan ;;
    tasks)                       predicate_tasks ;;
    review|clarify|analyze)      predicate_log_stage_end "$stage" ;;
    implement|codereview|audit)  echo incomplete ;;
    *) usage ;;
esac
