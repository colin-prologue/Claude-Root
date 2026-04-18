---
memory_enabled: true  # Set to false to disable all memory_recall/memory_store calls in speckit skills
---
# [PROJECT_NAME] Constitution

## Project Context

### Project Identity

- **Name**: [PROJECT_NAME]
- **Purpose**: [PROJECT_PURPOSE]
- **Status**: [PROJECT_STATUS]
- **Domain**: [PROJECT_DOMAIN]

### Development Team

- **Size**: [TEAM_SIZE]
- **Expertise**: [TEAM_EXPERTISE]
- **Turnover**: [TEAM_TURNOVER]
- **Collaboration style**: [TEAM_COLLABORATION]

### Content & Maintenance

- **Content creators**: [CONTENT_CREATORS]
- **Update cadence**: [UPDATE_CADENCE]
- **Operational ownership**: [OPERATIONAL_OWNERSHIP]

### Audience

- **Scale**: [AUDIENCE_SCALE]
- **Diversity**: [AUDIENCE_DIVERSITY]
- **Accessibility needs**: [ACCESSIBILITY_NEEDS]
- **Geography**: [AUDIENCE_GEOGRAPHY]
- **Trust level**: [AUDIENCE_TRUST]

### Stakes & Constraints

- **Data sensitivity**: [DATA_SENSITIVITY]
- **Availability needs**: [AVAILABILITY_NEEDS]
- **Compliance**: [COMPLIANCE_REQUIREMENTS]
- **Blast radius if broken**: [BLAST_RADIUS]

## Governing Principles

<!-- Each principle is assigned a rigor level based on the Project Context above.
     FULL = non-negotiable, enforced at every gate
     STANDARD = apply consistently but proportionally
     LIGHTWEIGHT = acknowledge, adapt to project scale
     Rigor levels are set during /speckit.constitution and inform
     agent review intensity during /speckit.review. -->

### I. Specification Before Implementation [RIGOR: [PRINCIPLE_I_RIGOR]]

All features begin with a written specification reviewed and approved before any code is written.
Ambiguity MUST be resolved upfront via `/speckit.clarify` — not during implementation.
Specs live in `specs/[###-feature-name]/spec.md` and are the source of truth.

Before any plan or approach is agreed upon, take multiple critical passes:
1. Challenge every assumption — ask "what if this is wrong?"
2. Stress-test the research — verify sources, look for contradictions
3. Scrutinize the plan — identify the riskiest decision and validate it first
An approach is not agreed upon until it has survived at least two independent reviews.

### II. Simplicity [RIGOR: [PRINCIPLE_II_RIGOR]]

Build only what is explicitly required. No speculative abstractions, no premature generalization.
- Three similar lines of code is better than a premature abstraction
- No helpers, utilities, or wrappers for one-time operations
- No backwards-compatibility shims unless supporting an existing public interface
- Every task MUST be single-purpose — one clear, well-scoped change per task
- Complexity MUST be justified in the plan's Complexity Tracking table

### III. Test-Driven Development [RIGOR: [PRINCIPLE_III_RIGOR]]

[TDD_DESCRIPTION]

### IV. Incremental & Independent Delivery [RIGOR: [PRINCIPLE_IV_RIGOR]]

Each user story is a deployable increment. P1 stories MUST be functional before P2 begins.
Features are complete when the independent test in the spec passes — not when all stories are done.
Commit after each completed task. Branch per feature (`###-feature-name` format).

### V. Security by Default [RIGOR: [PRINCIPLE_V_RIGOR]]

- No credentials, tokens, or secrets in source files or commits
- Validate all external input at system boundaries; trust internal code
- `.gitignore` MUST cover all agent/IDE credential paths before first commit
- Prefer environment variables for all configuration that varies by environment
[SECURITY_ADDITIONS]

### VI. Documentation Stays Current [RIGOR: [PRINCIPLE_VI_RIGOR]]

[DOCUMENTATION_DESCRIPTION]

### VII. Decision Transparency [RIGOR: [PRINCIPLE_VII_RIGOR]]

Every architectural decision and every significant challenge, question, or update MUST be recorded
as a discrete memory file. The goal is a complete history of *why* — not just *what was decided*.

**Architectural Decision Records (ADRs)**
- Any decision about technology choice, system structure, data model, integration pattern,
  or cross-cutting constraint MUST produce an `ADR_NNN_title.md` file.
- ADRs live in `.specify/memory/` and are numbered sequentially (`ADR_001_`, `ADR_002_`, ...).
- The spec or plan where the decision was made MUST include a reference to the ADR number.
- Use `.specify/templates/adr-template.md` as the starting point.

