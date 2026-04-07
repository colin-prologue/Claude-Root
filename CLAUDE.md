# CLAUDE.md

This file is read automatically by Claude Code at the start of every session.
Keep it lean — detailed rules live in `.claude/rules/`.

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
  commands/             # Spec-Kit slash commands
  agents/               # Agent personas for /speckit.review and /speckit.audit
  rules/                # Modular instruction files (loaded automatically)
  settings.local.json   # Local settings
.specify/
  memory/
    constitution.md     # Project principles + context
  templates/            # Document templates
  scripts/              # Helper scripts
specs/                  # Feature specifications (one folder per feature)
src/                    # Application source code
tests/                  # Test suite
docs/                   # Long-form documentation
```

## Key Conventions

- Branch naming: `###-feature-name` (e.g., `001-user-auth`)
- Commit format: conventional commits (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`)
- Commit after each completed task
- No credentials or secrets in source — use environment variables
- See `.specify/memory/constitution.md` for full governing principles

## Recent Changes
- 2026-04-03: Added `/speckit.review-profile` command — runs adversarial review against benchmark fixture with Panel Efficiency Report; supports `--compare` mode for FULL/STANDARD/LIGHTWEIGHT comparison
- 2026-04-03: Added benchmark fixture at `specs/000-review-benchmark/fixture/` (spec.md, plan.md, tasks.md), scoring key at `specs/000-review-benchmark/benchmark-key.md`, and run reports at `specs/000-review-benchmark/runs/`
- 2026-03-28: Added /speckit.retro for post-implementation retrospectives
- 2026-03-28: Added /speckit.brainstorm for pre-specify ideation and feature decomposition

<!-- Update this as features are completed -->

- 2026-04-06: Added /speckit.codereview — adversarial code review panel (code-reviewer agent, LIGHTWEIGHT default) at step 12 between implement and audit
- 2026-03-28: Added /speckit.retro for post-implementation retrospectives
- 2026-03-28: Added /speckit.brainstorm for pre-specify ideation and feature decomposition
