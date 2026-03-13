# ClaudeTest

This repository is set up with [GitHub Spec Kit](https://github.com/github/spec-kit) for Spec-Driven Development with Claude.

## Setup

Spec-Kit is installed globally via `uv`:

```bash
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
```

## Usage with Claude

The following slash commands are available in Claude Code:

| Command | Description |
|---|---|
| `/speckit.constitution` | Establish project governing principles |
| `/speckit.specify` | Define requirements and user stories |
| `/speckit.clarify` | *(optional)* Ask structured questions to de-risk ambiguous areas |
| `/speckit.plan` | Create technical implementation strategy |
| `/speckit.checklist` | *(optional)* Generate quality checklists |
| `/speckit.tasks` | Generate actionable task lists |
| `/speckit.analyze` | *(optional)* Cross-artifact consistency & alignment report |
| `/speckit.implement` | Execute all tasks to build features |
| `/speckit.taskstoissues` | Convert tasks to GitHub issues |

## Workflow

1. Run `/speckit.constitution` to define project principles
2. Run `/speckit.specify` to capture requirements
3. Run `/speckit.plan` to create an implementation plan
4. Run `/speckit.tasks` to break work into tasks
5. Run `/speckit.implement` to build the features

## Structure

```
.claude/commands/   # Claude slash command definitions
.specify/
  memory/           # Project constitution and context
  scripts/          # Helper shell scripts
  templates/        # Document templates
```
