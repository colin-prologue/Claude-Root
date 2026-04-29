#!/usr/bin/env bats

# T003 — PR0 precursor: `check-prerequisites.sh --feature-dir <path>` flag tests.
# Per helper-contracts.md L204 and plan.md PR0:
#  (a) --feature-dir <matching>     : flag honored, FEATURE_DIR matches
#  (b) --feature-dir <other>        : flag overrides branch-derived default
#  (c) missing path                 : exit 1 with diagnostic

setup() {
    REPO_ROOT_FIXTURE="$(mktemp -d)"
    cd "$REPO_ROOT_FIXTURE"
    git init -q -b 001-foo .
    git config user.email "t@t" >/dev/null
    git config user.name  "t"   >/dev/null

    mkdir -p specs/001-foo specs/002-bar .specify/scripts/bash .specify/memory
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/check-prerequisites.sh" .specify/scripts/bash/
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/common.sh"             .specify/scripts/bash/

    # Minimal artifacts both feature dirs need
    touch specs/001-foo/plan.md specs/002-bar/plan.md

    git add -A >/dev/null
    git commit -q -m init
}

teardown() {
    rm -rf "$REPO_ROOT_FIXTURE"
}

@test "(a) --feature-dir matches branch-derived default — FEATURE_DIR honored" {
    run .specify/scripts/bash/check-prerequisites.sh --json --feature-dir "$REPO_ROOT_FIXTURE/specs/001-foo"
    [ "$status" -eq 0 ]
    [[ "$output" == *"\"FEATURE_DIR\":\"$REPO_ROOT_FIXTURE/specs/001-foo\""* ]]
}

@test "(b) --feature-dir overrides branch-derived default" {
    # Branch is 001-foo; --feature-dir points to 002-bar; expect 002-bar in payload.
    run .specify/scripts/bash/check-prerequisites.sh --json --feature-dir "$REPO_ROOT_FIXTURE/specs/002-bar"
    [ "$status" -eq 0 ]
    [[ "$output" == *"\"FEATURE_DIR\":\"$REPO_ROOT_FIXTURE/specs/002-bar\""* ]]
    # And NOT 001-foo
    [[ "$output" != *"\"FEATURE_DIR\":\"$REPO_ROOT_FIXTURE/specs/001-foo\""* ]]
}

@test "(c) --feature-dir <nonexistent> exits 1 with diagnostic" {
    run .specify/scripts/bash/check-prerequisites.sh --json --feature-dir "$REPO_ROOT_FIXTURE/specs/999-missing"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Feature directory not found"* ]] || [[ "$output" == *"feature-dir"* ]]
}

@test "unknown flag still errors (preserved behavior)" {
    run .specify/scripts/bash/check-prerequisites.sh --bogus-flag
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}
