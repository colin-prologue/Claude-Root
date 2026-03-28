# CLAUDE.md

This file is read automatically by Claude Code at the start of every session.
Keep it current — update it whenever the stack, commands, or structure changes.

## Project

**Name**: ClaudeTest
**Description**: [One sentence describing what this project does]
**Status**: [e.g., Active development / Maintenance / Prototype]

## Stack

<!-- Update this section as you add dependencies -->

| Layer | Technology | Version |
|---|---|---|
| Language | [e.g., Python / TypeScript / Go] | [version] |
| Framework | [e.g., FastAPI / Next.js / Gin] | [version] |
| Database | [e.g., PostgreSQL / SQLite / None] | [version] |
| Testing | [e.g., pytest / vitest / go test] | [version] |
| Package manager | [e.g., uv / npm / go mod] | [version] |

## Commands

```bash
# Install dependencies
[command]

# Run tests
[command]

# Start dev server / run locally
[command]

# Lint / format
[command]

# Build / compile
[command]
```

## Directory Structure

```
.claude/
  commands/             # Spec-Kit slash commands for Claude
  agents/               # Agent persona definitions for /speckit.review
    security-reviewer.md
    systems-architect.md
    product-strategist.md
    devils-advocate.md
    delivery-reviewer.md
    synthesis-judge.md
    consistency-auditor.md
  settings.local.json   # Local settings (Agent Teams enabled)
.specify/
  memory/
    constitution.md     # Project principles + context — Claude reads this for every feature
  templates/            # Document templates for specs, plans, tasks
  scripts/              # Helper scripts used by slash commands
specs/                  # Feature specifications (one folder per feature)
  000-example/
    spec.md             # User stories and requirements
    plan.md             # Technical approach and project structure
    tasks.md            # Actionable task checklist
src/                    # Application source code
tests/                  # Test suite
docs/                   # Long-form documentation
CLAUDE.md               # This file — project context for Claude
README.md               # Human-facing project overview
```

## Spec-Kit Workflow

New features follow this order:

1. `/speckit.constitution` — interactive project setup (context + calibrated governance)
2. `/speckit.specify` — write user stories and requirements
3. `/speckit.review` *(recommended)* — adversarial review of spec
4. `/speckit.clarify` *(optional)* — resolve ambiguities before planning
5. `/speckit.plan` — technical approach and project structure
6. `/speckit.review` *(recommended)* — adversarial review of plan
7. `/speckit.checklist` *(optional)* — validate spec quality
8. `/speckit.tasks` — actionable task list
9. `/speckit.review` *(recommended)* — adversarial review of tasks
10. `/speckit.analyze` *(optional)* — cross-artifact consistency check
11. `/speckit.implement` — execute tasks
12. `/speckit.audit` *(recommended)* — bidirectional doc-code consistency audit

Feature specs live in `specs/[###-feature-name]/`.

### Adversarial Review System

`/speckit.review` spawns an Agent Team of specialized reviewers calibrated to the project context set in the constitution. Review panels vary by phase:

- **Spec gate**: product-strategist, security-reviewer, devils-advocate
- **Plan gate**: systems-architect, security-reviewer, delivery-reviewer, devils-advocate
- **Task gate**: delivery-reviewer, systems-architect, devils-advocate
- **Pre-implementation**: full panel

Reviews follow a three-phase anti-convergence protocol:
1. **Phase A** — Independent analysis (parallel, isolated)
2. **Phase B** — Cross-examination (devil's advocate challenges findings)
3. **Phase C** — Synthesis (judge integrates with preserved dissent)

Panel size scales with Principle VIII rigor level (FULL/STANDARD/LIGHTWEIGHT).

### Consistency Audit

`/speckit.audit` performs bidirectional doc-code scanning after implementation:
- **Docs → Code**: Are ADR decisions followed? Are spec requirements implemented?
- **Code → Docs**: Are dependencies documented? Do undocumented architectural decisions exist?
- **Decision Discovery**: Recommends new ADRs/LOGs for decisions hiding in code
- **Health Score**: Grades consistency across 5 dimensions (A-F scale)
- Supports focused modes: `decisions`, `freshness`, `compliance`

## Key Conventions

- Branch naming: `###-feature-name` (e.g., `001-user-auth`)
- Commit after each completed task
- No credentials or secrets in source — use environment variables
- See `.specify/memory/constitution.md` for full governing principles

## Recent Changes

<!-- Update this as features are completed -->

- 2026-03-28: Added consistency audit system (/speckit.audit + consistency-auditor agent)
- 2026-03-28: Added adversarial review system (/speckit.review + agent personas)
- 2026-03-28: Rewrote /speckit.constitution as interactive guided conversation with project context
- 2026-03-28: Added Agent Teams support (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)
- 2026-03-13: Initial project setup with Spec-Kit v0.3.0
