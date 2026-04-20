# Research: Auto-Sync Staleness Detection and Memory Opt-In Gate

**Feature**: 008-auto-sync-staleness  
**Date**: 2026-04-17  
**Status**: Complete — all NEEDS CLARIFICATION resolved

---

## Staleness Trigger Strategy

### Decision: Timestamp-based staleness check (Option A — simple variant)

**Rationale**: LOG-049 evaluated two variants of Option A:
- *File-count delta*: compare `len(crawl_files())` against `len(manifest["entries"])`. Requires a glob scan (~1ms) per recall call; triggers false positives when file counts shrink (deletions).
- *Timestamp delta*: compare `time.time()` against `manifest["last_sync_ts"]`. Pure in-memory arithmetic with no filesystem I/O. Requires one new field in the manifest written on sync completion.

The timestamp variant has zero per-call filesystem overhead and avoids the false-positive problem. The only new state is a single float in an already-loaded JSON document. Selected.

**Alternatives considered**:
- File-count delta: ~1ms fs overhead per call; false positives on deletion; rejected (LOG-049).
- Background async re-sync: avoids blocking the first post-staleness recall; adds thread management complexity; deferred per LOG-049.
- PostToolUse hook (Option B): fires on every Write/Edit, needs path filter, adds settings.json complexity; deferred per scope.
- ADR: ADR-050

---

## Staleness Threshold Configuration

### Decision: Env var `MEMORY_STALENESS_THRESHOLD` (seconds, default 3600, 0 = disabled)

**Rationale**: Consistent with existing env var configuration pattern (`OLLAMA_TIMEOUT`, `MEMORY_INDEX_PATH`). Default 3600s (1 hour) is a reasonable window for a speckit workflow — typically one or two features worth of ADRs get written before the next recall. Value 0 explicitly disables, which is cleaner than a boolean flag (the threshold value already encodes the on/off state). Negative values treated as disabled (same as 0) to be forgiving of misconfiguration.

**Alternatives considered**:
- Separate `MEMORY_STALENESS_ENABLED` boolean flag: redundant — 0 already disables. Rejected.
- Hardcoded threshold: removes operator control; rejected.

---

## Manifest Field for Sync Timestamp

### Decision: `last_sync_ts` (float Unix timestamp) written by `run_sync()` on successful completion

**Rationale**: The manifest is already loaded and saved in `run_sync()`. Adding a single `last_sync_ts` field on the existing `save_manifest()` call requires 1 line of code and no schema migration — missing keys are treated as stale (absent → stale is safe and forces a re-sync on first post-008 call). The field must be written only on success; partial or failed syncs must not update the timestamp to avoid masking the staleness condition.

**Alternatives considered**:
- Separate timestamp file: unnecessary complexity. Rejected.
- Store in the `_empty_manifest` default: would require pre-populating with 0, which is acceptable but noisier. Not needed — missing key already handled as stale.

---

## Constitution Gate Strategy

### Decision: `memory_enabled` YAML front-matter field; skill-layer convention; default `true`

**Rationale**: The constitution file already exists and is read by skills. Adding a YAML front-matter field to it (parsed by the existing `_strip_frontmatter()` helper in sync.py) is the lowest-friction way to introduce an explicit opt-in gate. The gate is enforced at the skill layer (convention in `memory-convention.md`), not in the server, because:
1. The spec explicitly requires direct MCP tool calls to remain unaffected.
2. Server enforcement would require adding constitution-parsing logic to the server, coupling two independent concerns.
3. Skills already read the constitution for other purposes; checking a field is a minor addition.

Default `true` preserves backward compatibility — existing constitutions without the field work unchanged. ADR: ADR-051.

**Alternatives considered**:
- Server-side gate: couples constitution parsing to server startup; violates spec requirement that direct tool calls always pass through. Rejected.
- Separate `.speckit-config.yml` file: unnecessary new artifact when constitution front-matter serves the same purpose. Rejected.
- Convention-only (no field, rely on error-skipping): already in place (LOG-049 immediate mitigation), but provides no explicit developer control. Insufficient.

---

## Sync Path: Synchronous vs. Background

### Decision: Synchronous staleness re-sync on recall path

**Rationale**: Background sync was discussed in LOG-049 but explicitly deferred because it adds thread lifecycle management complexity. The first post-staleness recall is slower, but this is acceptable for the typical speckit workflow where syncs take 2-10 seconds for a 50-200 file corpus. The slowdown is bounded, predictable, and rare (once per staleness window). Deferred: if sync latency becomes a concern, a background worker can be added as a follow-on.

---

## ADR-011 Amendment

ADR-011 documents the self-init sync trigger. Feature 008 changes the trigger conditions: `_ensure_init` can now reset its "done" flag based on timestamp comparison, meaning the sync may fire more than once per process lifetime. ADR-011 must be amended to document this. No new ADR required — amendment history entry suffices.

---

## Files Changed (Preview)

| File | Change |
|------|--------|
| `memory-server/speckit_memory/sync.py` | Add `manifest["last_sync_ts"] = time.time()` before `save_manifest()` in `run_sync()` |
| `memory-server/speckit_memory/server.py` | Add `MEMORY_STALENESS_THRESHOLD` config, `import time`, `_check_staleness()` helper, modify `_ensure_init()` |
| `memory-server/tests/unit/test_staleness.py` | New: TDD tests for staleness logic |
| `.claude/rules/memory-convention.md` | Add constitution gate check instruction |
| `.specify/memory/constitution.md` | Add `memory_enabled: true` to front-matter |
| `.specify/templates/constitution-template.md` | Add `memory_enabled` field with documentation |
| `.specify/memory/ADR_050_*.md` | New: timestamp staleness strategy |
| `.specify/memory/ADR_051_*.md` | New: constitution gate strategy |
| `.specify/memory/LOG_049_*.md` | Update: mark resolved, reference ADR-050 and ADR-051 |
