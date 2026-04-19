# User Conventions

This file is loaded at the start of every session. Keep it short and stable — project-specific rules belong in each repo's `CLAUDE.md`.

## Platform

- Windows 11, running commands through git-bash. Use Unix shell syntax in `Bash` tool calls (`/dev/null`, forward slashes), not cmd or PowerShell.
- Primary work: AI agents, Claude-powered tooling, web frontends (JS/TS), occasional C++. Rarely Python.

## Git Workflow

- **Every project uses branch protection on `main`.** Never push directly to `main` — it will be rejected. Always work on a named branch and open a PR.
- **Commit to a branch early and often.** Work lives on branches so it syncs across machines via `origin`. If a branch has more than ~15 file edits without a checkpoint commit, create one before continuing.
- **Conventional commits**: `feat(scope): ...`, `fix(scope): ...`, `refactor:`, `docs:`, `chore:`, `test:`. Keep the first line under 72 characters; put detail in the body.
- **Never amend published commits** (anything already pushed). Always create a new commit instead.
- When merging PRs, prefer `gh pr merge --squash` unless the branch has meaningfully distinct commits worth preserving.

## Agentic Safety

Global PreToolUse and Stop hooks enforce safeguards from `~/.claude/hooks/`. **Do not try to work around them.** If a hook blocks an action:
1. Assume the block is correct and pick a safer path.
2. If the block is wrong, tell the user — don't rewrite the command to bypass the pattern.

Hard-blocked patterns include `rm -rf`, `git reset --hard`, force push, `git clean -f`, `sudo`, `chmod 777`, `curl|bash`, `DROP TABLE`, `TRUNCATE`, unbounded `DELETE FROM`. Warnings (non-blocking) on edits to `.env`/credentials and debug artifacts in source.

## Working Style

- **Concise over verbose.** Short status updates between tool calls, tight end-of-turn summaries (1-2 sentences). No narrated thinking, no recapping diffs.
- **Ask before irreversible or shared-state actions.** Branch protection, git pushes, PR merges, messages to external services, destructive database operations. Local reversible edits don't need approval.
- **Prefer editing to creating.** Don't add docs, READMEs, or planning files unless asked.
- **Verify before claiming done.** Type checking and test suites verify code correctness, not feature correctness — if you can't actually exercise the feature, say so.

## Task Context

- `/help` for Claude Code help; feedback via https://github.com/anthropics/claude-code/issues.
- This conventions file supersedes conflicting skill defaults. Project-level `CLAUDE.md` supersedes this file.
