---
description: Detect and repair branching-rule mismatches (local git config, pre-push hook, branching.md, and GitHub branch protection). Idempotent — safe to run on greenfield or existing projects.
handoffs:
  - label: Initialize Template
    agent: speckit.init
    prompt: Finish initializing the spec-kit template in this repo
  - label: Audit Repository
    agent: speckit.audit
    prompt: Run a full audit after branching setup
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

Supported flags:
- `--check` — read-only scan, produce report only, do not repair
- `--repair` — apply all auto-fixable mismatches without prompting (keeps
  prompts for destructive ops: renaming branches, deleting stale branches)
- `--remote-only` — skip local checks, focus on GitHub rules
- `--local-only` — skip GitHub checks (useful offline)

## Goal

Bring a repository into compliance with the spec-kit branching convention
documented in `.claude/rules/branching.md`. Works in two directions:

1. **Greenfield**: new project adopting the template — install everything
2. **Repair**: existing project that has drifted — fix only what's broken

The command is non-destructive by default: it reports mismatches and asks
before applying each fix. Pass `--repair` for batch mode.

## Prerequisites

1. Git repository (`.git/` exists)
2. `gh` CLI installed and authenticated (only needed for remote checks).
   If missing, remote checks degrade to read-only via GitHub MCP where
   available and print manual remediation URLs.

## Execution Steps

### 1. Parse Flags and Determine Scope

Parse `$ARGUMENTS` for `--check`, `--repair`, `--remote-only`, `--local-only`.
Default (no flags): interactive scan + repair with per-fix prompts.

Determine the repo's `origin` remote URL to build GitHub paths:

```bash
git remote get-url origin
# e.g., https://github.com/colin-prologue/claude-root.git → owner=colin-prologue, repo=claude-root
```

Store as `OWNER` and `REPO`. If `origin` is missing or non-GitHub, skip remote
checks and report.

### 2. Local Scan — Collect Evidence

