# Tasks: Auto-Sync Staleness Detection and Memory Opt-In Gate

**Input**: Design documents from `/specs/008-auto-sync-staleness/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to
- TDD is mandatory — tests MUST fail before implementation begins

---

## Phase 1: Setup

**Purpose**: Create test file structure before writing any tests.

- [ ] T001 Create empty test file `memory-server/tests/unit/test_staleness.py` with module docstring and `from __future__ import annotations` import

---

## Phase 2: User Story 1 — Index Stays Current Without Manual Intervention (Priority: P1) 🎯 MVP

**Goal**: Timestamp-based staleness detection in `_ensure_init()` so the server automatically re-syncs when the index is older than `MEMORY_STALENESS_THRESHOLD`.

**Independent Test**: Given a populated index with `last_sync_ts` set to 2 hours ago, when `_ensure_init()` is called (with default 3600s threshold), `_first_call_done` is reset to `False` and the next call triggers re-sync. Given a fresh index (synced 30 minutes ago), `_first_call_done` remains `True`.

### Tests for User Story 1

> **Write these tests FIRST and confirm they FAIL before proceeding to implementation**

- [ ] T002 [US1] Write failing unit test: `_check_staleness()` resets `_first_call_done` when `time.time() - last_sync_ts > threshold` in `memory-server/tests/unit/test_staleness.py`
- [ ] T003 [US1] Write failing unit test: `_check_staleness()` does NOT reset `_first_call_done` when `time.time() - last_sync_ts <= threshold` in `memory-server/tests/unit/test_staleness.py`
- [ ] T004 [US1] Write failing unit test: `_check_staleness()` does nothing when `MEMORY_STALENESS_THRESHOLD` is 0 (disabled) in `memory-server/tests/unit/test_staleness.py`
- [ ] T005 [US1] Write failing unit test: `_check_staleness()` treats absent `last_sync_ts` (pre-008 manifest) as stale and resets `_first_call_done` in `memory-server/tests/unit/test_staleness.py`
- [ ] T006 [US1] Write failing unit test: `_check_staleness()` is non-fatal — swallows exceptions without raising in `memory-server/tests/unit/test_staleness.py`
- [ ] T007 [US1] Write failing unit test: `run_sync()` writes `last_sync_ts` (float) to manifest on successful completion in `memory-server/tests/unit/test_staleness.py`

### Implementation for User Story 1

- [ ] T008 [US1] Add `manifest["last_sync_ts"] = time.time()` before `save_manifest()` in `run_sync()` in `memory-server/speckit_memory/sync.py` (uses `time` already imported in function scope)
- [ ] T009 [US1] Add `import time` and `_MEMORY_STALENESS_THRESHOLD = float(os.environ.get("MEMORY_STALENESS_THRESHOLD", "3600"))` config to `memory-server/speckit_memory/server.py`
- [ ] T010 [US1] Add `_check_staleness()` helper function to `memory-server/speckit_memory/server.py` — reads manifest, compares `time.time() - last_sync_ts` against `_MEMORY_STALENESS_THRESHOLD`, resets `_first_call_done = False` if stale, swallows all exceptions
- [ ] T011 [US1] Modify `_ensure_init()` in `memory-server/speckit_memory/server.py` to call `_check_staleness()` at the top of the `if _first_call_done:` branch before returning

**Checkpoint**: Run `uv run --directory memory-server pytest memory-server/tests/unit/test_staleness.py -m "not integration"` — all T002–T007 tests must pass.

---

## Phase 3: User Story 2 — Memory Server Is Optional for Installs Without It (Priority: P2)

**Goal**: `memory_enabled: false` in constitution.md allows projects to skip all memory tool calls entirely without errors.

**Independent Test**: Given `memory_enabled: false` in `.specify/memory/constitution.md`, when any speckit skill reads the constitution and checks the gate before invoking memory tools, no `memory_recall` or `memory_store` call is issued.

### Implementation for User Story 2

*(No server code — convention and documentation changes only)*

- [ ] T012 [US2] Add YAML front-matter `memory_enabled: true` to `.specify/memory/constitution.md` (insert `---\nmemory_enabled: true\n---\n` at file start before the existing SYNC IMPACT REPORT comment)
- [ ] T013 [US2] Add `memory_enabled` field documentation to `.specify/templates/constitution-template.md` — add an optional `memory_enabled: true` field with a comment explaining the gate behavior
- [ ] T014 [US2] Add constitution gate check instruction to `.claude/rules/memory-convention.md` — new "Constitution gate" section: before invoking any memory tool, check `memory_enabled` in constitution front-matter; if `false`, skip all memory calls; if absent or unparseable, treat as `true`

**Checkpoint**: Read `.specify/memory/constitution.md` and verify front-matter is present. Read `.claude/rules/memory-convention.md` and verify the gate section is present.

---

## Phase 4: Polish & Cross-Cutting Concerns

- [ ] T015 Update `CLAUDE.md` to add `MEMORY_STALENESS_THRESHOLD` to the Environment Variables table in the Commands section
- [ ] T016 Verify ADR-011 amendment history entry is present in `.specify/memory/ADR_011_self-init-sync-trigger.md` (was written during plan phase — confirm and expand if needed)
- [ ] T017 Update Decision Records table in `specs/008-auto-sync-staleness/spec.md` to add ADR-050 and ADR-051 rows
- [ ] T018 Run full test suite `uv run --directory memory-server pytest -m "not integration"` to confirm no regressions

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **US1 (Phase 2)**: Depends on Phase 1 (test file must exist); TDD order within phase is mandatory
- **US2 (Phase 3)**: Independent of Phase 2 — can start immediately after Phase 1
- **Polish (Phase 4)**: Depends on US1 and US2 completion

### User Story Dependencies

- **US1 (P1)**: Depends only on Phase 1 (test file). No dependency on US2.
- **US2 (P2)**: No dependencies. Can start any time after Phase 1.

### Within Phase 2 (US1 — TDD mandatory order)

```
T001 (create test file)
  → T002–T007 (write ALL failing tests)
  → Confirm tests fail
  → T008 (sync.py: last_sync_ts)
  → T009 (server.py: config)
  → T010 (server.py: _check_staleness)
  → T011 (server.py: _ensure_init patch)
  → Confirm all tests pass
```

### Parallel Opportunities

- T002–T007: All test-writing tasks target the same file but are logically independent — write in sequence within one session; no cross-task blocking
- T012–T014 (US2 tasks): all target different files and can be done in any order

---

## Implementation Strategy

### MVP (US1 only)

1. T001 — create test file
2. T002–T007 — write failing tests
3. T008–T011 — implement staleness detection
4. Validate: `pytest memory-server/tests/unit/test_staleness.py -m "not integration"`

### Full delivery

1. MVP above
2. T012–T014 — constitution gate (no tests; convention-only)
3. T015–T018 — polish and regression check

---

## Notes

- T002–T007 are the TDD gate. Do not begin T008 until all six tests are written and confirmed failing.
- `run_sync()` already imports `time` inside the function body; `server.py` does not currently import `time` at module level — T009 adds it.
- The `_check_staleness()` helper must read the manifest fresh on each call (not cache it) so it always reflects the most recent sync timestamp.
- US2 changes are documentation/convention only. No server code changes, no new tests required.
- The `MEMORY_STALENESS_THRESHOLD` env var must be documented in CLAUDE.md with the same format as `OLLAMA_TIMEOUT`.
