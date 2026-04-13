# Tasks: Memory Server Hardening

**Input**: Design documents from `specs/003-memory-server-hardening/`
**Prerequisites**: plan.md ✓ spec.md ✓ research.md ✓ data-model.md ✓ contracts/ ✓

**Organization**: Three independent user stories in priority order. No shared setup or foundational
phase — all infrastructure (LanceDB, FastMCP, fake embedder fixture) exists from feature 002.
Each story phase is independently testable before the next begins.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks in this phase)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)

---

## Phase 3: User Story 1 — Mutation Protection (Priority: P1) 🎯 MVP

**Goal**: Prevent agent tool calls from corrupting index representations of real source files.
`memory_store` rejects any `source_file` that is not `"synthetic"`. `memory_delete` rejects
path-based deletes where the file still exists on disk.

**Independent Test**: Given `.specify/memory/ADR_008_lancedb-vector-backend.md` present on disk
and indexed, when `memory_store` is called with `source_file=".specify/memory/ADR_008_lancedb-vector-backend.md"`,
then the response contains `INVALID_SOURCE_FILE` error, and a subsequent `memory_recall("LanceDB")`
still returns the original ADR content unchanged.

**ADR references**: ADR-019 (whitelist write guard), ADR-023 (delete guard path resolution)

### Tests for User Story 1

> **Write these tests FIRST — confirm they FAIL before writing any implementation code**

- [X] T001 [US1] Write contract test: `memory_store` with `source_file="nonexistent/file.md"` returns `{"error": {"code": "INVALID_SOURCE_FILE", ...}}` in `memory-server/tests/contract/test_tools.py`
- [X] T002 [US1] Update existing `test_store_nonexistent_source_sets_synthetic_flag` to assert `INVALID_SOURCE_FILE` rejection (not `"stored"`) — this test must now fail in `memory-server/tests/contract/test_tools.py`
- [X] T003 [US1] Write contract test: `memory_delete` with `source_file` pointing to an on-disk path returns `{"error": {"code": "PROTECTED_SOURCE_FILE", ...}}`; use `tmp_path` to create a real file, patch `_repo_root` to return `tmp_path`, and pass the file's name as a relative `source_file` so that `_repo_root() / source_file` resolves correctly — use `patch("speckit_memory.server._repo_root", return_value=tmp_path)` in `memory-server/tests/contract/test_tools.py`
- [X] T004 [US1] Write contract test: `memory_delete` with `source_file` of a path that no longer exists on disk (create temp file then delete it) proceeds with `deleted_chunks: 0` in `memory-server/tests/contract/test_tools.py`

### Implementation for User Story 1

- [X] T005 [US1] Implement write guard in `memory_store`: replace lines 145–148 (`is_synthetic` filesystem-existence block) with a whitelist check — if `source_file != "synthetic"` return `INVALID_SOURCE_FILE` error; remove the `is_synthetic` computation entirely and hardcode `"synthetic": True` for all passing writes in `memory-server/speckit_memory/server.py`
- [X] T006 [US1] Implement delete guard in `memory_delete`: add a filesystem presence check at the top of the `source_file is not None` branch — if `(_repo_root() / source_file).exists()` return `PROTECTED_SOURCE_FILE` error; id-based delete branch is unaffected in `memory-server/speckit_memory/server.py`

**Checkpoint**: Run `uv run --directory memory-server pytest tests/contract/ -k "Store or Delete" -v`. T001–T004 must pass. Existing `test_store_returns_id_and_stored_status` and `test_stored_chunk_is_queryable` must still pass (no regression on `source_file="synthetic"`). Existing `test_delete_by_id_removes_exactly_one` must still pass.

---

## Phase 4: User Story 2 — Caller-Controlled Token Budget (Priority: P2)

**Goal**: `memory_recall` accepts an optional `max_chars` parameter that caps total content
characters across all returned chunks. Every `memory_recall` response includes `token_estimate`
(chars/4 heuristic). `budget_exhausted` is set when any ranked chunk was dropped.

**Independent Test**: Given at least 10 indexed chunks whose combined content exceeds 10,000
characters, when `memory_recall("architecture decisions")` is called with `max_chars=4000`, then
the total character count of all chunk content in the response does not exceed 4,000 and the
response includes `token_estimate` with a positive integer value.

**ADR references**: ADR-021 (token estimation heuristic), ADR-022 (budget enforcement algorithm)

### Tests for User Story 2

> **Write these tests FIRST — confirm they FAIL before writing any implementation code**

