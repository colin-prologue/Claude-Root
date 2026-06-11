#!/usr/bin/env bats

# T022 — run-postcheck.sh: pre-route linter postcheck on code-action stages.
#
# Source of truth:
#   contracts/helper-contracts.md §run-postcheck.sh
#   ADR-023 (pre-route postcheck gate)
#   LOG-013 (neutral no-findings banner — normative MUST, no iconography)
#   LOG-010 (non-code stages out of scope)
#
# Fixture: mktemp -d git repo with stubbed linter scripts so tests are
# self-contained (check-adr-crossrefs.sh and check-prerequisites.sh are
# replaced by stubs that exercise specific outcomes).

setup() {
    REPO_ROOT_FIXTURE="$(mktemp -d)"
    cd "$REPO_ROOT_FIXTURE"

    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test"
    git checkout -b 010-test-feature --quiet 2>/dev/null || true

    mkdir -p specs/001-foo/.run .specify/scripts/bash .specify/memory

    # Minimal feature artifacts so prerequisites pass
    printf 'spec\n'  > specs/001-foo/spec.md
    printf 'plan\n'  > specs/001-foo/plan.md
    printf 'tasks\n' > specs/001-foo/tasks.md

    git add .
    git commit -m "initial" --quiet

    # Copy run helpers
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-common.sh"  .specify/scripts/bash/
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-lock.sh"    .specify/scripts/bash/
    cp "$BATS_TEST_DIRNAME/../../.specify/scripts/bash/run-postcheck.sh" .specify/scripts/bash/ 2>/dev/null || true

    POSTCHECK=".specify/scripts/bash/run-postcheck.sh"
    FEATURE="$REPO_ROOT_FIXTURE/specs/001-foo"

    ".specify/scripts/bash/run-lock.sh" acquire "$FEATURE"

    # Default stubs: both linters pass
    write_linter_stubs_clean
}

teardown() {
    rm -rf "$REPO_ROOT_FIXTURE"
}

# write_linter_stubs_clean — install passing stubs for both linters
write_linter_stubs_clean() {
    cat > .specify/scripts/bash/check-adr-crossrefs.sh << 'SH'
#!/usr/bin/env bash
echo "Checked: 0 decision records in .specify/memory"
echo "OK: all records have at least one reference from specs/"
exit 0
SH
    chmod +x .specify/scripts/bash/check-adr-crossrefs.sh

    cat > .specify/scripts/bash/check-prerequisites.sh << 'SH'
#!/usr/bin/env bash
# Stub: accept any args, always pass
exit 0
SH
    chmod +x .specify/scripts/bash/check-prerequisites.sh
}

# write_adr_stub_failing — make check-adr-crossrefs.sh report a missing ref
write_adr_stub_failing() {
    cat > .specify/scripts/bash/check-adr-crossrefs.sh << 'SH'
#!/usr/bin/env bash
echo "Missing inbound references (1):"
echo "  - ADR_001_title"
exit 2
SH
    chmod +x .specify/scripts/bash/check-adr-crossrefs.sh
}

# write_prereq_stub_failing — make check-prerequisites.sh report a missing plan
write_prereq_stub_failing() {
    cat > .specify/scripts/bash/check-prerequisites.sh << 'SH'
#!/usr/bin/env bash
echo "ERROR: plan.md not found" >&2
exit 1
SH
    chmod +x .specify/scripts/bash/check-prerequisites.sh
}

# write_subagent_record <stage> — append a minimal subagent-record to decisions-log.md
# with a claimed test file that may or may not exist on disk.
write_subagent_record_with_test_claim() {
    local stage="$1" test_path="$2"
    cat >> "$FEATURE/decisions-log.md" << EOF
## subagent-record:$stage · 2026-05-13T10:00:00Z

- author: subagent:$stage
- status: success
- run_id: test-run-id

stage rationale.

### artifacts_written

- specs/001-foo/plan.md
- $test_path

### decisions_made

-

### halt_directive

- halt: false

EOF
}

# -------------------------------------------------------------------
# Usage errors
# -------------------------------------------------------------------

@test "missing feature-dir arg → exit 2" {
    run "$POSTCHECK"
    [ "$status" -eq 2 ]
}

@test "missing stage arg → exit 2" {
    run "$POSTCHECK" "$FEATURE"
    [ "$status" -eq 2 ]
}