**Decision Logs (LOGs)**
- Any significant challenge encountered, open question raised, or update to an earlier
  understanding MUST produce a `LOG_NNN_title.md` file.
- LOGs live in `.specify/memory/` and are numbered sequentially (`LOG_001_`, `LOG_002_`, ...).
- A LOG may exist before its resolution — open logs are valid and expected during planning.
- When a LOG leads to a decision, it MUST reference the resulting ADR, and the ADR MUST
  reference the LOG.
- The spec, plan, or task where the issue surfaced MUST include a reference to the LOG number.
- Use `.specify/templates/log-template.md` as the starting point.

**Cross-referencing rule**: a decision or log entry without a back-reference in the relevant
spec, plan, or task is incomplete. Both ends of the link MUST exist.

### VIII. Adversarial Review [RIGOR: [PRINCIPLE_VIII_RIGOR]]

[ADVERSARIAL_REVIEW_DESCRIPTION]

[ADDITIONAL_PRINCIPLES]

## Development Workflow

### Branch Strategy

- `main` — stable, always deployable, MUST be the default branch
- `###-feature-name` — one branch per feature spec (e.g., `001-user-auth`)
- Branch from `main`; merge only after independent test passes
- New repositories MUST initialize with `main` as the first branch and commit
  before creating feature branches (ensures GitHub recognizes `main` as default)

### Task Execution

- Every task MUST be single-purpose — one file, one concern, one reason to exist
- If a task description requires "and", split it into two tasks
- Work tasks in priority order (P1 → P2 → P3) unless marked `[P]` for parallel execution
- Mark tasks complete in `specs/[###]/tasks.md` as you finish them
- Stop at each Phase checkpoint to validate independently before continuing

### Decision Records

Naming and storage conventions:

| Type | File prefix | Location | Template |
|---|---|---|---|
| Architectural decision | `ADR_NNN_title.md` | `.specify/memory/` | `adr-template.md` |
| Challenge / Question / Update | `LOG_NNN_title.md` | `.specify/memory/` | `log-template.md` |

NNN is a zero-padded three-digit sequence shared across both types (ADR and LOG use the same
counter, so `ADR_001`, `LOG_002`, `ADR_003` — no two records share a number). This keeps the
timeline unambiguous.

When to create records:
- **ADR**: at the moment a significant architectural choice is made, before implementation proceeds
- **LOG (QUESTION)**: as soon as a significant unknown is identified during planning or research
- **LOG (CHALLENGE)**: when an obstacle is encountered that requires reconsidering a plan or spec
- **LOG (UPDATE)**: when an earlier understanding, spec section, or ADR needs revision

### Review Gates

Multi-persona adversarial review occurs at phase boundaries via `/speckit.review`.
Review panels are calibrated by the Project Context and principle rigor levels above.

| Gate | Review Panel | Trigger |
|---|---|---|
| Post-specify | Requirements Panel | After `/speckit.specify` completes |
| Post-plan | Architecture Panel | After `/speckit.plan` completes |
| Post-tasks | Delivery Panel | After `/speckit.tasks` completes |
| Pre-implement | Full Panel + Devil's Advocate | Before `/speckit.implement` begins |

Review output preserves majority findings, minority dissents, and unresolved items.
Unresolved items become LOGs. Architectural dissents may produce ADRs.

### PR Policy

- PRs MUST target [PR_LOC_LIMIT] lines of changed code or fewer
- If a feature exceeds the limit, split it into sequential, independently-mergeable PRs
  before implementation begins — not after
- Each PR must be self-contained: tests pass, no broken intermediary state
- Exceptions require explicit justification in the PR description

### Definition of Done

A feature is done when:
1. All tasks in `tasks.md` are checked off
2. The independent test from `spec.md` passes
3. All PRs are within LOC limits or exceptions are documented
4. All ADRs and LOGs raised during the feature are written and cross-referenced
5. `CLAUDE.md` reflects any new commands, dependencies, or structure changes
6. Adversarial review findings are addressed or documented as accepted risks
7. Branch is merged and deleted

## Governance

This constitution supersedes all other practices in this repository.
Amendments require updating this file with a version bump and noting the change in the git commit message.
All specs and plans MUST verify compliance with these principles before implementation begins.
Version policy: MAJOR for principle removal/redefinition; MINOR for new or materially expanded guidance;
PATCH for clarifications, wording, and non-semantic refinements.

**Version**: 1.0.0 | **Ratified**: [RATIFICATION_DATE] | **Last Amended**: [RATIFICATION_DATE]
