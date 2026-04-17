# Branching Rules

Canonical branching conventions for the spec-kit template. Rules are enforced
locally (via `.git/hooks/pre-push`) and remotely (via GitHub branch protection).
Run `/speckit.branching` to detect drift or install missing pieces.

## Default Branch

- Default branch MUST be `main` (never `master`)
- New repos: `git init -b main`
- Migrate: `git branch -M main && git push -u origin main`

## Direct Commits to main Are Forbidden

- All changes to `main` come through pull requests
- No direct pushes — enforced by:
  1. Local `pre-push` hook (defense against local mistakes)
  2. GitHub branch protection (defense against bypassed hooks)
- Bypass only in documented emergencies (`git push --no-verify`) + LOG entry

## Branch Naming Convention

| Prefix | Purpose | Example |
|--------|---------|---------|
| `###-` | Spec-Kit features (sequential) | `006-memory-export` |
| `fix/` | Bug fixes | `fix/null-pointer-in-sync` |
| `chore/` | Maintenance, deps, cleanup | `chore/bump-pytest` |
| `spike/` | Time-boxed investigations | `spike/lancedb-performance` |
| `docs/` | Documentation-only changes | `docs/update-readme` |
| `claude/` | Claude Code session branches | `claude/research-foo-bar` |

Any other prefix triggers a warning from `/speckit.branching` and the pre-push
hook.

## Pull Request Requirements

- PR title follows conventional commits (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`)
- At least 1 approving review
- CI passing
- Branch up to date with `main` before merge
- Conversations resolved
- Branch auto-deleted after merge

## Stale Branch Policy

- Branches >30 days without activity → flagged by `/speckit.branching`
- Merged branches → auto-deleted
- Abandoned branches → logged for manual decision

## Audit Scope Implication

`/speckit.audit` and `/speckit.codereview` use `git diff main...HEAD` as their
default scope when invoked on a non-main branch. This works because direct
commits to main are forbidden — the branch diff is always a complete unit of
work. Branch protection is therefore a prerequisite for diff-scoped audits.

## Rule Compliance

Run `/speckit.branching` to:
- Detect mismatches (local + remote)
- Auto-fix local issues (rename master→main, install hook, update rules file)
- Generate `gh` commands for remote branch protection
- Report stale branches

Run periodically, especially when:
- Onboarding an existing repo to this template
- Migrating from another branching model
- After major GitHub permission changes