@test "feature-dir does not exist → exit 2" {
    run "$POSTCHECK" "/nonexistent/feature" implement
    [ "$status" -eq 2 ]
}

# -------------------------------------------------------------------
# Non-code stages (out of scope per LOG-010)
# -------------------------------------------------------------------

@test "non-code stage (specify) → exit 0, 'postcheck: no findings'" {
    run "$POSTCHECK" "$FEATURE" specify
    [ "$status" -eq 0 ]
    [ "$output" = "postcheck: no findings" ]
}

@test "non-code stage (plan) → exit 0, 'postcheck: no findings'" {
    run "$POSTCHECK" "$FEATURE" plan
    [ "$status" -eq 0 ]
    [ "$output" = "postcheck: no findings" ]
}

# -------------------------------------------------------------------
# Clean pass (all linters pass)
# -------------------------------------------------------------------

@test "implement stage, all checks pass → exit 0, exactly 'postcheck: no findings'" {
    run "$POSTCHECK" "$FEATURE" implement
    [ "$status" -eq 0 ]
    [ "$output" = "postcheck: no findings" ]
}

@test "codereview stage, all checks pass → exit 0, 'postcheck: no findings'" {
    run "$POSTCHECK" "$FEATURE" codereview
    [ "$status" -eq 0 ]
    [ "$output" = "postcheck: no findings" ]
}

@test "audit stage, all checks pass → exit 0, 'postcheck: no findings'" {
    run "$POSTCHECK" "$FEATURE" audit
    [ "$status" -eq 0 ]
    [ "$output" = "postcheck: no findings" ]
}

# -------------------------------------------------------------------
# No-findings banner is EXACTLY the neutral line (LOG-013 MUST)
# -------------------------------------------------------------------

@test "clean exit banner contains no iconography (no checkmark, emoji, or 'all checks passed')" {
    run "$POSTCHECK" "$FEATURE" implement
    # Must not contain ✓, ✔, emoji-style affirmations, or 'all checks passed'
    echo "$output" | grep -qv "✓\|✔\|all checks passed\|All checks"
    [ "$output" = "postcheck: no findings" ]
}

# -------------------------------------------------------------------
# Linter failures produce findings (exit 1)
# -------------------------------------------------------------------

@test "adr-crossrefs failure → exit 1, finding line contains 'adr-crossrefs'" {
    write_adr_stub_failing
    run "$POSTCHECK" "$FEATURE" implement
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "adr-crossrefs"
}

@test "prerequisites failure → exit 1, finding line contains 'prerequisites'" {
    write_prereq_stub_failing
    run "$POSTCHECK" "$FEATURE" implement
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "prerequisites"
}

# -------------------------------------------------------------------
# implement stage: claimed-test-files cross-check (git ls-files)
# -------------------------------------------------------------------

@test "implement: claimed test file present in git ls-files → exit 0" {
    git add tests/unit/test_foo.bats 2>/dev/null || true
    mkdir -p tests/unit
    printf 'bats test\n' > tests/unit/test_foo.bats
    git add tests/unit/test_foo.bats
    git commit -m "add test" --quiet
    write_subagent_record_with_test_claim implement "tests/unit/test_foo.bats"
    run "$POSTCHECK" "$FEATURE" implement
    [ "$status" -eq 0 ]
    [ "$output" = "postcheck: no findings" ]
}

@test "implement: claimed test file missing from git ls-files → exit 1, finding" {
    write_subagent_record_with_test_claim implement "tests/unit/test_missing.bats"
    run "$POSTCHECK" "$FEATURE" implement
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "claimed-tests"
}

@test "codereview stage: no test-file cross-check even if record is present" {
    write_subagent_record_with_test_claim codereview "tests/unit/test_missing.bats"
    run "$POSTCHECK" "$FEATURE" codereview
    [ "$status" -eq 0 ]
    [ "$output" = "postcheck: no findings" ]
}

# -------------------------------------------------------------------
# Findings format
# -------------------------------------------------------------------

@test "failure finding format is '<check>: <detail>' (colon-space)" {
    write_adr_stub_failing
    run "$POSTCHECK" "$FEATURE" implement
    echo "$output" | grep -qE "^[a-z-]+: .+"
}
