# Spec-Kit Base

A reusable project template for spec-driven development with Claude Code. Copy it into any new project to get a structured workflow for writing specs, plans, tasks, and implementations.

## Quick Start

```bash
# One-time: install copier
pipx install copier

# Create a new project from this template
copier copy git+ssh://git@github.com/YOUR_USERNAME/spec-kit-base.git my-new-project
cd my-new-project
git init && git add . && git commit -m "chore: initialize from Spec-Kit Base"
```

Copier will prompt you for your project name, stack, and commands — it writes `CLAUDE.md` for you.

Then open Claude Code and start building:

```
/speckit.constitution   # optional: customize governing principles
/speckit.specify        # start your first feature
```

To pull in template updates later from inside any downstream project:

```bash
copier update
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

## Updating Downstream Projects

The template version is tracked in `.speckit-version`. When this template is updated, run
`copier update` from inside any downstream project — copier will apply template-owned changes
and prompt you to resolve conflicts in project-owned files.

### File Ownership

| File / Directory | Owner | On template update |
|---|---|---|
| `.claude/commands/` | Template | Safe to overwrite |
| `.specify/templates/` | Template | Safe to overwrite |
| `.specify/scripts/` | Template | Safe to overwrite |
| `.specify/conventions/` | Template | Safe to overwrite |
| `.speckit-version` | Template | Safe to overwrite |
| `CLAUDE.md` | Project | Merge manually |
| `.specify/memory/constitution.md` | Project | Merge manually |
| `specs/` | Project | Never touch |
| `.specify/memory/ADR_*.md` | Project | Never touch |
| `.specify/memory/LOG_*.md` | Project | Never touch |

## Constitution

Project principles are in `.specify/memory/constitution.md`. Key rules:

- Spec before code — no implementation without an approved spec
- Simplicity first — no speculative abstractions
- Test-first when tests are in scope (Red → Green → Refactor)
- Each user story is independently deliverable (P1 before P2)
- No secrets in source — environment variables only
