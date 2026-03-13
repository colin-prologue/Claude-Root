<!--
SYNC IMPACT REPORT
==================
Version change: 1.0.0 → 1.1.0 (MINOR)

Modified principles:
  - III. "Test-First Where Tests Are Requested" → "Test-Driven Development"
      Rationale: TDD is now a standing practice, not conditional on spec requests.
  - I. "Specification Before Implementation"
      Rationale: Added mandatory multi-pass review gate before any plan or approach is agreed.
  - II. "Simplicity"
      Rationale: Added explicit single-purpose task constraint.

Added sections:
  - Development Workflow › PR Policy (300 LOC target, rationale for exceptions)

Removed sections:
  - None

Templates updated:
  ✅ .specify/templates/constitution-template.md — principle III title + PR policy section added
  ✅ .specify/templates/tasks-template.md — single-purpose task note added to Format section
  ✅ .specify/templates/plan-template.md — multi-pass review gate added to Constitution Check

Follow-up TODOs:
  - None. All placeholders resolved.
-->

# Claude Project Constitution

## Core Principles

### I. Specification Before Implementation

All features begin with a written specification reviewed and approved before any code is written.
Ambiguity MUST be resolved upfront via `/speckit.clarify` — not during implementation.
Specs live in `specs/[###-feature-name]/spec.md` and are the source of truth.

Before any plan or approach is agreed upon, take multiple critical passes:
1. Challenge every assumption — ask "what if this is wrong?"
2. Stress-test the research — verify sources, look for contradictions
3. Scrutinize the plan — identify the riskiest decision and validate it first
An approach is not agreed upon until it has survived at least two independent reviews.

### II. Simplicity (NON-NEGOTIABLE)

Build only what is explicitly required. No speculative abstractions, no premature generalization.
- Three similar lines of code is better than a premature abstraction
- No helpers, utilities, or wrappers for one-time operations
- No backwards-compatibility shims unless supporting an existing public interface
- Every task MUST be single-purpose — one clear, well-scoped change per task
- Complexity MUST be justified in the plan's Complexity Tracking table

### III. Test-Driven Development

TDD is the default approach, not an option. Follow Red-Green-Refactor on every unit of work:
1. Write a failing test that captures the intended behaviour
2. Confirm it fails for the right reason
3. Write the minimum implementation to make it pass
4. Refactor under green

Never write implementation code before a failing test exists for it.
Test scope: unit tests for pure logic, integration tests for system boundaries.

### IV. Incremental & Independent Delivery

Each user story is a deployable increment. P1 stories MUST be functional before P2 begins.
Features are complete when the independent test in the spec passes — not when all stories are done.
Commit after each completed task. Branch per feature (`###-feature-name` format).

### V. Security by Default

- No credentials, tokens, or secrets in source files or commits
- Validate all external input at system boundaries; trust internal code
- `.gitignore` MUST cover all agent/IDE credential paths before first commit
- Prefer environment variables for all configuration that varies by environment

### VI. Documentation Stays Current

`CLAUDE.md` is the living project context — update it when the tech stack, commands, or structure changes.
Do not add inline comments to code unless the logic is genuinely non-obvious.
Specs and plans are the documentation for *why*; code is the documentation for *how*.

## Development Workflow

### Branch Strategy

- `main` — stable, always deployable
- `###-feature-name` — one branch per feature spec (e.g., `001-user-auth`)
- Branch from `main`; merge only after independent test passes

### Task Execution

- Every task MUST be single-purpose — one file, one concern, one reason to exist
- Work tasks in priority order (P1 → P2 → P3) unless marked `[P]` for parallel execution
- Mark tasks complete in `specs/[###]/tasks.md` as you finish them
- Stop at each Phase checkpoint to validate independently before continuing

### PR Policy

- PRs MUST target 300 lines of changed code or fewer
- If a feature exceeds 300 lines, split it into sequential, independently-mergeable PRs
  before implementation begins — not after
- Each PR must be self-contained: tests pass, no broken intermediary state
- Exceptions require explicit justification in the PR description

### Definition of Done

A feature is done when:
1. All tasks in `tasks.md` are checked off
2. The independent test from `spec.md` passes
3. All PRs are ≤ 300 LOC or exceptions are documented
4. `CLAUDE.md` reflects any new commands, dependencies, or structure changes
5. Branch is merged and deleted

## Governance

This constitution supersedes all other practices in this repository.
Amendments require updating this file with a version bump and noting the change in the git commit message.
All specs and plans MUST verify compliance with these principles before implementation begins.
Version policy: MAJOR for principle removal/redefinition; MINOR for new or materially expanded guidance;
PATCH for clarifications, wording, and non-semantic refinements.

**Version**: 1.1.0 | **Ratified**: 2026-03-13 | **Last Amended**: 2026-03-13
