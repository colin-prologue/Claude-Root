# ClaudeTest

This repository is configured for Spec-Driven Development with Claude Code using [GitHub Spec Kit](https://github.com/github/spec-kit).

## Quick Start

```bash
# Install Spec-Kit CLI (one-time, global)
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git

# Start a new feature
# Open Claude Code and run:
/speckit.specify
```

## Directory Structure

```
.claude/
  commands/             # Spec-Kit slash commands (auto-loaded by Claude Code)
.specify/
  memory/
    constitution.md     # Governing principles — read by Claude for every feature
  templates/            # Document templates (spec, plan, tasks, checklist, agent)
  scripts/bash/         # Helper scripts used by slash commands
specs/                  # Feature documentation (created by slash commands)
  ###-feature-name/
    spec.md             # User stories & requirements  (/speckit.specify)
    plan.md             # Technical approach           (/speckit.plan)
    tasks.md            # Task checklist               (/speckit.tasks)
    research.md         # Research output              (/speckit.plan)
    data-model.md       # Data model                   (/speckit.plan)
    contracts/          # API contracts                (/speckit.plan)
src/                    # Application source code
tests/                  # Test suite
docs/                   # Long-form documentation
CLAUDE.md               # Project context — read by Claude at session start
README.md               # This file
```

## Spec-Kit Slash Commands

| Command | Purpose | When to run |
|---|---|---|
| `/speckit.constitution` | Edit project principles | Project setup or when principles change |
| `/speckit.specify` | Write user stories & requirements | Start of every feature |
| `/speckit.clarify` | Resolve ambiguities | Before planning (optional) |
| `/speckit.plan` | Technical approach & structure | After spec is approved |
| `/speckit.checklist` | Validate spec quality | After plan (optional) |
| `/speckit.tasks` | Generate task list | After plan is approved |
| `/speckit.analyze` | Cross-artifact consistency check | After tasks, before implementing (optional) |
| `/speckit.implement` | Execute tasks | After tasks are approved |
| `/speckit.taskstoissues` | Create GitHub issues from tasks | After tasks are generated (optional) |

## Feature Workflow

```
/speckit.specify  →  /speckit.plan  →  /speckit.tasks  →  /speckit.implement
       ↑                   ↑                  ↑
  /speckit.clarify   /speckit.checklist  /speckit.analyze
  (optional)         (optional)          (optional)
```

## Reusing This Template

To apply this structure to a new project:

1. Copy `.claude/`, `.specify/`, `CLAUDE.md`, `.gitignore`, and `specs/` into the new repo root
2. Update `CLAUDE.md` with the new project's name, stack, and commands
3. Run `/speckit.constitution` to tailor the principles if needed

## Constitution

Project principles are in `.specify/memory/constitution.md`. Key rules:

- Spec before code — no implementation without an approved spec
- Simplicity first — no speculative abstractions
- Test-first when tests are in scope (Red → Green → Refactor)
- Each user story is independently deliverable (P1 before P2)
- No secrets in source — environment variables only
