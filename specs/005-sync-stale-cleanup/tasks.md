---
description: "Task list for 005-sync-stale-cleanup"
---

# Tasks: Stale Chunk Cleanup in memory_sync

**Input**: Design documents from `/specs/005-sync-stale-cleanup/`
**Branch**: `005-sync-stale-cleanup`
**Prerequisites**: spec.md ✓, plan.md ✓

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[US1]**: Belongs to User Story 1 — Stale Chunks Purged During Sync
- Include exact file paths in descriptions
- TDD: test tasks precede implementation tasks

---

## Phase 1: Setup

**Purpose**: Confirm baseline — existing tests must pass before any changes.

- [x] T001 Run existing unit tests to confirm baseline in `memory-server/` (`uv run --directory memory-server pytest -m "not integration"`)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: No new schema, dependencies, or shared infrastructure required for this feature. The `fake_embedder` fixture in `memory-server/tests/conftest.py` covers all new unit tests. This phase is a no-op — proceed to Phase 3.

**Checkpoint**: Foundation ready — no blocking prerequisites beyond Phase 1 baseline confirmation.

---

## Phase 3: User Story 1 — Stale Chunks Purged During Sync (Priority: P1) 🎯 MVP

**Goal**: Fix two bugs in `run_sync` (scoped-sync mass-deletion and per-file deleted count), harden `find_deleted` to guard malformed/synthetic manifest entries, and add a direct-exists safety check per ADR-030.

**Independent Test**: Given an index containing chunks from a file that has since been deleted from disk, when `memory_sync` is called (unscoped), then the sync response includes a `deleted` count equal to the number of chunks that belonged to that file, and a subsequent `memory_recall` query that previously matched content from that file returns no results from it.

### Tests for User Story 1

> **TDD: Write these tests FIRST and verify they FAIL before implementing.**

- [x] T002 [P] [US1] Create `memory-server/tests/unit/test_sync.py` with 6 failing unit tests for cleanup-pass behavior:
  - `test_scoped_sync_skips_cleanup` — index 2 files, delete 1, sync scoped to the other; assert `deleted == 0` and deleted file's chunks remain (FR-001a)
  - `test_deleted_count_is_chunks_not_files` — index a multi-heading file (produces N>1 chunks), delete it, sync; assert `deleted == N` (FR-008)
  - `test_clean_index_reports_zero_deleted` — index files, sync again with all files present; assert `deleted == 0` (FR-006, SC-002)
  - `test_idempotent_cleanup` — delete file, sync, sync again; assert second sync `deleted == 0` (SC-003)
  - `test_malformed_manifest_entry_skipped` — inject empty-string key and `"synthetic"` key into manifest; sync; assert no crash and `deleted == 0` (spec edge case)
  - `test_find_deleted_filters_synthetic_entries` — call `find_deleted` directly with `"synthetic"` key in manifest entries; assert returns empty list (FR-007)
- [x] T003 [P] [US1] Add 2 failing integration tests to `memory-server/tests/integration/test_sync.py`:
  - `test_scoped_sync_does_not_delete_absent_files` — FR-001a end-to-end with real LanceDB
  - `test_deleted_count_matches_actual_chunks_removed` — FR-008 end-to-end, verify `deleted` equals actual row count delta

### Implementation for User Story 1

- [x] T004 [US1] Harden `find_deleted` in `memory-server/speckit_memory/sync.py` (lines ~244–248): add `rel and rel != "synthetic"` guard so empty-string and `"synthetic"` manifest keys are never returned as deletion candidates (FR-007, spec edge case)
- [x] T005 [US1] Fix scoped-sync cleanup gate in `run_sync` in `memory-server/speckit_memory/sync.py` (lines ~324–330): introduce `scoped_files` variable, pass `scoped_files` to `classify_files`, gate `find_deleted` call behind `if not paths and not full` — prevents mass-deletion when a scoped sync filters `all_files` (FR-001a, ADR-027)
- [x] T006 [US1] Fix `deleted` count to use chunks not files in `run_sync` cleanup loop in `memory-server/speckit_memory/sync.py`: change `deleted += 1` to `deleted += n` where `n` is the return value of `delete_chunks_by_source_file` (FR-008)
- [x] T007 [US1] Add `try/except OSError` direct-exists safety check in `run_sync` cleanup loop in `memory-server/speckit_memory/sync.py`: skip deletion if `(repo_root / rel).exists()` returns `True` or raises `OSError` — treat inaccessible files as present (ADR-030)

**Checkpoint**: All 6 unit tests and 2 new integration tests should now pass. Run `uv run --directory memory-server pytest` to confirm.

---

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: Validation and doc hygiene after implementation.

- [x] T008 Run full test suite (unit + integration) to confirm no regressions: `uv run --directory memory-server pytest` in `memory-server/`
- [x] T009 [P] Update `CLAUDE.md` to reflect the `005-sync-stale-cleanup` feature under Recent Changes if not already present

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Phase 2**: No-op — skip
- **US1 (Phase 3)**: Depends on Phase 1 baseline confirmation
  - T002 and T003 can run in parallel (different files)
  - T004 must precede T005 (both in `sync.py`, sequential — T004 changes `find_deleted` which T005 calls)
  - T005 must precede T006 (same cleanup block in `run_sync`, sequential)
  - T006 must precede T007 (same cleanup loop body, sequential)
- **Polish (Phase 4)**: Depends on all Phase 3 tasks complete

### Within User Story 1

- T002 and T003 are written in parallel (different files); both must FAIL before T004 begins
- T004 → T005 → T006 → T007 (all in `sync.py`, sequential — one coherent edit region)
- T008 runs after T007 to confirm all tests pass

### Parallel Opportunities

```bash
# Phase 3 — write tests in parallel (different files):
Task T002: memory-server/tests/unit/test_sync.py          (new file)
Task T003: memory-server/tests/integration/test_sync.py   (additions)

# Implementation is sequential (all changes in sync.py):
T004 → T005 → T006 → T007
```

---

## Implementation Strategy

### MVP (User Story 1 is the only story)

1. Complete Phase 1: confirm baseline passes
2. Write failing tests (T002, T003) in parallel
3. Verify tests fail — do not proceed until confirmed
4. Implement T004 → T005 → T006 → T007 sequentially
5. Run T008 to confirm all tests pass
6. Commit and open PR

### PR Budget

~50 LOC production (`sync.py`) + ~130 LOC tests ≈ 180 LOC total. Within the 300 LOC limit per conventions.

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [US1] label maps to User Story 1 (only story in this feature)
- `fake_embedder` fixture is in `memory-server/tests/conftest.py` — no new fixtures needed
- `delete_chunks_by_source_file` already returns `int` (before − after rows) in `index.py` — no changes to `index.py`
- Synthetic chunk safety depends on the invariant that synthetic chunks never produce manifest entries (documented in FR-007 and confirmed in plan.md constitution check)
- `full=True` rebuilds also skip cleanup — the `if not paths and not full` gate covers both cases; document this in the inline comment
- T006 and T007 are in the same loop body; separate tasks because they fix distinct bugs (count semantics vs. safety posture)
