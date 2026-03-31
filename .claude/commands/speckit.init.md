---
description: Integrate or update the Spec-Kit template into the current repository. Smart merge for existing projects — adds missing files, preserves customizations, and reports what changed.
handoffs:
  - label: Set Up Constitution
    agent: speckit.constitution
    prompt: Set up the project constitution for this project...
  - label: Start Brainstorming
    agent: speckit.brainstorm
    prompt: I have an idea for this project...
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Goal

Integrate the Spec-Kit template structure into the current repository. This works for:
- **New repos**: Full installation of all template files
- **Existing repos**: Smart merge that adds missing files without overwriting customizations
- **Updates**: Refresh template files to the latest version while preserving local changes

## Execution Steps

### 1. Assess Current State

Scan the current repository to understand what exists:

```
Check for:
- .claude/commands/speckit.*.md — existing spec-kit commands
- .claude/agents/*.md — existing agent personas
- .claude/rules/*.md — existing rules files
- .specify/ — existing template infrastructure
- CLAUDE.md — existing project context
- .specify/memory/constitution.md — existing constitution
- specs/ — existing feature specs
- src/, tests/ — existing code
```

Classify the repo:
- **Fresh**: No spec-kit files exist → full installation
- **Partial**: Some spec-kit files exist → gap-fill installation
- **Complete**: All spec-kit files exist → update check
- **Customized**: Spec-kit files exist but have been modified → careful merge

### 2. Determine Source

If `$ARGUMENTS` specifies a source repo or branch, use that:
- `/speckit.init` — use default source (colin-prologue/Claude-Root@main)
- `/speckit.init from user/repo` — use specified repo
- `/speckit.init update` — refresh existing files to latest template version

For the default source, check if `setup.sh` exists in the current repo and read
the REPO/REF defaults from it.

### 3. Fetch Template

Run the setup script if available:
```bash
bash setup.sh --verbose
```

If `setup.sh` doesn't exist yet, fetch the template manually:
```bash
# Clone template to temp directory
git clone --depth 1 https://github.com/colin-prologue/Claude-Root.git /tmp/speckit-template
```

### 4. Smart Merge

For each category of files, apply the appropriate merge strategy:

#### Commands (`.claude/commands/speckit.*.md`)
**Strategy**: Add missing, don't overwrite existing.

- For each command in the template, check if it exists locally
- If missing: copy it in
- If exists: compare content. If identical, skip. If different, report as "locally modified"
- Present a summary: "Adding 3 new commands, skipping 10 existing (2 locally modified)"

#### Agents (`.claude/agents/*.md`)
**Strategy**: Add missing, don't overwrite existing.

- Same approach as commands
- Users may have custom agents — never delete or overwrite those
- Template agents have specific names; any agent not matching a template name is a custom agent

#### Rules (`.claude/rules/*.md`)
**Strategy**: Add missing, don't overwrite existing.

- Same approach as commands
- Custom rules are preserved

#### Templates (`.specify/templates/*.md`)
**Strategy**: Add missing, offer to update existing.

- Templates are less likely to be customized
- If different from template: ask "Update [file] to latest template? Your version differs. [y/N]"

#### Scripts (`.specify/scripts/bash/*.sh`)
**Strategy**: Always update (scripts should match template version).

- Scripts are infrastructure, not customization points
- Copy and make executable

#### CLAUDE.md
**Strategy**: NEVER overwrite. Merge missing sections.

- If CLAUDE.md doesn't exist: create from template
- If CLAUDE.md exists: scan for missing sections that the template provides
  - Missing "Directory Structure"? Offer to add it
  - Missing "Spec-Kit Workflow"? Note that it moved to `.claude/rules/workflow.md`
  - Missing "Recent Changes"? Offer to add it
- Present a merge report, not an automatic overwrite

#### Constitution (`.specify/memory/constitution.md`)
**Strategy**: NEVER overwrite. Create from template only if missing.

- If exists: skip entirely (this is the user's governance document)
- If missing: copy the template version as a starting point
- Remind user to run `/speckit.constitution` to customize it

#### Settings (`.claude/settings.local.json`)
**Strategy**: Create if missing, merge keys if exists.

- If missing: create with Agent Teams enabled
- If exists: check for `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` in env
  - If missing: offer to add it
  - If present: skip

#### Gitignore
**Strategy**: Append missing entries.

- Check if `.gitignore` contains `settings.local.json`
- If not: append the Spec-Kit entries
- Never remove existing entries

### 5. Git Initialization & Default Branch

Ensure the repository uses `main` as the default branch. This is critical for
new repos — GitHub sets the default branch based on the first push, so getting
this right from the start prevents confusion.

**If no `.git` directory exists** (new project):
```bash
git init -b main
```

**If `.git` exists but no commits yet** (freshly initialized):
```bash
git branch -M main
```

**If `.git` exists with commits on a non-main branch**:
- Warn the user: "Default branch is '[branch]', not 'main'. Consider renaming with `git branch -M main`."
- Do NOT auto-rename — the user may have a reason for a different default branch.

After setup is complete, suggest an initial commit to establish `main`:
```bash
git add .
git commit -m "chore: initialize project with Spec-Kit template"
git push -u origin main
```

This ensures GitHub recognizes `main` as the default branch.

### 6. Create Missing Directories

Ensure these directories exist (create with `.gitkeep` if empty):
- `specs/`
- `src/`
- `tests/`
- `docs/`
- `.specify/memory/`

### 6. Migration Report

Present a structured summary:

```markdown
## Spec-Kit Integration Report

### Files Created
- [list of new files]

### Files Skipped (already exist)
- [list with reason: "exists", "locally modified", "protected"]

### Files Updated
- [list of refreshed files]

### Locally Modified Files
These files differ from the template. Review manually if you want to
incorporate upstream changes:
- [file]: [brief description of difference]

### Missing Customization
These files need your input to be useful:
- CLAUDE.md: Update project name, stack, and commands
- .specify/memory/constitution.md: Run /speckit.constitution to customize

### Recommended Next Steps
1. [If no constitution] Run `/speckit.constitution` to set up governance
2. [If CLAUDE.md is template default] Update CLAUDE.md with your project details
3. [If no features yet] Run `/speckit.brainstorm` or `/speckit.specify`
4. [If features exist] Run `/speckit.audit` to check consistency
```

### 7. Commit Suggestion

If changes were made, suggest a commit:
```
chore: integrate Spec-Kit template (v[version])

Added [N] commands, [N] agents, [N] rules, [N] templates.
[N] existing files preserved.
```

Do NOT auto-commit. Present the suggestion and let the user decide.

## Update Mode

When the user runs `/speckit.init update`:

1. Fetch the latest template
2. Compare each template file against the local version
3. Categorize:
   - **Unchanged locally**: Safe to update to latest template
   - **Modified locally**: Show diff, ask user whether to update
   - **New in template**: Add automatically
   - **Removed from template**: Warn but don't delete locally
4. Present update plan before making any changes
5. Apply approved updates

## Behavior Rules

- NEVER overwrite CLAUDE.md or constitution.md without explicit user approval
- NEVER delete files that exist locally but not in the template
- NEVER auto-commit changes
- Always present a summary before making changes in update mode
- Custom agents, rules, and commands (files that don't match template names) are always preserved
- If the setup script exists and is functional, prefer using it over manual file operations

## Context

$ARGUMENTS
