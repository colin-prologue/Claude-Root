# Implementation Plan: Stale Chunk Cleanup in memory_sync

**Branch**: `005-sync-stale-cleanup` | **Date**: 2026-04-13 | **Spec**: [specs/005-sync-stale-cleanup/spec.md](spec.md)
**Input**: Feature specification from `/specs/005-sync-stale-cleanup/spec.md`

## Summary

Add a cleanup pass to `run_sync` that deletes chunks for manifest entries whose
source files no longer exist on disk. The pass runs before the add/update pass on
every unscoped sync. Two bugs already exist in the partial implementation: (1) the
scoped-sync cleanup gate is missing — when `paths` is set, `find_deleted` receives
a filtered `all_files` and incorrectly marks all non-scoped manifest entries as
deleted; (2) `deleted` counts files, not chunks. Both are fixed with targeted
changes to `sync.py`. No new technologies introduced.

## Decision Records

| # | Type | File | Title | Status |
|---|---|---|---|---|
| ADR-027 | Decision | ADR_027_scoped-sync-cleanup-exclusion.md | Scoped sync excludes stale chunk cleanup | Accepted (pre-existing) |
| ADR-030 | Decision | ADR_030_cleanup-detection-strategy.md | Crawl-based with direct-exists safety check | Accepted |
| LOG-028 | Challenge | LOG_028_orphaned-chunks-non-atomic-cleanup.md | Orphaned chunks from non-atomic cleanup | Open (deferred) |
| LOG-029 | Question | LOG_029_log018-unresolved-concerns.md | LOG-018 unresolved concerns: de-dupe and synthetic purge | Deferred |
| LOG-031 | Challenge | LOG_031_codereview-005-fast-follows.md | Post-codereview fast-follow items (FF-001 through FF-004) | Open (FF-001, FF-002) / Resolved (FF-003, FF-004) |

## Technical Context

**Language/Version**: Python 3.10+
**Primary Dependencies**: FastMCP 3.2+, LanceDB 0.13+, PyArrow, Ollama nomic-embed-text
**Storage**: LanceDB embedded (`.specify/memory/.index/chunks.lance/`) + `manifest.json`
**Testing**: pytest + pytest-asyncio (unit: no Ollama; integration: requires Ollama)
**Target Platform**: macOS/Linux (local developer tool)
**Project Type**: MCP server library
**Performance Goals**: Cleanup pass adds negligible overhead — O(manifest entries) path-exists checks, no Ollama calls
**Constraints**: Must not change sync response schema for the scoped-sync case (`deleted: 0` on scoped sync, unchanged from current behavior)
**Scale/Scope**: Typical corpus: 20-100 manifest entries. Bulk deletion (dozens of files) must complete correctly per FR-008

## Constitution Check

*GATE: Pre-Phase 0. Re-verified below after design.*

Passes:
- **Pass 1 — Assumptions challenged**:
  - *"Synthetic chunks never appear in manifest"* — confirmed: `manifest["entries"][rel]` is only set in the `to_embed` loop in `run_sync`, which processes real files from `crawl_files`. `memory_store` never touches the manifest. Invariant holds (FR-007).
  - *"Current deleted count is files not chunks"* — confirmed: `deleted += 1` in the cleanup loop, not `deleted += delete_chunks_by_source_file(...)`. Bug confirmed.
  - *"Scoped sync currently triggers mass deletion"* — confirmed: `all_files` is filtered to `paths` before `find_deleted` is called. `find_deleted` returns all manifest entries NOT in the filtered list. Bug confirmed.
  - *"find_deleted uses crawl results, not direct exists"* — confirmed. Covered by ADR-030.
- **Pass 2 — Research**:
  - `delete_chunks_by_source_file` already returns the deleted count (`before - after`). No new function needed.
  - `find_deleted` signature and logic are correct for the full-sync case once we stop filtering `all_files` before calling it.
  - No performance concern: `Path.exists()` for 20-100 entries is sub-millisecond.
- **Pass 3 — Riskiest decision**: The `all_files` refactor (separating `scoped_files` from `all_files`). Risk: breaking the classify_files / add-update pass for scoped syncs. Mitigation: `classify_files` receives `scoped_files` (scoped case unchanged); `find_deleted` receives `all_files` (full crawl, only on unscoped syncs).

Constitution gates:
- [x] Principle I: Spec approved, ADR-027 and ADR-030 written before Phase 1
- [x] Principle II: Two targeted bug fixes + edge case handling. No new abstractions.
- [x] Principle III: TDD — failing tests written first for each requirement
- [x] Principle IV: Single story (P1), single deployable increment
- [x] PR Policy: ~50 LOC production + ~130 LOC tests ≈ 180 LOC total. Within 300 LOC.

## Project Structure

### Documentation (this feature)

