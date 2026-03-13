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
.claude/commands/       # Spec-Kit slash commands for Claude
.specify/
  memory/
    constitution.md     # Project principles — Claude reads this for every feature
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

1. `/speckit.specify` — write user stories and requirements
2. `/speckit.clarify` *(optional)* — resolve ambiguities before planning
3. `/speckit.plan` — technical approach and project structure
4. `/speckit.checklist` *(optional)* — validate spec quality
5. `/speckit.tasks` — actionable task list
6. `/speckit.analyze` *(optional)* — cross-artifact consistency check
7. `/speckit.implement` — execute tasks

Feature specs live in `specs/[###-feature-name]/`.

## Key Conventions

- Branch naming: `###-feature-name` (e.g., `001-user-auth`)
- Commit after each completed task
- No credentials or secrets in source — use environment variables
- See `.specify/memory/constitution.md` for full governing principles

## Recent Changes

<!-- Update this as features are completed -->

- 2026-03-13: Initial project setup with Spec-Kit v0.3.0
