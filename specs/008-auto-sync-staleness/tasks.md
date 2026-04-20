# Tasks: Auto-Sync Staleness Detection and Memory Opt-In Gate

**Input**: Design documents from `/specs/008-auto-sync-staleness/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓
**Revised**: 2026-04-18 — post-task-gate review (H1 float parse, H2 summary_only gap, M1 integration test, M2 stderr log)

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to
- TDD is mandatory — tests MUST fail before implementation begins

### Architecture note (revised from plan)

`_check_staleness()` is called from `memory_recall()` directly, **before** the `summary_only` gate — not inside `_ensure_init()`. This fixes the summary_only staleness gap (H2): all `memory_recall` callers trigger the staleness check; only non-summary_only callers proceed to `_ensure_init()` which does the actual embed+sync. `_ensure_init()` stays simpler (no staleness logic).

```
memory_recall():
    _check_staleness()          # all paths — pure arithmetic, no Ollama
    if not summary_only:
        _ensure_init()          # embeds, Ollama required
    ...

_ensure_init():
    if _first_call_done: return
    run_sync(...)
    _first_call_done = True
```

---

## Phase 1: Setup

**Purpose**: Create test file before writing any tests.

- [x] T001 Create empty test file `memory-server/tests/unit/test_staleness.py` with module docstring and `from __future__ import annotations` import

---

## Phase 2: User Story 1 — Index Stays Current Without Manual Intervention (Priority: P1) 🎯 MVP

**Goal**: Timestamp-based staleness detection so the server re-syncs automatically when the index is older than `MEMORY_STALENESS_THRESHOLD`.

**Independent Test**: Given a populated index with `last_sync_ts` set 2+ hours ago, when `memory_recall` is called (with default 3600s threshold), `_first_call_done` is reset and the subsequent `_ensure_init()` call triggers `run_sync`. Given a fresh index (synced 30 minutes ago), `_first_call_done` remains `True`.

### Tests for User Story 1

> **Write ALL tests first and confirm they FAIL before proceeding to T008**

- [x] T002 [US1] Write failing unit test: `_check_staleness()` resets `_first_call_done` when `time.time() - last_sync_ts > threshold` in `memory-server/tests/unit/test_staleness.py`
- [x] T003 [US1] Write failing unit test: `_check_staleness()` does NOT reset `_first_call_done` when `time.time() - last_sync_ts <= threshold` in `memory-server/tests/unit/test_staleness.py`
- [x] T004 [US1] Write failing unit test: `_check_staleness()` does nothing when `MEMORY_STALENESS_THRESHOLD` is 0 (disabled) in `memory-server/tests/unit/test_staleness.py`
- [x] T005 [US1] Write failing unit test: `_check_staleness()` treats absent `last_sync_ts` (pre-008 manifest) as stale and resets `_first_call_done` in `memory-server/tests/unit/test_staleness.py`
- [x] T006 [US1] Write failing unit test: `_check_staleness()` logs a WARNING to stderr and continues when manifest read raises an exception (does not re-raise) in `memory-server/tests/unit/test_staleness.py`
- [x] T007 [US1] Write failing unit test: `run_sync()` writes a `last_sync_ts` float field to the manifest on successful completion in `memory-server/tests/unit/test_staleness.py`
- [x] T008 [US1] Write failing integration test: calling `_check_staleness()` when stale resets `_first_call_done = False`, and a subsequent `_ensure_init()` call invokes `run_sync` (mock `run_sync` to verify two-call sequence) in `memory-server/tests/unit/test_staleness.py`
- [x] T009 [US1] Write failing unit test: `_check_staleness()` is called on the `summary_only=True` path of `memory_recall` — verify it runs before `_ensure_init()` is bypassed in `memory-server/tests/unit/test_staleness.py`
- [x] T010 [US1] Write failing unit test: non-numeric `MEMORY_STALENESS_THRESHOLD` env var does NOT raise at import; server module imports cleanly and treats it as 0 (disabled) in `memory-server/tests/unit/test_staleness.py`

### Implementation for User Story 1

- [x] T011 [US1] Add `manifest["last_sync_ts"] = time.time()` immediately before the final `save_manifest(index_dir, manifest)` call in `run_sync()` in `memory-server/speckit_memory/sync.py` (uses `time` already imported in function scope)
- [x] T012 [US1] Add config to `memory-server/speckit_memory/server.py`: `import time` at module level; `_MEMORY_STALENESS_THRESHOLD` parsed from `MEMORY_STALENESS_THRESHOLD` env var using try/except — on `ValueError` or any parse error, default to `0.0` (disabled); non-positive values also treat as `0.0`
- [x] T013 [US1] Add `_check_staleness()` helper to `memory-server/speckit_memory/server.py`: reads manifest from `_index_dir()`, compares `time.time() - manifest.get("last_sync_ts", 0)` against `_MEMORY_STALENESS_THRESHOLD`, resets `global _first_call_done = False` if stale; on any exception emits `[speckit-memory] WARNING: staleness check failed: {exc}` to stderr and returns without re-raising
- [x] T014 [US1] Move staleness check to `memory_recall()` in `memory-server/speckit_memory/server.py`: add `_check_staleness()` call at the top of `memory_recall()`, before the `if not summary_only: _ensure_init()` branch; remove any staleness logic from `_ensure_init()` (which should retain only its existing first-call-done guard and sync logic)

**Checkpoint**: Run `uv run --directory memory-server pytest memory-server/tests/unit/test_staleness.py -m "not integration"` — all T002–T010 tests must pass.

---

## Phase 3: User Story 2 — Memory Server Is Optional for Installs Without It (Priority: P2)

**Goal**: `memory_enabled: false` in constitution.md allows projects to explicitly skip all memory tool calls. The gate is convention-enforced (skill-layer); no server code changes.

**Independent Test**: Given `memory_enabled: false` in `.specify/memory/constitution.md`, when a speckit skill reads the constitution per the updated `memory-convention.md` gate instruction, the skill skips `memory_recall` and `memory_store` calls.

### Tests for User Story 2

- [x] T015 [US2] Write smoke test: read `.claude/rules/memory-convention.md` and assert all four of the following strings are present in `memory-server/tests/unit/test_staleness.py`: (1) `"Constitution gate"` — gate section exists (FR-008); (2) `"memory_enabled"` — field name documented (FR-008); (3) `"absent"` or `"absent or unparseable"` — absent-field default-to-true documented (FR-009); (4) `"unparseable"` — fallback for bad constitution documented (FR-011). Guards against accidental removal and verifies convention text covers all three spec requirements.

### Implementation for User Story 2

- [x] T016 [US2] Add YAML front-matter to `.specify/memory/constitution.md`: insert `---\nmemory_enabled: true\n---\n` at file start, before the existing SYNC IMPACT REPORT HTML comment
- [x] T017 [US2] Add `memory_enabled` field to `.specify/templates/constitution-template.md` with a comment: `# memory_enabled: true | Set to false to disable all memory_recall/memory_store calls in speckit skills`
- [x] T018 [US2] Add "Constitution gate" section to `.claude/rules/memory-convention.md`: before invoking any memory tool, check `memory_enabled` in constitution front-matter; if `false`, skip all `memory_recall` and `memory_store` calls; if absent or unparseable, treat as `true`; include a concrete example showing exactly what the gate check looks like in a skill prompt. The section MUST explicitly state: (a) absent `memory_enabled` defaults to `true` (FR-009), and (b) an unparseable or absent constitution file also defaults to `true` (FR-011) — T015 asserts these strings are present.