Run each check and store findings in a `MISMATCHES` table with:
- `id` (short slug)
- `severity` (CRITICAL / HIGH / MEDIUM / LOW)
- `category` (local-git / hook / rules-file / naming / stale)
- `current` (what's there now)
- `expected` (what should be there)
- `auto_fix` (boolean)
- `fix_command` (bash/instruction)

**Local checks:**

| ID | Severity | What to check |
|----|----------|---------------|
| `default-branch-master` | HIGH | `git symbolic-ref refs/remotes/origin/HEAD` or `git branch --list master` shows master instead of main |
| `pre-push-missing` | HIGH | `.git/hooks/pre-push` does not exist or does not contain the marker `spec-kit pre-push hook` |
| `pre-push-stale` | MEDIUM | Hook exists but content differs from `.specify/templates/hooks/pre-push` |
| `pre-push-not-executable` | HIGH | Hook file exists but is not `chmod +x` |
| `rules-file-missing` | HIGH | `.claude/rules/branching.md` does not exist |
| `rules-file-stale` | MEDIUM | Hash of `.claude/rules/branching.md` differs from the canonical version (see "Canonical Hashes" below) |
| `protection-template-missing` | LOW | `.specify/templates/github/branch-protection.json` missing (needed for remote fix) |
| `current-branch-naming` | MEDIUM | Current branch name does not match any prefix in the convention table |
| `stale-branches` | LOW | Local branches with no commits in >30 days (report only; user decides) |

**How to check hook freshness**: compute SHA256 of `.git/hooks/pre-push` and
compare to SHA256 of `.specify/templates/hooks/pre-push`. If the template
doesn't exist yet, fall back to checking for the marker string.

**How to check branch naming**: the current branch must match one of these
regex patterns:
- `^[0-9]{3}-[a-z0-9-]+$` — spec-kit feature
- `^(fix|chore|spike|docs|claude)/[a-z0-9./-]+$` — typed prefix
- `^main$` — base branch (fine to be on main)

### 3. Remote Scan — Collect GitHub Evidence

Skip this section if `--local-only` or no `origin` remote. Use GitHub MCP
tools where available; fall back to `gh api` commands where not.

**Remote checks:**

| ID | Severity | What to check |
|----|----------|---------------|
| `default-branch-remote` | HIGH | Repo default branch (from `mcp__github__search_repositories` or `gh api repos/:owner/:repo`) is not `main` |
| `main-protection-missing` | CRITICAL | No branch protection on main. Check via `gh api repos/:owner/:repo/branches/main/protection` — a 404 means no protection |
| `pr-reviews-not-required` | HIGH | Protection exists but `required_pull_request_reviews` is null or count < 1 |
| `admin-bypass-allowed` | HIGH | `enforce_admins.enabled` is false |
| `force-push-allowed` | MEDIUM | `allow_force_pushes.enabled` is true |
| `deletions-allowed` | MEDIUM | `allow_deletions.enabled` is true |
| `conversation-resolution-off` | LOW | `required_conversation_resolution.enabled` is false |

**MCP tool usage**: prefer `mcp__github__*` tools where they cover the check.
For branch-protection specifics (which MCP does not cover), generate a
`gh api` command instead of attempting the call.

### 4. Produce Mismatch Report

If `MISMATCHES` is empty, output:

```
✅ Branching rules are in compliance.
   Last checked: <timestamp>
   Repo: <OWNER>/<REPO>
   Branch: <current-branch>
```

Otherwise, group by severity and print:

```
🔍 Branching Compliance Report
   Repo: <OWNER>/<REPO>  Branch: <current-branch>

🚨 CRITICAL (1)
   [main-protection-missing] GitHub main branch has no protection rule
     Current: no rule exists
     Expected: PR required, 1 review, admin-enforced, no force push, no deletion
     Auto-fix: NO (requires gh CLI)

⚠️  HIGH (2)
   [pre-push-missing] Local pre-push hook is not installed
     Current: .git/hooks/pre-push does not exist
     Expected: blocks direct push to main
     Auto-fix: YES

   ...

Total: N mismatches (X auto-fixable, Y manual)
```

### 5. Interactive Repair Loop

If `--check`: stop here and exit with the report.

Otherwise, for each mismatch in severity order (CRITICAL → LOW):

1. Print the mismatch detail block
2. If `auto_fix: true`:
   - Default mode: ask "Apply fix? [y/N/q]"
   - `--repair` mode: apply without asking
3. If `auto_fix: false`: print `fix_command` with copy-paste instructions
4. `q` at any prompt quits the repair loop (already-applied fixes are kept)

**Auto-fix procedures:**

| Mismatch ID | Repair action |
|-------------|---------------|
| `default-branch-master` | `git branch -M main && git push -u origin main` (prompt for remote rename confirmation) |
| `pre-push-missing` | `cp .specify/templates/hooks/pre-push .git/hooks/pre-push && chmod +x .git/hooks/pre-push`. If the template file is missing, copy from the canonical version embedded in this command (see "Canonical Template Content" below). |
| `pre-push-stale` | Show diff, ask to overwrite, then `cp` + `chmod +x` |
| `pre-push-not-executable` | `chmod +x .git/hooks/pre-push` |
| `rules-file-missing` | Create `.claude/rules/branching.md` from the canonical version in `.specify/templates/` or emit it inline |
| `rules-file-stale` | Show diff, ask to overwrite |
| `protection-template-missing` | Write `.specify/templates/github/branch-protection.json` from the canonical inline content below |
| `current-branch-naming` | Suggest `git branch -m <new-name>` with a guessed name (ask for confirmation); purely advisory |
| `stale-branches` | Print list, offer `git branch -D <name>` per branch after confirmation |

**Remote-fix procedures (always manual — gh CLI):**

| Mismatch ID | Remediation output |
|-------------|-------------------|
| `default-branch-remote` | `gh api repos/<OWNER>/<REPO> --method PATCH -f default_branch=main` plus UI link |
| `main-protection-missing` or `*-allowed` or `*-missing` | Single consolidated command: `gh api repos/<OWNER>/<REPO>/branches/main/protection --method PUT --input .specify/templates/github/branch-protection.json` |
| `admin-bypass-allowed` | Same as above (protection template enforces admins) |
| `pr-reviews-not-required` | Same as above |

For every remote fix, also emit a direct settings URL:
`https://github.com/<OWNER>/<REPO>/settings/branches`

### 6. Final Summary

Print a summary table:

```
Summary
─────────────
Fixed:        N (list of IDs)
Skipped:      M (list of IDs)
Manual:       P (list of IDs, each with the command to run)
Stale reported: Q branches flagged for review
```

If manual fixes remain, print the consolidated gh commands block ready to
copy-paste:

```bash
# Run these to bring GitHub into compliance:

gh api repos/<OWNER>/<REPO>/branches/main/protection \
  --method PUT \
  --input .specify/templates/github/branch-protection.json

# Or visit: https://github.com/<OWNER>/<REPO>/settings/branches
```

### 7. Optional: Store in Memory Server

If the memory MCP is available, store a summary chunk:

```
memory_store(
  content="Branching compliance check: <N> mismatches, <M> fixed, <P> manual",
  metadata={
    "source_file": "synthetic",
    "section": "speckit.branching summary",
    "type": "synthetic",
    "tags": ["branching", "compliance"],
    "date": "<ISO date>"
  }
)
```

## Operating Principles

### Idempotent

Running the command twice is safe. Already-compliant items are skipped. Hook
and rules file installs use templated content, not appends.

### Non-Destructive by Default

Renaming branches, deleting stale branches, and overwriting diverged files
always require explicit confirmation — even in `--repair` mode.

### Local Changes Never Touch Main

All file modifications (hook install, rules file creation, template scaffolding)
happen on the current branch. If the current branch is `main`, the command
stops with an error: "Switch to a working branch first — this command modifies
files and those changes need to land via PR."

### Remote Changes Are Always Manual

The command never executes `gh api` or any destructive remote call itself. It
prints the command for the user to run. This preserves the principle that
changes to shared repo configuration are explicitly authorized.

### MCP Scope Awareness

This command's GitHub MCP access is scoped. If the current repo is outside
the allowed scope (per the MCP server config), remote checks fall back
entirely to `gh api` commands that the user runs outside Claude.

### Canonical Template Content (Fallback)

If `.specify/templates/hooks/pre-push` is missing when the command tries to
install it, use the embedded content below verbatim:

```sh
#!/bin/sh
# Spec-Kit pre-push hook: enforce branching rules locally
protected_branch='main'
while read local_ref local_sha remote_ref remote_sha
do
  zero='0000000000000000000000000000000000000000'
  [ "$local_sha" = "$zero" ] && continue
  remote_branch=$(echo "$remote_ref" | sed 's|refs/heads/||')
  if [ "$remote_branch" = "$protected_branch" ]; then
    echo "🚫 Direct push to '$protected_branch' is blocked."
    echo "   See .claude/rules/branching.md. Open a PR instead."
    exit 1
  fi
done
exit 0
```

If `.specify/templates/github/branch-protection.json` is missing, emit the
canonical JSON from this command's section on branch-protection and also
scaffold it at that path for future runs.

## Relationship to Other Commands

- `/speckit.init`: sets up the full template; may call `/speckit.branching`
  during initialization, or the user runs it as a follow-up.
- `/speckit.audit`: relies on branch protection to guarantee that
  `git diff main...HEAD` is a complete unit of work for diff-scoped audits.
- `/speckit.codereview`: same dependency as audit.

## Context

$ARGUMENTS
