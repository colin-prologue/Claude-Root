# [PROJECT_NAME] Constitution

## Core Principles

### I. Specification Before Implementation

All features begin with a written specification reviewed and approved before any code is written.
Ambiguity must be resolved upfront via `/speckit.clarify` — not during implementation.
Specs live in `specs/[###-feature-name]/spec.md` and are the source of truth.

### II. Simplicity (NON-NEGOTIABLE)

Build only what is explicitly required. No speculative abstractions, no premature generalization.
- Three similar lines of code is better than a premature abstraction
- No helpers, utilities, or wrappers for one-time operations
- No backwards-compatibility shims unless supporting an existing public interface
- Complexity must be justified in the plan's Complexity Tracking table

### III. Test-First Where Tests Are Requested

When tests are part of the spec, follow Red-Green-Refactor strictly:
1. Write tests → confirm they fail → implement → confirm they pass
Never write implementation code before a failing test exists for it.
Test scope: unit tests for pure logic, integration tests for system boundaries.

### IV. Incremental & Independent Delivery

Each user story is a deployable increment. P1 stories must be functional before P2 begins.
Features are complete when the independent test in the spec passes — not when all stories are done.
Commit after each completed task. Branch per feature (`###-feature-name` format).

### V. Security by Default

- No credentials, tokens, or secrets in source files or commits
- Validate all external input at system boundaries; trust internal code
- `.gitignore` must cover all agent/IDE credential paths before first commit
- Prefer environment variables for all configuration that varies by environment

### VI. [PROJECT-SPECIFIC PRINCIPLE]
<!-- Replace this section with principles specific to your project's domain,
     stack, or quality requirements. Examples:
     - VI. API Contracts: All endpoints defined in contracts/ before implementation
     - VI. Mobile-First: Every UI decision validated on smallest supported screen size
     - VI. Library-First: Every feature starts as a standalone, independently testable library -->

[PRINCIPLE_DESCRIPTION]

## Development Workflow

### Branch Strategy

- `main` — stable, always deployable
- `###-feature-name` — one branch per feature spec (e.g., `001-user-auth`)
- Branch from `main`; merge only after independent test passes

### Task Execution

- Work tasks in priority order (P1 → P2 → P3) unless marked `[P]` for parallel execution
- Mark tasks complete in `specs/[###]/tasks.md` as you finish them
- Stop at each Phase checkpoint to validate independently before continuing

### Definition of Done

A feature is done when:
1. All tasks in `tasks.md` are checked off
2. The independent test from `spec.md` passes
3. `CLAUDE.md` reflects any new commands, dependencies, or structure changes
4. Branch is merged and deleted

## Governance

This constitution supersedes all other practices in this repository.
Amendments require updating this file, noting the change in git commit message.
All specs and plans must verify compliance with these principles before implementation begins.

**Version**: 1.0.0 | **Ratified**: [RATIFICATION_DATE] | **Last Amended**: [RATIFICATION_DATE]
