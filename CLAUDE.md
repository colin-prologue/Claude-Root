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

<!-- Update this as features are completed -->

- 2026-04-06: Added /speckit.codereview — adversarial code review panel (code-reviewer agent, LIGHTWEIGHT default) at step 12 between implement and audit
- 2026-03-28: Added /speckit.retro for post-implementation retrospectives
- 2026-03-28: Added /speckit.brainstorm for pre-specify ideation and feature decomposition
- 2026-03-28: Split CLAUDE.md into modular .claude/rules/ structure
- 2026-03-28: Added consistency audit system (/speckit.audit + consistency-auditor agent)
- 2026-03-28: Added adversarial review system (/speckit.review + agent personas)
- 2026-03-28: Rewrote /speckit.constitution as interactive guided conversation with project context
- 2026-03-28: Added Agent Teams support (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)
- 2026-03-22: Audit and cleanup — renamed to Spec-Kit Base, filled CLAUDE.md/README placeholders, added .speckit-version, added .specify/conventions/
- 2026-03-13: Initial project setup with Spec-Kit v0.3.0
