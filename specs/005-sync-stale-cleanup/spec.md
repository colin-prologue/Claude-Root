# Feature Specification: Stale Chunk Cleanup in memory_sync

**Feature Branch**: `005-sync-stale-cleanup`
**Created**: 2026-04-13
**Status**: Draft

## Decision Records

| # | Type | File | Title | Status |
|---|---|---|---|---|
| LOG-018 | Question | LOG_018_index-cleanup-agent.md | Index Cleanup Agent — Deferred from feature 003 | Partially resolved (stale file-synced chunks only; de-dupe and synthetic purge remain open → LOG-029) |
| ADR-027 | Decision | ADR_027_scoped-sync-cleanup-exclusion.md | Scoped sync excludes stale chunk cleanup | Accepted |
| LOG-028 | Challenge | LOG_028_orphaned-chunks-non-atomic-cleanup.md | Orphaned chunks from non-atomic cleanup | Open |
| LOG-029 | Question | LOG_029_log018-unresolved-concerns.md | LOG-018 unresolved concerns: de-dupe and synthetic purge | Deferred |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Stale Chunks Purged During Sync (Priority: P1)

A developer deletes, renames, or moves a source file that was previously indexed. On the next sync, memory_sync automatically detects that the file no longer exists on disk, removes all chunks associated with it, and reports how many chunks were deleted. The developer sees a non-zero deleted count in the sync response and can confirm the index no longer returns content from that file.

**Why this priority**: Without this, deleted or renamed files continue to pollute recall results indefinitely. This is the core correctness guarantee the feature provides — the index reflects the current state of the file system.

**Independent Test**: Given an index containing chunks from a file that has since been deleted from disk, when memory_sync is called, then the sync response includes a `deleted` count equal to the number of chunks that belonged to that file, and a subsequent memory_recall query that previously matched content from that file returns no results from it.

**Acceptance Scenarios**:

1. **Given** a file was indexed and then deleted from disk, **When** memory_sync runs (unscoped), **Then** all chunks with that `source_file` path are removed from the index, the file's entry is removed from the manifest, and `deleted` in the sync response equals the number of chunks that were removed.
2. **Given** a file was indexed and then renamed (old path gone, new path not yet indexed), **When** memory_sync runs (unscoped), **Then** chunks for the old path are deleted, the sync response reports the deleted count, and the new path is indexed as a new file.
3. **Given** a file was indexed and then moved out of the configured index path, **When** memory_sync runs (unscoped), **Then** its chunks are deleted and its manifest entry is removed.
4. **Given** the cleanup pass runs and then the add/update pass runs, **When** a previously stale path matches a newly added file at the same path, **Then** the file is treated as new and re-indexed correctly (cleanup ran first, leaving no residue to conflict).
5. **Given** memory_sync is called with a non-null `paths` parameter (scoped sync), **When** the sync runs, **Then** the cleanup pass is skipped entirely — no manifest entries are checked for deletion, and `deleted: 0` is reported.
6. **Given** all manifest paths exist on disk, **When** memory_sync runs (unscoped), **Then** `deleted: 0` is reported and no chunks are removed.
7. **Given** the index is completely empty (fresh install, nothing indexed yet), **When** memory_sync runs, **Then** the cleanup pass completes without error and `deleted: 0` is reported.
8. **Given** memory_sync has just been run (index is already clean), **When** it is run again immediately (unscoped), **Then** both responses report `deleted: 0` and the index contains the same set of chunk IDs before and after both calls.

---

### Edge Cases

