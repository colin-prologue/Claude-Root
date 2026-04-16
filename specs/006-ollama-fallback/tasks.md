# Tasks: Ollama Fallback (006)

**Branch**: `006-ollama-fallback` | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)
**Revised**: 2026-04-15 — post-task-review amendments (LOG-038, F1 guard in T014, F2 contract test scope in T010, F3 T021 clarity); post-analyze gaps (H1: T018b partial-sync manifest test; H2: T003b _ensure_init retry test; H3: T023b memory_delete _ensure_init guard)

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[US1]** / **[US2]**: Maps to user story from spec.md
- TDD is non-negotiable: tests precede implementation within each phase

---

## Phase 1: Setup

**Purpose**: Add missing imports and wire up the new timeout env var constant — one-time scaffolding that all subsequent changes depend on.

- [x] T001 Add imports to `memory-server/speckit_memory/server.py`: `import httpx`, `import ollama as ollama_sdk`, `from fastmcp.exceptions import ToolError`

**Checkpoint**: Imports available — subsequent changes can reference ToolError, httpx, and ollama_sdk

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Timeout configuration, `_embed_error` helper, and `_ensure_init` flag fix — shared infrastructure required by both US1 and US2.

**⚠️ CRITICAL**: No user story implementation can begin until this phase is complete.

### Tests (write first, verify they fail)

- [x] T002 [P] Write failing unit tests for `_ollama_embed` timeout parameter: assert client is constructed with the passed timeout value in `memory-server/tests/unit/test_sync.py`
- [x] T003 [P] Write failing unit tests for `_embed_error` helper: assert each exception type (ConnectionError, httpx.TimeoutException, ollama_sdk.ResponseError with status 404, other ResponseError) raises ToolError with the correct message prefix (EMBEDDING_UNAVAILABLE, EMBEDDING_MODEL_ERROR) in `memory-server/tests/unit/test_server_errors.py`
- [x] T003b Write failing unit test for `_ensure_init` retry-on-recovery in `memory-server/tests/unit/test_server_errors.py`: patch `run_sync` to raise ConnectionError; call `_ensure_init()`; assert `_first_call_done` is still `False`; then patch to succeed; call `_ensure_init()` again; assert it does not short-circuit (resolves LOG-035; enables T007)

### Implementation

- [x] T004 [P] Add `timeout: float = 10.0` parameter to `_ollama_embed` and pass it to `ollama.Client(host=base_url, timeout=timeout)` in `memory-server/speckit_memory/sync.py`
- [x] T005 Add `_OLLAMA_TIMEOUT = float(os.environ.get("OLLAMA_TIMEOUT", "10"))` at module level in `memory-server/speckit_memory/server.py` and thread it through `_embed_text` to `_ollama_embed`
- [x] T006 Implement `_embed_error(exc, model)` helper in `memory-server/speckit_memory/server.py`: raises ToolError with EMBEDDING_MODEL_ERROR for ollama_sdk.ResponseError 404, EMBEDDING_UNAVAILABLE for httpx.TimeoutException and ConnectionError/OSError
- [x] T007 Fix `_ensure_init` flag ordering in `memory-server/speckit_memory/server.py`: move `_first_call_done = True` inside the try block, after `run_sync(...)` succeeds (resolves LOG-035)

**Checkpoint**: Foundation ready — `_embed_error`, timeout threading, and `_ensure_init` retry fix all in place

---

## Phase 3: User Story 1 — Read Operations Survive Ollama Outage (Priority: P1)

**Goal**: `memory_recall` in `summary_only` mode bypasses Ollama entirely via a table scan; semantic recall fails with a structured ToolError, not an unhandled exception.

**Independent Test**: Given a populated index and Ollama not running, `memory_recall(summary_only=True)` returns results successfully. `memory_recall` in semantic mode raises a ToolError within 10 seconds — no crash, no hang.

### Tests for User Story 1 (write first, verify they fail)

- [x] T008 [P] [US1] Write failing unit tests for `scan_chunks` in `memory-server/tests/unit/test_index.py`: cover filter_type, filter_feature, filter_tags, filter_source_file, top_k truncation, and empty table case
- [x] T009 [P] [US1] Write failing unit test in `memory-server/tests/unit/test_server_errors.py`: mock `_embed_text` to raise ConnectionError and assert `memory_recall(summary_only=True)` never calls it AND does not call `_ensure_init` (use `unittest.mock.patch`); assert semantic `memory_recall` raises ToolError
- [x] T010 [P] [US1] Update contract tests in `memory-server/tests/contract/test_tools.py`: (a) `memory_recall` in semantic mode with Ollama down must produce isError=true (ToolError), not a return-value error dict (ADR-033 breaking change); (b) update existing `test_recall_summary_only_omits_content` — remove `assert "score" in entry`, assert only `source_file` and `section` keys are present; (c) update `test_recall_summary_only_with_max_chars_budget` — recalculate expected `total` for 2-field entries (~45 chars each, not ~67)
- [x] T011 [US1] Write failing integration test in `memory-server/tests/integration/test_fault_scenarios.py`: `memory_recall(summary_only=True)` returns populated results with Ollama not running (mark `@pytest.mark.integration`)
- [x] T012 [US1] Write failing integration test in `memory-server/tests/integration/test_fault_scenarios.py`: `memory_recall` semantic mode with Ollama down raises ToolError containing "EMBEDDING_UNAVAILABLE" within 10 seconds

