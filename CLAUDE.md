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
  commands/             # Spec-Kit slash commands (including speckit.run)
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
    bash/               # check-adr-crossrefs.sh, run-*.sh orchestrator helpers
specs/                  # Feature specifications (one folder per feature)
tests/
  unit/                 # Tier 1 bats tests (pre-commit, deterministic, no LLM calls)
  smoke/                # Tier 2 bats tests (pre-merge, real subagent dispatches, cost-capped)
    fixtures/           # Synthetic feature descriptions for smoke runs
benchmarks/             # Persistent benchmark fixtures (re-run to track improvement over time)
  review-panel/         # Panel efficiency benchmark — fixture + key + runs/
docs/                   # Long-form documentation
```

**bats-core** is a soft dependency — only required to run Tier 1 unit tests locally. Install with `brew install bats-core` (macOS) or `sudo apt-get install bats` (Linux). Not required to use the template or run the orchestrator.

## Key Conventions

- Branch naming: `###-feature-name` (e.g., `001-user-auth`)
- Commit format: conventional commits (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`)
- Commit after each completed task
- No credentials or secrets in source — use environment variables
- See `.specify/memory/constitution.md` for full governing principles

## Recent Changes
- 010-autonomous-workflow: `/speckit.run` orchestrator shipped — slash command + 9 bash helpers (`run-lock`, `run-completeness`, `run-target`, `run-route`, `run-emit-event`, `run-validate-entry`, `run-check-sandbox`, `run-postcheck`, `run-serialize`); canonical `decisions-log.md` + JSONL sidecar; 183 Tier 1 unit tests + 20-case Tier 2 smoke harness (pre-merge, cost-capped); V1 BLOCKING-everywhere
- 009-remove-memory-server: Extracted memory server to `archive/memory-server` branch + `v1.0-with-memory` tag; template now ships without MCP server dependency
- skill-plugin-optimization: `adr-crossref-check` skill + helper script, ADR-055 filter-predicate helpers, guardrail against `.decisions/` vocabulary drift