- [X] T007 [US2] Write contract test: `memory_recall` with `max_chars=100` (with corpus seeded beyond that limit) returns total content ≤ 100 chars and includes `budget_exhausted` field in `memory-server/tests/contract/test_tools.py`
- [X] T008 [US2] Write contract test: `memory_recall` with `max_chars` smaller than the single highest-ranked chunk returns one result with `content` truncated at `max_chars`, `truncated: true`, and `budget_exhausted: true` in `memory-server/tests/contract/test_tools.py`
- [X] T009 [US2] Write contract test: `memory_recall` without `max_chars` returns `token_estimate` as a positive integer and does NOT include a `budget_exhausted` field in `memory-server/tests/contract/test_tools.py`
- [X] T010 [US2] Write contract test: `memory_recall` with `max_chars=0` returns `{"error": {"code": "INVALID_INPUT", ...}}` in `memory-server/tests/contract/test_tools.py`
- [X] T011 [US2] Write contract test: `memory_recall` with `max_chars` large enough to fit all chunks returns `budget_exhausted: false` and all chunks in `memory-server/tests/contract/test_tools.py`
- [X] T011b [US2] Write contract test confirming stop-at-first-overflow semantics: seed corpus with chunk A (score 0.9, 200 chars), chunk B (score 0.8, 500 chars), chunk C (score 0.7, 50 chars); call `memory_recall` with `max_chars=250`; assert results contain only chunk A (B overflows → stop, C is never considered) in `memory-server/tests/contract/test_tools.py`

### Implementation for User Story 2

- [X] T012 [US2] Add `max_chars: int | None = None` parameter to `memory_recall`; add validation (reject zero/negative with `INVALID_INPUT`); implement **stop-at-first-overflow** packing loop: iterate results in ranked order; include chunk if `len(chunk["content"]) <= chars_remaining`; on the first chunk that does NOT fit, set `budget_exhausted = True` and break — do not check subsequent chunks; set `budget_exhausted` in response only when `max_chars` is set in `memory-server/speckit_memory/server.py`
- [X] T013 [US2] Add truncation-of-last-resort to `max_chars` handling: if packing loop produces an empty result list, take the first result and truncate `content` to `max_chars` characters; set `truncated: True` and `budget_exhausted: True` in response in `memory-server/speckit_memory/server.py`
- [X] T014 [US2] Add `token_estimate` field to every `memory_recall` response: `math.ceil(total_content_chars / 4)` where `total_content_chars = sum(len(r["content"]) for r in results)`; always present regardless of `max_chars` in `memory-server/speckit_memory/server.py`

**Checkpoint**: Run `uv run --directory memory-server pytest tests/contract/ -k "Recall" -v`. T007–T011 must pass. Existing `test_recall_*` tests must still pass (no regression — `token_estimate` is additive, `budget_exhausted` absent when `max_chars` not set).

---

## Phase 5: User Story 3 — Summary-Only Recall and Source Filter (Priority: P3)

**Goal**: `memory_recall` with `summary_only: true` returns lightweight `{source_file, section, score}`
entries (no chunk content) for two-pass retrieval. `filter_source_file` restricts results to a
specific source file.

**Independent Test**: Given at least 5 indexed chunks, when `memory_recall("technology decisions")`
is called with `summary_only: true`, then each result contains `source_file`, `section`, and `score`
fields, contains no `content` field, and the total response character count is under 500 chars for
a 5-result set.

**ADR references**: LOG-020 resolved as FR-010 (filter_source_file added as top-level param)

### Tests for User Story 3

> **Write these tests FIRST — confirm they FAIL before writing any implementation code**

- [X] T015 [US3] Write contract test: `memory_recall` with `summary_only=True` returns results where each entry has `source_file`, `section`, `score` and does NOT have a `content` key in `memory-server/tests/contract/test_tools.py`
- [X] T015b [US3] Write contract test for `summary_only=True` combined with `max_chars`: seed corpus with 3 chunks whose serialized entry sizes (len(source_file + section + str(score))) total more than `max_chars`; assert that fewer than 3 summary entries are returned and `budget_exhausted: true` is set (FR-007 / US3 acceptance scenario 2) in `memory-server/tests/contract/test_tools.py`
- [X] T016 [P] [US3] Write unit test: `vector_search()` with `filter_source_file="file_a.md"` (with corpus containing chunks from `file_a.md` and `file_b.md`) returns only `file_a.md` chunks in `memory-server/tests/unit/test_index.py`
- [X] T017 [US3] Write contract test: `memory_recall` with `filter_source_file="specific_file.md"` (seeded corpus with that file) returns only results from that file in `memory-server/tests/contract/test_tools.py`

