#!/usr/bin/env bats

# T033 — US-2: chronological order of decisions-log.md entries + coalesced summary at tail.
# Verifies that for a fixture run with multiple subagent records, entries appear
# timestamp-monotonically and the run-serialize.sh coalesced summary (stage-end:run)
# appears after all subagent records per ADR-016 termination append.
# Source of truth: spec.md US-2; ADR-016 (canonical/derivative model).

setup() {
    REPO_ROOT_FIXTURE="$(mktemp -d)"
    cd "$REPO_ROOT_FIXTURE"
    mkdir -p .specify/scripts/bash specs/001-foo
    for h in run-common run-lock run-serialize; do
        cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/$h.sh" .specify/scripts/bash/
    done
    LOCK=".specify/scripts/bash/run-lock.sh"
    SERIALIZE=".specify/scripts/bash/run-serialize.sh"
    FEATURE="$REPO_ROOT_FIXTURE/specs/001-foo"
    LOG="$FEATURE/decisions-log.md"
    "$LOCK" acquire "$FEATURE"
    RUN_ID="$(grep -E '^run_id=' "$FEATURE/.run/run-lock" | cut -d= -f2-)"
}

teardown() {
    rm -rf "$REPO_ROOT_FIXTURE"
}

write_subagent_record() {
    local stage="$1" ts="$2"
    cat >> "$LOG" <<EOF
## subagent-record:$stage · $ts

- author: subagent:$stage
- status: success
- run_id: $RUN_ID

rationale

### artifacts_written

- specs/001-foo/$stage.md

### decisions_made

-

### halt_directive

- halt: false

EOF
}

# Extract timestamps from all level-2 headings in the log.
extract_heading_timestamps() {
    grep -E '^## [a-z-]+:[a-z-]+ · [0-9T:Z-]+$' "$LOG" | sed 's/.* · //'
}

@test "entries are in timestamp-monotonic order across a multi-stage fixture run" {
    write_subagent_record specify "2026-04-26T20:00:00Z"
    write_subagent_record clarify "2026-04-26T20:10:00Z"
    write_subagent_record plan    "2026-04-26T20:20:00Z"
    run "$SERIALIZE" "$FEATURE" clean
    [ "$status" -eq 0 ]

    prev=""
    while IFS= read -r ts; do
        if [[ -n "$prev" ]]; then
            # ISO-8601 UTC sorts lexicographically
            [[ "$prev" < "$ts" || "$prev" == "$ts" ]]
        fi
        prev="$ts"
    done < <(extract_heading_timestamps)
    # At least one timestamp must be present (serialize appended stage-end:run)
    [ -n "$prev" ]
}

@test "coalesced summary (stage-end:run) appears after all subagent-record headings" {
    write_subagent_record specify "2026-04-26T20:00:00Z"
    write_subagent_record plan    "2026-04-26T20:10:00Z"
    run "$SERIALIZE" "$FEATURE" clean
    [ "$status" -eq 0 ]

    last_subagent_line="$(grep -n '^## subagent-record:' "$LOG" | tail -1 | cut -d: -f1)"
    run_end_line="$(grep -n '^## stage-end:run' "$LOG" | tail -1 | cut -d: -f1)"
    [ -n "$last_subagent_line" ]
    [ -n "$run_end_line" ]
    (( run_end_line > last_subagent_line ))
}

@test "cold start: serialize creates decisions-log.md with stage-end:run when no prior entries exist" {
    [ ! -f "$LOG" ]
    run "$SERIALIZE" "$FEATURE" clean
    [ "$status" -eq 0 ]
    [ -f "$LOG" ]
    grep -q '^## stage-end:run' "$LOG"
}
