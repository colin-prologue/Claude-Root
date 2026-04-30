#!/usr/bin/env bats

# T008 — run-target.sh: validate | next
# Source of truth: helper-contracts.md §run-target.sh, FR-009, data-model.md E-6.

setup() {
    REPO_ROOT_FIXTURE="$(mktemp -d)"
    cd "$REPO_ROOT_FIXTURE"
    mkdir -p .specify/scripts/bash
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-common.sh" .specify/scripts/bash/
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-target.sh" .specify/scripts/bash/ 2>/dev/null || true
    TARGET=".specify/scripts/bash/run-target.sh"
}

teardown() {
    rm -rf "$REPO_ROOT_FIXTURE"
}

# ----- validate -----

@test "validate accepts a single canonical stage" {
    run "$TARGET" validate "specify"
    [ "$status" -eq 0 ]
}

@test "validate accepts a contiguous canonical subsequence" {
    run "$TARGET" validate "specify→clarify→plan"
    [ "$status" -eq 0 ]
}

@test "validate accepts a code-action contiguous subsequence" {
    run "$TARGET" validate "implement→codereview→audit"
    [ "$status" -eq 0 ]
}

@test "validate rejects non-contiguous subsequence" {
    run "$TARGET" validate "specify→tasks"
    [ "$status" -eq 1 ]
}

@test "validate rejects reordered subsequence" {
    run "$TARGET" validate "plan→specify"
    [ "$status" -eq 1 ]
}

@test "validate rejects unknown stage" {
    run "$TARGET" validate "specify→bogus→plan"
    [ "$status" -eq 1 ]
}

# ----- review-contiguity grammar (data-model E-6) -----

@test "validate accepts review between two non-code stages" {
    run "$TARGET" validate "specify→review→plan"
    [ "$status" -eq 0 ]
}

@test "validate accepts review in multiple gaps" {
    run "$TARGET" validate "specify→review→clarify→plan→review→tasks"
    [ "$status" -eq 0 ]
}

@test "validate rejects review at start of target" {
    run "$TARGET" validate "review→plan"
    [ "$status" -eq 1 ]
}

@test "validate rejects review at end of target" {
    run "$TARGET" validate "plan→review"
    [ "$status" -eq 1 ]
}

@test "validate rejects two consecutive review tokens in one gap" {
    run "$TARGET" validate "specify→review→review→plan"
    [ "$status" -eq 1 ]
}

@test "validate rejects review adjacent to a code-action stage" {
    run "$TARGET" validate "tasks→review→implement"
    [ "$status" -eq 1 ]
}

@test "validate rejects review adjacent to implement (other side)" {
    run "$TARGET" validate "implement→review→codereview"
    [ "$status" -eq 1 ]
}

# ----- next -----

@test "next returns next stage in canonical target" {
    run "$TARGET" next "specify→plan→tasks" "specify"
    [ "$status" -eq 0 ]
    [ "$output" = "plan" ]
}

@test "next returns next stage skipping over review (review is meta)" {
    run "$TARGET" next "specify→review→plan" "specify"
    [ "$status" -eq 0 ]
    [ "$output" = "review" ]
}

@test "next returns __END__ at exhaustion" {
    run "$TARGET" next "specify→plan" "plan"
    [ "$status" -eq 0 ]
    [ "$output" = "__END__" ]
}

@test "next rejects last-completed not in target" {
    run "$TARGET" next "specify→plan" "tasks"
    [ "$status" -eq 1 ]
}

# ----- usage -----

@test "validate with no arg exits 2" {
    run "$TARGET" validate
    [ "$status" -eq 2 ]
}

@test "next with one arg exits 2" {
    run "$TARGET" next "specify→plan"
    [ "$status" -eq 2 ]
}

@test "unknown subcommand exits 2" {
    run "$TARGET" frobnicate
    [ "$status" -eq 2 ]
}