### Implementation for User Story 1

- [x] T013 [P] [US1] Implement `scan_chunks(table, top_k, filter_type, filter_feature, filter_tags, filter_source_file)` in `memory-server/speckit_memory/index.py`: table scan via `table.to_arrow().to_pylist()`, apply Python-level filters, return `rows[:top_k]` (ADR-037)
- [x] T014 [US1] Restructure `memory_recall` in `memory-server/speckit_memory/server.py`: (a) guard `_ensure_init()` call with `if not summary_only` — the `summary_only` path calls `init_table(idx_dir)` directly and must never trigger `_ensure_init` (fixes LOG-038: post-T007, `_ensure_init` retries on every call when Ollama is down, adding ~10s latency to every `summary_only` call); (b) check `summary_only` BEFORE calling `_embed_text`; (c) on `summary_only=True` call `scan_chunks` and return `{source_file, section}` results with no score field; (d) wrap `_embed_text` on semantic path in `except (ConnectionError, OSError, httpx.TimeoutException, ollama_sdk.ResponseError) as exc: _embed_error(exc, _OLLAMA_MODEL)` (depends on T013)

**Checkpoint**: `memory_recall(summary_only=True)` works without Ollama; semantic recall raises structured ToolError

---

## Phase 4: User Story 2 — Write Operations Fail Gracefully (Priority: P1)

**Goal**: `memory_store` and `memory_sync` raise ToolError with a corrective hint when Ollama is unavailable; invalid `OLLAMA_BASE_URL` uses a distinct error code.

**Independent Test**: Given Ollama not running, `memory_store` returns a structured ToolError with code EMBEDDING_UNAVAILABLE and a hint field within 10 seconds — no hang.

### Tests for User Story 2 (write first, verify they fail)

- [x] T015 [US2] Write failing unit test in `memory-server/tests/unit/test_server_errors.py`: `_embed_text` with `OLLAMA_BASE_URL="ftp://bad"` raises ToolError containing "EMBEDDING_CONFIG_ERROR" (FR-009)
- [x] T016 [P] [US2] Update contract tests in `memory-server/tests/contract/test_tools.py`: `memory_store` and `memory_sync` with Ollama down must produce isError=true (ToolError), not a return-value error dict (ADR-033 breaking change)
- [x] T017 [US2] Write failing integration test in `memory-server/tests/integration/test_fault_scenarios.py`: `memory_store` with Ollama not running raises ToolError containing "EMBEDDING_UNAVAILABLE" and "Hint:" within timeout
- [x] T018 [US2] Write failing integration test in `memory-server/tests/integration/test_fault_scenarios.py`: with a bad model name (model not pulled), `memory_store` raises ToolError containing "EMBEDDING_MODEL_ERROR" with model name in message
- [x] T018b [US2] Write failing integration test in `memory-server/tests/integration/test_fault_scenarios.py`: `memory_sync` with Ollama failing after the first chunk is embedded — assert `manifest.json` is not written with entries for un-embedded files (FR-007, SC-004; mark `@pytest.mark.integration`)

### Implementation for User Story 2

- [x] T019 [US2] Add URL validation in `_embed_text` in `memory-server/speckit_memory/server.py`: if `urllib.parse.urlparse(_OLLAMA_BASE_URL).scheme not in ("http", "https")`, raise `ToolError("EMBEDDING_CONFIG_ERROR: ...")` before constructing the client (FR-009)
- [x] T020 [US2] Update `memory_store` in `memory-server/speckit_memory/server.py`: replace `except ConnectionError` / `return _api_unavailable(...)` with `except (ConnectionError, OSError, httpx.TimeoutException, ollama_sdk.ResponseError) as exc: _embed_error(exc, _OLLAMA_MODEL)` (FR-001, FR-002, FR-003)
- [x] T021 [US2] Update `memory_sync` in `memory-server/speckit_memory/server.py`: `memory_sync` has two distinct exception handlers — (a) `except (ConnectionError, OSError)` calling `_api_unavailable`, and (b) a `except Exception` with string-matching (`"connection" in err_str.lower()`) also calling `_api_unavailable`. Replace BOTH by removing handler (b) entirely and replacing handler (a) with `except (ConnectionError, OSError, httpx.TimeoutException, ollama_sdk.ResponseError) as exc: _embed_error(exc, _OLLAMA_MODEL)` — the string-matching heuristic is superseded by the typed catch clause and must not be preserved (FR-001, FR-002, FR-003, FR-007)