- What happens when a manifest entry exists but the `source_file` field is empty or malformed? The cleanup pass should skip that entry rather than deleting it, and log a warning.
- What happens when the filesystem check itself fails (permission error, network path unavailable)? The cleanup pass should treat the file as present (conservative: do not delete) and surface the error in the sync response.
- What happens when a synthetic chunk (created by a speckit skill) has a `source_file` of `"synthetic"`? The cleanup pass must not delete synthetic chunks — they have no on-disk path and are excluded from the cleanup pass by design.
- What happens when dozens of files are deleted between syncs? The cleanup pass must handle bulk deletion correctly, reporting the total deleted count across all removed files.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: memory_sync MUST include a cleanup pass that runs before the add/update pass on every unscoped sync cycle.
- **FR-001a**: The cleanup pass MUST be skipped entirely when `memory_sync` is called with a non-null `paths` parameter. Scoped syncs do not trigger stale chunk cleanup. (See ADR-027 for rationale.)
- **FR-001b**: The cleanup pass MUST be skipped when `memory_sync` is called with `full=True`. A full rebuild drops and recreates the entire table, making per-file cleanup a no-op. This exemption applies even though `full=True` syncs are technically unscoped (no `paths` set).
- **FR-002**: The cleanup pass MUST read the current manifest to identify all indexed `source_file` paths (excluding synthetic entries).
- **FR-003**: For each non-synthetic manifest entry, the cleanup pass MUST check whether the corresponding path exists on the filesystem.
- **FR-004**: If a path no longer exists, the cleanup pass MUST delete all chunks in the index whose `source_file` matches that path.
- **FR-005**: If a path no longer exists, the cleanup pass MUST remove that path's entry from the manifest.
- **FR-006**: The cleanup pass MUST be safe to run on an already-clean index — no deletions, no errors, no state changes.
- **FR-007**: Synthetic chunks MUST be excluded from the cleanup pass and never deleted by it. The safety of this exclusion depends on the invariant that synthetic chunks never appear as entries in the manifest. If that invariant changes in a future feature, this requirement must be revisited. (Synthetic chunks are identified by `source_file == "synthetic"` and do not produce manifest entries via the normal sync path.)
- **FR-008**: The sync response MUST include a `deleted` field (integer ≥ 0) containing the total number of index chunks removed during the cleanup pass — counted per chunk, not per source file. A file that produces N chunks contributes N to the `deleted` count, not 1.
- **FR-009**: The cleanup pass MUST NOT be exposed as a separate MCP tool — it operates entirely within the internal sync cycle.
- **FR-010**: The delete guard introduced in feature 003 (which rejects deletion of on-disk files via the `memory_delete` MCP tool) does NOT apply to the internal cleanup pass; the cleanup pass interacts with the index directly.

### Key Entities

- **Manifest**: A persistent record mapping `source_file` paths to their last-indexed state (hash, timestamps). Drives both change detection and cleanup.
- **Chunk**: A unit of indexed content associated with a `source_file`. Multiple chunks may share the same `source_file`. Chunks are the unit of deletion during cleanup.
- **Sync Response**: The structured result returned by memory_sync, extended in this feature to include `deleted` (integer: chunks removed during cleanup).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After deleting any indexed source file and running sync, no recall results reference content from that file.
- **SC-002**: Running sync on an index where all files are present produces `deleted: 0` with no chunk loss.
- **SC-003**: Running sync N times on the same unchanged index yields identical results on every run — "identical" means the same set of chunk IDs is returned by `memory_recall` for any given query, and the manifest is unchanged.
- **SC-004**: The sync response accurately reports the deleted chunk count (in chunks, not files) — verified by comparing the index row count before and after cleanup. If the cleanup pass encounters an error mid-pass, the sync response MUST report an error state; the `deleted` field MUST reflect only the chunks that were actually removed before the error, not the intended total.
- **SC-005**: The cleanup pass does not remove synthetic chunks under any circumstances.

## Assumptions

- Synthetic chunks are identified by `source_file == "synthetic"`. Any chunk with this value is excluded from cleanup regardless of other fields.
- Filesystem existence check uses a simple path-exists test on the local filesystem — no special handling for symlinks, network mounts, or remote paths beyond the conservative "treat unavailable as present" rule.
- The manifest is the authoritative source of truth for what paths are indexed. Chunks whose `source_file` does not appear in the manifest are considered orphaned and are out of scope for this feature — they are tracked as a known gap in LOG-028.
- This feature does not address deduplication, stale synthetic chunk purge, or index health audit — those were part of LOG-018's broader vision and remain deferred.
