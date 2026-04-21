# LOG-057: `MEMORY_REPO_ROOT` Env Var Undocumented

**Date**: 2026-04-20
**Type**: UPDATE
**Status**: Resolved
**Raised In**: speckit.audit full-repo findings (2026-04-20) § HIGH H2
**Related ADRs**: ADR-052 (component model — this env var is the primary
relocation hook for non-canonical deployments)

---

## Description

`memory-server/speckit_memory/server.py:60-70` reads `MEMORY_REPO_ROOT` at module
load to resolve the repo root used for sync-path derivation. The variable is not
documented in `CLAUDE.md`'s env-var table (lines 39–43) nor in `.mcp.json` (lines
6–10). The only mention is in `specs/006-ollama-fallback/data-model.md:80`, which
labels it "auto-detected" — misleading, since it is an explicit override that
overrides the auto-detection.

## Context

Added during 006-ollama-fallback as an escape hatch for test harnesses and
out-of-tree deployments where `speckit_memory` is imported from a location that
does not sit under the user's repo. Never documented beyond the data-model note.
ADR-052 (three-component model) anticipates that speckit-memory may be installed
into arbitrary projects via `speckit init`, which makes this override a
first-class integration surface — it deserves user-facing documentation.

## Discussion

### Pass 1 — Initial Analysis

Options:
1. Document in `CLAUDE.md` env-var table and correct the 006 data-model note.
2. Remove the override (force auto-detect) — lossy; breaks any caller that relies on
   it today.
3. Rename it to match convention (e.g., `SPECKIT_REPO_ROOT`) and document.

### Pass 2 — Critical Review

Option 1 is the minimal fix and unblocks 009-speckit-init. Option 2 is a breaking
change with no gain. Option 3 is cosmetic and can be deferred; the current name is
namespaced by `MEMORY_` which is consistent with the other env vars on the server.

## Resolution

Added `MEMORY_REPO_ROOT` to the CLAUDE.md env-var table and corrected the 006
data-model description to note it is an explicit override for out-of-tree
deployments. No code change needed.

**Resolved By**: inline edit
**Resolved Date**: 2026-04-20

## Impact

- [x] CLAUDE.md updated: env-var table — `MEMORY_REPO_ROOT (default:
      auto-derived from server.py location) — override repo root for out-of-tree
      deployments (LOG-057)`
- [x] Spec updated: `specs/006-ollama-fallback/data-model.md:80` — replaced
      "_(auto-detected)_" with "_(auto-detected from server.py location)_" +
      explicit-override language
- [ ] ADR created/updated: None