### Implementation for User Story 3

- [X] T018 [US3] Add `filter_source_file: str | None = None` parameter to `vector_search()` in `memory-server/speckit_memory/index.py`; if set, append `source_file = '{_sql_escape(filter_source_file)}'` to the WHERE conditions list (same pattern as `filter_type` and `filter_feature`)
- [X] T019 [US3] Add `filter_source_file: str | None = None` parameter to `memory_recall` in `memory-server/speckit_memory/server.py`; pass through to `vector_search()` call alongside existing filter params
- [X] T020 [US3] Add `summary_only: bool = False` parameter to `memory_recall` in `memory-server/speckit_memory/server.py`; if `True`, project results to `[{"source_file": r["source_file"], "section": r["section"], "score": r["score"]} for r in results]` after vector search; update `token_estimate` to count serialized entry chars in summary mode: `sum(len(r["source_file"] + r["section"] + str(r["score"])) for r in results)`

**Checkpoint**: Run `uv run --directory memory-server pytest tests/ -m "not integration" -v`. All 3 new US3 tests pass. All prior US1 and US2 tests still pass.

---

## Phase 6: Polish

- [X] T021 Run full non-integration test suite and confirm zero failures: `uv run --directory memory-server pytest -m "not integration" -v` — all contract, unit tests pass; no regressions from feature 002 baseline

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 3 (US1)**: No prerequisites — start immediately
- **Phase 4 (US2)**: Independent of US1 — can start in parallel with US1 if desired; no code dependency
- **Phase 5 (US3)**: Independent of US1 and US2 — can start after US1/US2 tests are written; T018 (`index.py`) has no dependency on any US1 or US2 server.py change
- **Phase 6 (Polish)**: After all user stories complete

### User Story Dependencies

- **US1 (P1)**: Independent — starts from existing `server.py`; no dependency on US2 or US3
- **US2 (P2)**: Independent — adds parameters to `memory_recall`; no dependency on US1 guards or US3 projections
- **US3 (P3)**: T018 (`index.py`) independent of all US1/US2 work; T019/T020 (`server.py`) independent of US1 guard changes and US2 budget changes (different parameters, different code paths in same function)

### Within Each User Story

- TDD order: tests FIRST → confirm they fail → implement → confirm they pass
- T002 (update existing test) comes before T005 (implement write guard) — the test must be red before the guard is green
- T012 (packing loop) before T013 (truncation edge case) — truncation requires the packing loop to exist first
- T018 (index.py `filter_source_file`) before T019 (server.py wiring) — wiring depends on the underlying function accepting the parameter

### Parallel Opportunities

- T016 [P] can run concurrently with T015 and T017 (different file: `test_index.py` vs `test_tools.py`)
- All US phases can proceed in parallel if two developers are available — US1 (guards), US2 (budget), US3 (summary/filter) touch distinct parameters and code paths

---

## Parallel Example: User Story 3

```bash
# T015 and T016 can start together:
Task T015: summary_only contract test in tests/contract/test_tools.py
Task T016: [P] filter_source_file unit test in tests/unit/test_index.py

# T017 follows T015 (same file, test_tools.py):
Task T017: filter_source_file contract test in tests/contract/test_tools.py

# T018, T019, T020 are sequential (T18→T19→T20):
Task T018: add filter_source_file to vector_search() in index.py
Task T019: wire filter_source_file in memory_recall in server.py
Task T020: add summary_only projection in memory_recall in server.py
```

---

## Implementation Strategy

### MVP (User Story 1 Only)

1. Complete Phase 3 (US1): write guard + delete guard
2. **STOP and VALIDATE**: Run `pytest tests/contract/ -k "Store or Delete" -v`
3. All US1 tests pass. Existing store/delete tests unaffected (no regression)
4. Ship P1 — index integrity protected going forward

### Incremental Delivery

1. US1 (P1) → mutation protection closes the corruption vector → ship
2. US2 (P2) → budget control and observability for high-context sessions → ship
3. US3 (P3) → two-pass retrieval tooling for power callers → ship
4. Each story adds value without touching the prior story's code paths

---

## Notes

- `[P]` tasks are in different files — genuine write-conflict-free parallelism
- The write guard removes ~6 lines of filesystem-existence logic from `memory_store` and replaces with ~4 lines — net LOC reduction in implementation
- `math.ceil` must be imported (or use `-(x // -4)` floor division trick) for T014
- The truncation-of-last-resort (T013) is the trickiest edge case — verify the test covers `max_chars` < the smallest seeded chunk, not just < the largest
- Commit after each checkpoint
