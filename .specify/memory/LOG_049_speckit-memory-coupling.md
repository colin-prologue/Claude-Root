---
name: LOG-049 — Speckit skills implicitly require memory server
description: Skills follow memory-convention.md without checking server availability; no opt-in gate; tight coupling risk for installs without the memory server
type: project
---

# LOG-049: Speckit Skills Implicitly Require Memory Server

**Date**: 2026-04-17
**Status**: Open — partial mitigation applied; ADR-worthy decision pending
**Feature**: cross-cutting (memory-convention.md)
**Related ADRs**: ADR-011 (self-init sync), ADR-032 (scope boundary)

---

## Observation

Speckit skills (`/speckit.plan`, `/speckit.review`, `/speckit.audit`) follow `memory-convention.md` and call `memory_recall`/`memory_store` at the start and end of execution. The convention uses `SHOULD` language but contained no explicit guidance for the case where the memory server is absent, crashed, or unwanted.

This creates implicit coupling: the `.mcp.json` registers `speckit-memory` as a required server, but there is no opt-in gate in the skills or convention that allows an install without the memory server to function gracefully. If a user clones this repo without running the memory server, or if the server fails mid-session, skill behavior is undefined.

Separately: `_ensure_init` (ADR-011) only syncs once per server process lifetime. If new ADRs/LOGs are created after the first sync and `memory_sync()` is never called manually, the knowledge base drifts silently from the file tree — as observed between April 9–17, where 37 files went unindexed.

## Immediate Mitigation

`memory-convention.md` updated (2026-04-17) to add an explicit best-effort clause: skills must not block on memory availability; if the tool is absent or errors, skip silently and continue.

## Open Questions

1. **Opt-in gate**: Should `constitution.md` include a `memory_enabled: true/false` field that skills check before invoking memory tools? This would make the memory dependency explicit and allow installs without the server.

2. **Staleness detection**: Should `_ensure_init` compare disk file count against manifest entry count and re-sync when the delta exceeds a threshold? This would make the index self-healing without requiring manual `memory_sync()` calls after creating new ADRs/LOGs.

3. **Sync convention**: Should `memory_sync()` be added to the Definition of Done (conventions.md) as a required step after creating new ADRs/LOGs? This is the lowest-effort fix for the staleness problem.

## Feature 008 Design Notes

**Goal**: Index stays current automatically. No manual `memory_sync()` required after creating ADRs/LOGs.

### Option A — Staleness-aware `_ensure_init` (preferred)

Extend `_ensure_init` to check for drift after first sync, not just at startup. On every call where `_first_call_done = True`, compare disk file count against manifest entry count. If delta ≥ threshold (e.g., 3 files), reset `_first_call_done = False` to trigger incremental re-sync on the next call.

```python
# Pseudocode for staleness check in _ensure_init
if _first_call_done:
    disk_count = len(crawl_files(_repo_root(), _MEMORY_INDEX_PATH or None))
    manifest_count = len(load_manifest(_index_dir())["entries"])
    if disk_count - manifest_count >= STALENESS_THRESHOLD:
        _first_call_done = False  # will re-sync on next call
    return
```

**Threshold**: 3 new files is a reasonable default — avoids spurious re-syncs from single file edits, catches "just finished a feature" additions. Make it configurable via `MEMORY_STALENESS_THRESHOLD` env var.

**Cost**: `crawl_files()` does a glob scan — ~1ms for a 50-200 file corpus. Acceptable per-call overhead. `load_manifest()` is already fast (JSON read). Net overhead: ~2ms per recall call when synced, sync triggered ~once per feature.

**Risk**: If sync takes 30s (large corpus, slow Ollama), the first recall after threshold crossed will be slow. Mitigation: run sync in background thread, return stale results immediately, let next call pick up fresh index. Adds complexity — defer to implementation.

**Simpler version**: Just check if `time.time() - manifest.get("last_sync_ts", 0) > 3600` (1 hour). Add a `last_sync_ts` field to manifest. Zero filesystem overhead, pure timestamp check.

### Option B — PostToolUse hook (complementary)

Add a `settings.json` hook on `Write`/`Edit` that triggers scoped `memory_sync(paths=[file])` when the touched path matches `.specify/memory/` or `specs/*/`.

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Write|Edit",
      "hooks": [{"type": "command", "command": "...check path and sync..."}]
    }]
  }
}
```

**Pro**: Zero overhead on recall path. Syncs the exact file immediately after creation.
**Con**: Hook fires on every Write/Edit (needs path filter to avoid spurious syncs). Adds settings.json complexity. Hook failures are silent unless configured.

### Option C — Constitution opt-in gate

Add `memory_enabled: true` to `constitution.md`. Skills read this and skip memory calls entirely when false. Solves the coupling problem for no-memory installs.

**Implementation**: Single field in constitution YAML front-matter. Skills check it before calling `memory_recall`/`memory_store`. The `.mcp.json` could omit the memory server registration when disabled.

**Recommended 008 scope**: Option A (timestamp-based staleness check, simpler variant) + Option C (constitution gate). Option B is useful but adds operational complexity; defer unless A proves insufficient.

### ADR-011 amendment needed

If 008 changes `_ensure_init` behavior, ADR-011 ("self-init sync trigger") must be amended to document the new trigger conditions.
