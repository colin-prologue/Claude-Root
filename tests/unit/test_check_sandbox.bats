#!/usr/bin/env bats

# T020 — run-check-sandbox.sh: post-dispatch sandbox audit (FR-020 allowlist).
#
# Source of truth:
#   contracts/helper-contracts.md §run-check-sandbox.sh
#   spec.md FR-020 (code-action sandbox allowlist)
#   data-model.md §E-8 (Sandbox Audit Result)
#
# Fixture: mktemp -d git repo on a feature branch. Pre-dispatch HEAD stored in
# .run/pre-dispatch-head; tests commit disallowed/allowed files after that point.

setup() {
    REPO_ROOT_FIXTURE="$(mktemp -d)"
    cd "$REPO_ROOT_FIXTURE"

    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test"

    mkdir -p specs/001-foo .specify/scripts/bash
    printf 'spec\n' > specs/001-foo/spec.md
    git add .
    git commit -m "initial" --quiet

    # Work on a feature branch so main-branch detection doesn't fire
    git checkout -b 010-test-feature --quiet

    PRE_HEAD="$(git rev-parse HEAD)"

    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-common.sh" .specify/scripts/bash/
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-lock.sh"   .specify/scripts/bash/
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-check-sandbox.sh" .specify/scripts/bash/ 2>/dev/null || true

    SANDBOX=".specify/scripts/bash/run-check-sandbox.sh"
    FEATURE="$REPO_ROOT_FIXTURE/specs/001-foo"

    ".specify/scripts/bash/run-lock.sh" acquire "$FEATURE"
    printf '%s' "$PRE_HEAD" > "$FEATURE/.run/pre-dispatch-head"
}

teardown() {
    rm -rf "$REPO_ROOT_FIXTURE"
}

# commit_file <path> [content] — stage and commit a file after pre-dispatch-head
commit_file() {
    local path="$1" content="${2:-change}"
    mkdir -p "$(dirname "$path")" 2>/dev/null || true
    printf '%s\n' "$content" > "$path"
    git add "$path"
    git commit -m "add $path" --quiet
}

# -------------------------------------------------------------------
# Usage errors
# -------------------------------------------------------------------

@test "missing feature-dir arg → exit 2" {
    run "$SANDBOX"
    [ "$status" -eq 2 ]
}

@test "missing stage arg → exit 2" {
    run "$SANDBOX" "$FEATURE"
    [ "$status" -eq 2 ]
}

@test "feature-dir does not exist → exit 2" {
    run "$SANDBOX" "/nonexistent/feature" implement
    [ "$status" -eq 2 ]
}

# -------------------------------------------------------------------
# Clean paths (ALLOWED)
# -------------------------------------------------------------------

@test "no changed files since pre-dispatch-head → exit 0, empty output" {
    run "$SANDBOX" "$FEATURE" implement
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ALLOWED: file under specs/001-foo/ → exit 0" {
    commit_file "specs/001-foo/plan.md"
    run "$SANDBOX" "$FEATURE" implement
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ALLOWED: project source file (not in disallowed list) → exit 0" {
    commit_file "src/foo.py"
    run "$SANDBOX" "$FEATURE" implement
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# -------------------------------------------------------------------
# Disallowed paths (violations — exit 1 + diagnostic line)
# -------------------------------------------------------------------

@test "DISALLOWED: .gitignore → exit 1, path in diagnostic" {
    commit_file ".gitignore" "*.pyc"
    run "$SANDBOX" "$FEATURE" implement
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "^\.gitignore:"
}

@test "DISALLOWED: .github/workflows/ci.yml → exit 1" {
    commit_file ".github/workflows/ci.yml" "name: CI"
    run "$SANDBOX" "$FEATURE" implement
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "^\.github/workflows/ci\.yml:"
}

@test "DISALLOWED: .claude/settings.local.json → exit 1" {
    commit_file ".claude/settings.local.json" "{}"
    run "$SANDBOX" "$FEATURE" implement
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "^\.claude/settings\.local\.json:"
}

@test "DISALLOWED: .claude/hooks/pre-push → exit 1" {
    commit_file ".claude/hooks/pre-push" "#!/bin/bash"
    run "$SANDBOX" "$FEATURE" implement
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "^\.claude/hooks/pre-push:"
}

@test "DISALLOWED: .env.local (secrets pattern) → exit 1" {
    commit_file ".env.local" "SECRET=x"
    run "$SANDBOX" "$FEATURE" implement
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "^\.env\.local:"
}

@test "DISALLOWED: .env (bare) → exit 1" {
    commit_file ".env" "SECRET=x"
    run "$SANDBOX" "$FEATURE" implement
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "^\.env:"
}

@test "multiple violations → exit 1, one diagnostic line per path" {
    commit_file ".gitignore" "*.pyc"
    commit_file ".env" "SECRET=x"
    run "$SANDBOX" "$FEATURE" implement
    [ "$status" -eq 1 ]
    [ "$(echo "$output" | grep -c '^')" -ge 2 ]
}

@test "DISALLOWED: .claude/settings.json (exact match) → exit 1" {
    commit_file ".claude/settings.json" "{}"
    run "$SANDBOX" "$FEATURE" implement
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "^\.claude/settings\.json:"
}

# -------------------------------------------------------------------
# Diagnostic format
# -------------------------------------------------------------------

@test "diagnostic format is '<path>: <reason>' (colon-space separator)" {
    commit_file ".gitignore" "*.pyc"
    run "$SANDBOX" "$FEATURE" implement
    echo "$output" | grep -qE "^[^:]+: .+"
}
