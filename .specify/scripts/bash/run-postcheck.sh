#!/usr/bin/env bash
# run-postcheck.sh — pre-route linter postcheck on code-action stages (ADR-023).
#
# Invocation: run-postcheck.sh <feature-dir> <stage>
#
# Runs check-adr-crossrefs.sh (Principle VII) and check-prerequisites.sh
# --feature-dir <feature-dir>. For stage=implement, also cross-checks claimed
# test files in the latest subagent-record against git ls-files.
#
# Clean exit MUST emit exactly: postcheck: no findings
# (LOG-013 normative MUST — no iconography, no 'all checks passed' phrasing)
#
# Source of truth: contracts/helper-contracts.md §run-postcheck.sh, ADR-023.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

feature_dir="${1:-}"
stage="${2:-}"

if [[ -z "$feature_dir" || -z "$stage" ]]; then
    echo "usage: run-postcheck.sh <feature-dir> <stage>" >&2
    exit 2
fi

if [[ ! -d "$feature_dir" ]]; then
    echo "ERROR: feature-dir '$feature_dir' not found" >&2
    exit 2
fi

# Non-code stages are out of scope (LOG-010); pass through immediately.
case "$stage" in
    implement|codereview|audit) ;;
    *)
        printf 'postcheck: no findings\n'
        exit 0
        ;;
esac

# -------------------------------------------------------------------
# Collect findings
# -------------------------------------------------------------------

declare -a findings=()

# 1. ADR cross-reference check (Principle VII)
adr_script="$SCRIPT_DIR/check-adr-crossrefs.sh"
if [[ ! -x "$adr_script" ]]; then
    echo "ERROR: check-adr-crossrefs.sh not found or not executable at $adr_script" >&2
    exit 2
fi

adr_out="$("$adr_script" 2>&1)" || {
    # Non-zero exit — extract missing-reference lines from output
    while IFS= read -r line; do
        case "$line" in
            "  - "*)
                findings+=("adr-crossrefs: ${line#  - }")
                ;;
        esac
    done <<< "$adr_out"
    # If non-zero but no parseable lines, add a generic finding
    if (( ${#findings[@]} == 0 )); then
        findings+=("adr-crossrefs: check failed")
    fi
}

# 2. Prerequisites check (--feature-dir override required per ADR-023 contract)
prereq_script="$SCRIPT_DIR/check-prerequisites.sh"
if [[ ! -x "$prereq_script" ]]; then
    echo "ERROR: check-prerequisites.sh not found or not executable at $prereq_script" >&2
    exit 2
fi

prereq_args=(--feature-dir "$feature_dir")
[[ "$stage" == "implement" ]] && prereq_args+=(--require-tasks)

"$prereq_script" "${prereq_args[@]}" >/dev/null 2>&1 || {
    findings+=("prerequisites: check failed for $feature_dir")
}

# 3. For implement: cross-check claimed test files against git ls-files
if [[ "$stage" == "implement" ]]; then
    log="$feature_dir/decisions-log.md"
    if [[ -f "$log" ]]; then
        # Parse claimed test-file paths from the latest subagent-record:implement entry.
        # A path is a "test file" if its basename or directory name contains 'test'
        # or it ends in .bats — matching the project's bats convention.
        declare -a claimed_tests=()
        in_record=false
        in_artifacts=false

        while IFS= read -r line; do
            case "$line" in
                "## subagent-record:implement"*)
                    in_record=true
                    in_artifacts=false
                    claimed_tests=()  # reset — we want the latest record
                    ;;
                "## "*) # next top-level entry ends the record
                    if $in_record; then
                        in_record=false
                        in_artifacts=false
                    fi
                    ;;
                "### artifacts_written")
                    $in_record && in_artifacts=true
                    ;;
                "### "*) # next subsection ends artifacts block
                    in_artifacts=false
                    ;;
                "- "*)
                    if $in_record && $in_artifacts; then
                        path="${line#- }"
                        path="${path#"${path%%[![:space:]]*}"}"  # ltrim
                        # Is this a test file?
                        base="${path##*/}"
                        dir="${path%/*}"
                        is_test=false
                        case "$base" in
                            *_test.*|test_*|*.bats) is_test=true ;;
                        esac
                        case "$dir" in
                            *tests*|*test*) is_test=true ;;
                        esac
                        $is_test && claimed_tests+=("$path")
                    fi
                    ;;
            esac
        done < "$log"

        if (( ${#claimed_tests[@]} > 0 )); then
            # Get tracked files (git ls-files includes staged+committed)
            declare -a tracked=()
            while IFS= read -r f; do
                [[ -n "$f" ]] && tracked+=("$f")
            done < <(git ls-files 2>/dev/null || true)

            for claimed in "${claimed_tests[@]}"; do
                found=false
                for f in "${tracked[@]}"; do
                    [[ "$f" == "$claimed" ]] && { found=true; break; }
                done
                $found || findings+=("claimed-tests: $claimed not found in git ls-files")
            done
        fi
    fi
fi

# -------------------------------------------------------------------
# Report
# -------------------------------------------------------------------

if (( ${#findings[@]} == 0 )); then
    printf 'postcheck: no findings\n'
    exit 0
fi

for f in "${findings[@]}"; do
    printf '%s\n' "$f"
done
exit 1
