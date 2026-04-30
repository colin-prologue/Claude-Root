#!/usr/bin/env bash
# run-target.sh — FR-009 contiguous-subsequence validation + review-contiguity grammar.
#
# Source of truth: helper-contracts.md §run-target.sh, data-model.md E-6.
#
# Usage:
#   run-target.sh validate <target-string>
#   run-target.sh next     <target-string> <last-completed-stage>

set -uo pipefail

# Canonical pipeline (FR-009 — selection only, no reordering).
CANONICAL=(specify clarify plan tasks analyze implement codereview audit)
NON_CODE=(specify clarify plan tasks analyze)
CODE_ACTION=(implement codereview audit)

usage() {
    echo "usage: run-target.sh {validate|next} ..." >&2
    exit 2
}

contains() {
    local needle="$1"; shift
    local item
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

# Split a target string on the U+2192 arrow (→) into a global TOKENS array.
split_target() {
    local input="$1"
    # Bash 3.2 (macOS default) lacks readarray; use IFS+read with the arrow as delimiter.
    TOKENS=()
    local rest="$input" head
    while [[ "$rest" == *"→"* ]]; do
        head="${rest%%→*}"
        rest="${rest#*→}"
        TOKENS+=("$head")
    done
    TOKENS+=("$rest")
}

validate_target() {
    local target="$1"
    [[ -n "$target" ]] || { echo "ERROR: empty target" >&2; exit 1; }

    split_target "$target"

    # Every token must be a canonical stage or `review`.
    local tok
    for tok in "${TOKENS[@]}"; do
        if [[ "$tok" != "review" ]] && ! contains "$tok" "${CANONICAL[@]}"; then
            echo "ERROR: unknown stage '$tok'" >&2
            exit 1
        fi
    done

    # First and last tokens must not be `review`.
    if [[ "${TOKENS[0]}" == "review" || "${TOKENS[${#TOKENS[@]}-1]}" == "review" ]]; then
        echo "ERROR: 'review' MAY NOT appear at start or end of target" >&2
        exit 1
    fi

    # Strip `review` tokens; the remainder must be a contiguous canonical subsequence,
    # and review-adjacency rules must hold.
    local stripped=()
    local i
    for ((i=0; i<${#TOKENS[@]}; i++)); do
        local t="${TOKENS[$i]}"
        if [[ "$t" == "review" ]]; then
            # Adjacent tokens must both be non-code-action stages (E-6).
            local prev="${TOKENS[$i-1]:-}"
            local next="${TOKENS[$i+1]:-}"
            if contains "$prev" "${CODE_ACTION[@]}" || contains "$next" "${CODE_ACTION[@]}"; then
                echo "ERROR: 'review' MAY NOT appear adjacent to a code-action stage ('$prev'/'$next')" >&2
                exit 1
            fi
            # At most one review per gap: previous token must not also be review.
            if [[ "$prev" == "review" ]]; then
                echo "ERROR: at most one 'review' permitted per inter-stage gap" >&2
                exit 1
            fi
        else
            stripped+=("$t")
        fi
    done

    # Canonical-ordering rule: stripped tokens must be strictly increasing in
    # canonical index (no reordering). A `review` token bridging two non-review
    # tokens lets them skip canonical stages — without a bridging review,
    # consecutive non-review tokens must be canonical-adjacent.
    canon_idx() {
        local stage="$1" k
        for ((k=0; k<${#CANONICAL[@]}; k++)); do
            if [[ "${CANONICAL[$k]}" == "$stage" ]]; then echo "$k"; return 0; fi
        done
        return 1
    }

    # 1. Strictly-increasing canonical index across stripped tokens.
    local prev_idx=-1 idx s
    for s in "${stripped[@]}"; do
        if ! idx=$(canon_idx "$s"); then
            echo "ERROR: '$s' is not a canonical stage" >&2
            exit 1
        fi
        if (( idx <= prev_idx )); then
            echo "ERROR: target reorders canonical stages at '$s'" >&2
            exit 1
        fi
        prev_idx=$idx
    done

    # 2. Consecutive non-review pairs in TOKENS must be canonical-adjacent.
    local i
    for ((i=0; i+1<${#TOKENS[@]}; i++)); do
        local a="${TOKENS[$i]}" b="${TOKENS[$i+1]}"
        [[ "$a" == "review" || "$b" == "review" ]] && continue
        local ai bi
        ai=$(canon_idx "$a")
        bi=$(canon_idx "$b")
        if (( bi - ai != 1 )); then
            echo "ERROR: '$a'→'$b' is not a contiguous canonical pair (insert 'review' to bridge non-adjacent stages)" >&2
            exit 1
        fi
    done
    return 0
}

next_stage() {
    local target="$1" last="$2"
    [[ -n "$target" && -n "$last" ]] || usage

    split_target "$target"

    # Find `last` in TOKENS; output the next token, or __END__ at exhaustion.
    local i
    for ((i=0; i<${#TOKENS[@]}; i++)); do
        if [[ "${TOKENS[$i]}" == "$last" ]]; then
            if (( i + 1 >= ${#TOKENS[@]} )); then
                echo "__END__"
                return 0
            fi
            echo "${TOKENS[$i+1]}"
            return 0
        fi
    done
    echo "ERROR: last-completed '$last' not in target" >&2
    exit 1
}

cmd="${1:-}"
shift || true
case "$cmd" in
    validate)
        [[ $# -eq 1 ]] || usage
        validate_target "$1"
        ;;
    next)
        [[ $# -eq 2 ]] || usage
        next_stage "$1" "$2"
        ;;
    *)
        usage
        ;;
esac