```text
specs/005-sync-stale-cleanup/
├── plan.md              # This file
├── research.md          # N/A — no NEEDS CLARIFICATION; bugs confirmed by code inspection
├── data-model.md        # N/A — no schema changes; existing chunk/manifest schema unchanged
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code

```text
memory-server/
  speckit_memory/
    sync.py              # Modified — cleanup pass fix (FR-001a, FR-008, edge cases)
  tests/
    unit/
      test_sync.py       # New — unit tests for cleanup pass behavior
    integration/
      test_sync.py       # Modified — add deleted-count-is-chunks test, scoped-sync-no-cleanup test
```

No new files in `speckit_memory/`. No changes to `index.py`, `server.py`, or any other module.

## Design

### Root Cause Analysis

`run_sync` in `sync.py` (lines 325–339):

```python
# Current (buggy) code
all_files = crawl_files(repo_root, index_paths_env)
if paths:
    all_files = [f for f in all_files if str(f.relative_to(repo_root)) in paths]

classified = classify_files(all_files, manifest, repo_root)
deleted_rel = find_deleted(manifest, all_files, repo_root)

# ...
for rel in deleted_rel:
    delete_chunks_by_source_file(table, rel)
    manifest["entries"].pop(rel, None)
    deleted += 1                           # BUG 2: counts files not chunks
```

**Bug 1** (FR-001a): When `paths` is set, `all_files` is filtered down. `find_deleted(manifest, all_files, ...)` then marks all manifest entries NOT in the scoped files as "deleted." On a scoped sync, this deletes everything except the scoped file — data destruction.

**Bug 2** (FR-008): `deleted += 1` increments by file. Spec requires per-chunk counting.

### Fix

```python
# Fixed code
all_files = crawl_files(repo_root, index_paths_env)
scoped_files = (
    [f for f in all_files if str(f.relative_to(repo_root)) in paths]
    if paths else all_files
)

classified = classify_files(scoped_files, manifest, repo_root)

# Cleanup pass — skipped entirely on scoped syncs (ADR-027, FR-001a)
if not paths and not full:
    deleted_candidates = find_deleted(manifest, all_files, repo_root)
    for rel in deleted_candidates:
        # Conservative safety check (ADR-030): verify the file truly doesn't exist
        # before deleting. Handles permission errors / glob miss edge cases.
        try:
            if (repo_root / rel).exists():
                continue  # file exists but wasn't crawled; skip
        except OSError:
            continue  # cannot check; treat as present (conservative)
        n = delete_chunks_by_source_file(table, rel)
        manifest["entries"].pop(rel, None)
        deleted += n                        # FIX: chunks, not files
```

Note: cleanup is also skipped during `full` rebuilds because `full=True` drops and
recreates the table entirely — cleanup would be a no-op and wasteful.

### find_deleted hardening

Add guard for malformed entries (spec edge case: empty or "synthetic" source_file
in manifest should not trigger deletion):

```python
def find_deleted(manifest: dict, files: list[Path], repo_root: Path) -> list[str]:
    indexed_rel = {str(f.relative_to(repo_root)) for f in files}
    return [
        rel for rel in manifest.get("entries", {})
        if rel and rel != "synthetic" and rel not in indexed_rel
    ]
```

### Sync response

No schema change. `deleted` field already exists. On scoped sync: `deleted: 0`
(cleanup pass skipped, no deletion). On full rebuild: `deleted: 0` (table is dropped
and recreated, not tracked as deletions).

## Test Plan (TDD — failing tests precede implementation)

### Unit tests — `memory-server/tests/unit/test_sync.py` (new file)

Use `fake_embedder` fixture. No Ollama dependency.

| Test | Requirement | Method |
|---|---|---|
| `test_scoped_sync_skips_cleanup` | FR-001a | Index 2 files; delete 1 from disk; sync with `paths=[other_file]`; assert `deleted == 0`, deleted file's chunks still in table |
| `test_deleted_count_is_chunks_not_files` | FR-008 | Index file that produces N chunks (multiple headings); delete file; sync; assert `deleted == N` |
| `test_clean_index_reports_zero_deleted` | FR-006, SC-002 | Index files; sync again (all present); assert `deleted == 0` |
| `test_idempotent_cleanup` | SC-003 | Delete file; sync; sync again; assert second `deleted == 0` |
| `test_malformed_manifest_entry_skipped` | spec edge case | Manually inject empty-string key and "synthetic" key into manifest; sync; assert no crash, `deleted == 0` |
| `test_find_deleted_filters_synthetic_entries` | FR-007 | `find_deleted` with "synthetic" key in manifest entries returns empty list |

### Integration tests — additions to `memory-server/tests/integration/test_sync.py`

| Test | Requirement |
|---|---|
| `test_scoped_sync_does_not_delete_absent_files` | FR-001a end-to-end with real LanceDB |
| `test_deleted_count_matches_actual_chunks_removed` | FR-008 end-to-end |

## Complexity Tracking

No violations. Changes are minimal targeted fixes to an existing function.