**Checkpoint**: All four tools surface Ollama errors as ToolError; write operations bounded by OLLAMA_TIMEOUT

---

## Phase 5: Polish & Cross-Cutting Concerns

- [x] T022 Remove `_api_unavailable` function from `memory-server/speckit_memory/server.py` (all call sites replaced in T020–T021; dead code per ADR-033)
- [x] T023 [P] Add contract test in `memory-server/tests/contract/test_tools.py`: `memory_delete` succeeds with Ollama unavailable — no embedding required (FR-008)
- [x] T023b Remove `_ensure_init()` call from `memory_delete` in `memory-server/speckit_memory/server.py`; replace with direct `init_table(idx_dir)` — delete never embeds, so auto-sync-on-first-call is neither needed nor correct (resolves LOG-038 for delete path; makes T023 pass; FR-008)
- [x] T024 [P] Run full unit + contract test suite: `uv run --directory memory-server pytest -m "not integration"` and confirm all new test targets pass

**Checkpoint**: All unit/contract tests green; integration tests can be validated manually against a live Ollama instance

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 — **BLOCKS** all user story work
- **Phase 3 (US1)**: Depends on Phase 2 completion — tests + implementation in priority order
- **Phase 4 (US2)**: Depends on Phase 2 completion — can begin after Phase 3 tests pass (same `server.py`)
- **Phase 5 (Polish)**: Depends on Phase 3 + Phase 4 completion

### User Story Dependencies

- **US1**: Depends only on Foundational phase — no dependency on US2
- **US2**: Depends only on Foundational phase — no dependency on US1
- US1 and US2 both modify `server.py` so they must be sequential in practice (solo dev, single file)

### Within Each User Story

- Tests → verify fail → implementation (strict TDD order)
- `scan_chunks` (T013) must complete before `memory_recall` restructure (T014)
- Both stories' implementation tasks must complete before T022 (removing `_api_unavailable`)
- T023 (contract test) must come before T023b (impl); T023b must come before T024

### Parallel Opportunities

| Group | Tasks | Can run in parallel |
|---|---|---|
| Phase 2 tests | T002, T003, T003b | Yes — different files; T003b same file as T003, sequential after T003 |
| Phase 2 impl | T004, T005 | Yes — sync.py vs server.py; T006 and T007 must follow T005 sequentially; T007 depends on T003b passing |
| Phase 3 tests | T008, T009, T010 | Yes — different files; T011 → T012 sequential (same file) |
| Phase 3 impl | T013 independent; T014 depends on T013 | T013 can start with test phase; T014 only after T013 |
| Phase 5 | T023, T023b, T024 | T023 (test) → T023b (impl) → T024 (suite run) |

---

## Parallel Example: Phase 2

```bash
# Parallel: write both test files simultaneously
Task T002: Failing tests for _ollama_embed timeout in tests/unit/test_sync.py
Task T003: Failing tests for _embed_error categories in tests/unit/test_server_errors.py

# Parallel: implement sync.py while starting server.py changes
Task T004: Add timeout param to _ollama_embed in sync.py
Task T005: Add _OLLAMA_TIMEOUT + thread through _embed_text in server.py
# Then sequential in server.py:
Task T006: Implement _embed_error (after T005)
Task T007: Fix _ensure_init (after T006)
```

---

## Implementation Strategy

### MVP (US1 Only — Read Resilience)

1. Complete Phase 1: Setup (T001)
2. Complete Phase 2: Foundational (T002–T007)
3. Complete Phase 3: US1 tests + implementation (T008–T014)
4. **STOP and VALIDATE**: Run `uv run --directory memory-server pytest -m "not integration"` — all new US1 tests must pass
5. Manual: verify `memory_recall(summary_only=True)` with Ollama stopped

### Full Delivery (Both Stories)

1. MVP above →
2. Add Phase 4: US2 tests + implementation (T015–T021) →
3. Phase 5: Polish (T022–T024) →
4. PR: ~130–150 LOC, within 300 LOC limit

---

## Notes

- [P] = different files, no incomplete task dependencies
- All integration tests must be marked `@pytest.mark.integration` (require live Ollama)
- Commit after each phase checkpoint
- `_api_unavailable` must not be removed (T022) until both T020 and T021 are complete
- `scan_chunks` result shape has no `score` field — callers in summary_only path must not expect one