**Checkpoint**: Run T015 smoke test; verify constitution.md front-matter is parseable; verify memory-convention.md gate section is present.

---

## Phase 4: Polish & Cross-Cutting Concerns

- [x] T019 Update `CLAUDE.md` to add `MEMORY_STALENESS_THRESHOLD` to the Environment Variables table in the Commands section (default: `3600`; `0` = disabled)
- [x] T020 Verify ADR-011 amendment history entry is present in `.specify/memory/ADR_011_self-init-sync-trigger.md`; update if the plan-phase entry doesn't reflect the revised architecture (staleness check in `memory_recall`, not `_ensure_init`)
- [x] T021 Update `specs/008-auto-sync-staleness/spec.md` Decision Records table to add ADR-050 and ADR-051 rows
- [x] T022 Run full test suite `uv run --directory memory-server pytest -m "not integration"` to confirm no regressions

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **US1 (Phase 2)**: Depends on Phase 1 (test file must exist); TDD order within phase is mandatory
- **US2 (Phase 3)**: Independent of Phase 2 — can start any time after Phase 1
- **Polish (Phase 4)**: Depends on US1 and US2 completion

### Within Phase 2 (TDD mandatory order)

```
T001 (create test file)
  → T002–T010 (write ALL failing tests; confirm they fail)
  → T011 (sync.py: last_sync_ts)
  → T012 (server.py: config + safe parse)
  → T013 (server.py: _check_staleness helper)
  → T014 (server.py: move check to memory_recall)
  → Confirm all T002–T010 pass
```

### Within Phase 3 (US2 order)

```
T015 (write smoke test; confirm it fails)
  → T016 (constitution.md front-matter)
  → T017 (template update)
  → T018 (memory-convention.md gate section)
  → Confirm T015 passes
```

---

## Implementation Strategy

### MVP (US1 only)

1. T001 — create test file
2. T002–T010 — write failing tests (confirm all fail)
3. T011–T014 — implement staleness detection
4. Validate: `pytest memory-server/tests/unit/test_staleness.py -m "not integration"`

### Full delivery

1. MVP above
2. T015–T018 — constitution gate
3. T019–T022 — polish and regression check

---

## Notes

- T002–T010 are the TDD gate. Do not begin T011 until all nine tests are written and confirmed failing.
- `run_sync()` imports `time` inside the function body. `server.py` does not currently import `time` at module level — T012 adds it.
- `_check_staleness()` reads the manifest fresh on each call (do not cache). The manifest load is fast (JSON read) and must reflect the latest sync timestamp.
- The config parse (T012) uses try/except around `float(os.environ.get(...))`. ValueError, empty string, and any other exception → 0.0 (disabled).
- `_check_staleness()` exception handling (T013) logs to stderr (`[speckit-memory] WARNING: staleness check failed: {exc}`) and returns — consistent with `_ensure_init()` warning pattern.
- US2 changes are convention/documentation only. The smoke test (T015) verifies the convention file was updated, not that LLMs follow it.
- `memory-convention.md` gate section (T018) must include a concrete example — not just prose — showing what the check looks like in a skill prompt template.
