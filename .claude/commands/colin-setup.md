---
description: Sync personal Claude Code config (hooks, CLAUDE.md, plugins) from this repo into ~/.claude/
argument-hint: [apply]
---

# /colin-setup

Syncs personal global Claude Code configuration from this repo's `setup/global/` directory into the user's `~/.claude/` directory.

**Default behavior**: dry-run — compare and report differences only.
**With `apply` argument**: make the changes after showing the plan.

## What this command manages

Canonical files live under `setup/global/` in this repo. The command keeps the following in sync with the user's `~/.claude/`:

| Canonical path | Target path | Operation |
|---|---|---|
| `setup/global/CLAUDE.md` | `~/.claude/CLAUDE.md` | Full-file replace if content differs |
| `setup/global/hooks/*.py` | `~/.claude/hooks/*.py` | Full-file replace if content differs |
| `setup/global/settings.hooks.json` | `~/.claude/settings.json` (`hooks` key) | Deep-merge `hooks` section, replace with canonical |
| `setup/global/preferred-plugins.json` | `~/.claude/settings.json` (`enabledPlugins` key) | Report drift only; do not auto-enable/disable without explicit user confirmation per plugin |

## Execution steps

Claude: follow these in order. Do not skip the plan summary; the user must see changes before they land.

### 1. Parse argument

- If `$ARGUMENTS` contains `apply`, set `MODE=apply`.
- Otherwise, `MODE=dryrun`.

### 2. Resolve home directory

- Read `$HOME` (or `$USERPROFILE` on Windows) via Bash.
- On Windows git-bash, `$HOME` is like `/c/Users/colin`. Convert to `C:/Users/colin` format for settings.json paths by substituting the leading `/c/` with `C:/` (or using `cygpath -m "$HOME"` if available).
- Call the resolved value `USER_HOME_NATIVE` (the format that works in settings.json command strings).

### 3. Load canonical files

- Read the four canonical sources from `setup/global/`.
- For `settings.hooks.json`: substitute every `{{USER_HOME}}` placeholder with `USER_HOME_NATIVE`.

### 4. Compare to target state

For each canonical file:
- **CLAUDE.md**: compare byte-for-byte. Mark as `✓ up to date`, `△ differs`, or `+ missing`.
- **hooks/*.py**: same byte-compare per file.
- **settings.hooks.json**: read `~/.claude/settings.json`, extract its `hooks` key, compare to the canonical (substituted) version. Mark accordingly.
- **preferred-plugins.json**: read `~/.claude/settings.json`, extract `enabledPlugins`. For each plugin in canonical `enabled`: check it's `true`. For each in `disabled`: check it's absent or `false`. List any drift.

### 5. Present the plan

Show a concise table:

```
/colin-setup plan (MODE: dryrun|apply)

CLAUDE.md                        ✓ up to date
hooks/pre-bash-guard.py          △ differs
hooks/pre-file-guard.py          ✓ up to date
hooks/stop-repetition-guard.py   ✓ up to date
settings.json hooks block        ✓ up to date
Plugin drift                     2 issues:
  - vercel is enabled globally (should be project-scoped)
  - atomic-agents is enabled (should be disabled)
```

### 6. Apply (only if MODE=apply)

For each item marked `△` or `+`:

- **CLAUDE.md and hooks/*.py**: write the canonical content to the target path. Create parent directories if missing.
- **settings.json hooks block**: read target `~/.claude/settings.json`, replace the `hooks` key with the canonical version, write back with 2-space indent. Preserve all other keys (enabledPlugins, extraKnownMarketplaces, statusLine, etc.).
- **Plugin drift**: do NOT auto-modify. List the drift and ask the user which to enable/disable. Only apply their explicit choices.

### 7. Final verification

After applying:
- Re-run the compare step.
- Confirm all items now show `✓ up to date` (or that remaining plugin drift is intentional).
- Print a one-line summary: `Applied N changes. Re-verification: clean.` or list anything still drifting.

## Important rules

- **Never overwrite `~/.claude/settings.json` wholesale.** Always surgical edits to the `hooks` key; preserve every other key.
- **Never auto-install or uninstall plugins.** Plugin changes are user-gated — too much blast radius.
- **The existing blocking hooks may prevent some operations** (e.g. destructive commands in other tools). This command uses only `Read` and `Write` on canonical paths; it should not trip them.
- If any canonical file under `setup/global/` is missing, abort with a clear error — the repo is the source of truth.
