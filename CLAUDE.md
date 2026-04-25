# CLAUDE.md

This file is read automatically by Claude Code at the start of every session.
Keep it lean — detailed rules live in `.claude/rules/`.

## Project

**Name**: ClaudeTest
**Description**: A spec-driven development template with multi-agent adversarial review and bidirectional consistency auditing.
**Status**: Active development

## Skills

| Skill | Trigger | Purpose |
|---|---|---|
| `adr-crossref-check` | "check ADR cross-references", "verify Principle VII" | Audits every ADR/LOG in `.specify/memory/` for at least one inbound reference from `specs/` |
| `writing-decision-records` | "write an ADR", "create a LOG" | Guided authoring of ADR/LOG files with correct format and cross-references |

## Directory Structure

```
.claude/
  commands/             # Spec-Kit slash commands
  agents/               # Agent personas for /speckit.review and /speckit.audit
  rules/                # Modular instruction files (loaded automatically)
  skills/               # Reusable skills (adr-crossref-check, writing-decision-records)
  settings.json         # Project-scope hooks and permissions
.specify/
  memory/
    constitution.md     # Project principles + context
    ADR_*.md            # Architectural decision records
    LOG_*.md            # Challenges, questions, updates
  templates/            # Document templates
  scripts/
    bash/               # check-adr-crossrefs.sh and other helpers
specs/                  # Feature specifications (one folder per feature)
docs/                   # Long-form documentation
```

## Key Conventions

- Branch naming: `###-feature-name` (e.g., `001-user-auth`)
- Commit format: conventional commits (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`)
- Commit after each completed task
- No credentials or secrets in source — use environment variables
- See `.specify/memory/constitution.md` for full governing principles

## Recent Changes
- 009-remove-memory-server: Extracted memory server to `archive/memory-server` branch + `v1.0-with-memory` tag; template now ships without MCP server dependency
- skill-plugin-optimization: `adr-crossref-check` skill + helper script, ADR-055 filter-predicate helpers, guardrail against `.decisions/` vocabulary drift
