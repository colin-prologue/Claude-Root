# Tasks: BM25 Keyword Fallback for memory_recall

**Feature**: `007-bm25-keyword-fallback`
**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [contracts/memory_recall.md](contracts/memory_recall.md)
**Estimated LOC**: ~141 (under 300 LOC limit — single PR)

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on incomplete tasks)
- **[Story]**: Which user story this task belongs to ([US1], [US2], [US3])

---

## Phase 1: Setup

**Purpose**: Confirm baseline before any changes.

- [X] T001 Verify baseline test suite passes on branch `007-bm25-keyword-fallback`: `uv run --directory memory-server pytest -m "not integration"` — record pass count

**Checkpoint**: Green baseline confirmed — no pre-existing failures to mask.

---

## Phase 2: Foundational (TDD Gates — all tests MUST be written and failing before any implementation)

**Purpose**: All contract and unit tests for both modules written first. Tests in `test_tools.py` must fail before `server.py` is touched. Tests in `test_index.py` must fail before `index.py` is touched.

> **CRITICAL (Principle III)**: Do not proceed to Phase 3 until T008 confirms all tests below are failing for the right reason.

- [X] T002 Update `test_recall_semantic_raises_tool_error_when_ollama_down` (line 247) in `memory-server/tests/contract/test_tools.py` to assert `degraded: true` + results returned — not ToolError raised (this test inverts current behavior; it must fail immediately after this edit)
- [X] T003 Add `test_recall_model_error_still_raises_tool_error` and `test_recall_non404_response_error_raises_tool_error` in `memory-server/tests/contract/test_tools.py`: (a) `ollama_sdk.ResponseError` with `status_code=404` raises `ToolError(EMBEDDING_MODEL_ERROR)`; (b) `ollama_sdk.ResponseError` with `status_code=500` raises `ToolError` (not returns `degraded: true`) — both verify that ResponseError never triggers fallback (FR-009, ADR-039, ADR-044)
- [X] T004 Add `test_recall_config_error_message_includes_url` in `memory-server/tests/contract/test_tools.py` asserting the error string from a bad-URL `EMBEDDING_CONFIG_ERROR` includes the actual URL value and names `OLLAMA_BASE_URL` (FR-011)
- [X] T004a Add `test_recall_config_error_not_caught_by_fallback_handler` in `memory-server/tests/contract/test_tools.py`: mock `_embed_text` to raise `ToolError("EMBEDDING_CONFIG_ERROR: ...")` and assert `memory_recall` re-raises `ToolError` (not returns `degraded: true`) — guards the INVARIANT block in plan.md that CONFIG_ERROR must never be swallowed by the fallback handler (ADR-039)
- [X] T005 Add `test_recall_degraded_absent_on_semantic_path` and `test_recall_summary_only_no_degraded` in `memory-server/tests/contract/test_tools.py` (US2: `degraded` key must be absent when Ollama available; `summary_only` path never sets `degraded`)
- [X] T005a Add `test_recall_fallback_emits_stderr_warning` in `memory-server/tests/contract/test_tools.py`: use `capsys`, inject `ConnectionError`, assert stderr contains exact string `[speckit-memory] WARNING: embedding unavailable — falling back to keyword search` (FR-012, ADR-041)
- [X] T006 Add US3 filter/budget contract tests in `memory-server/tests/contract/test_tools.py`: `test_recall_fallback_filter_source_file`, `test_recall_fallback_filters_dict`, `test_recall_fallback_top_k`, `test_recall_fallback_max_chars_and_budget_exhausted` (all assert fallback + Ollama unavailable; use `ConnectionError` injection)
- [X] T006a Add `test_recall_fallback_ignores_min_score` in `memory-server/tests/contract/test_tools.py`: inject `ConnectionError`, populate index with a chunk that would be filtered by `min_score=0.95`, call with `min_score=0.95`, assert chunk appears in results (verifies `min_score` is observably not applied in fallback mode — ADR-040)
- [X] T007 [P] Add `TestKeywordSearch` class in `memory-server/tests/unit/test_index.py` with unit tests: zero-match returns score 0.0, partial match returns intermediate [0,1] score, best-match chunk returns score 1.0 (max-relative normalization), chunk with more occurrences scores higher than chunk with fewer occurrences of same term (FR-003/ADR-043), empty query returns score 0.0 for all rows, result dicts include all required fields (`id`, `content`, `score`, `source_file`, `section`, `type`, `feature`, `date`, `tags`, `synthetic`) and exclude `vector`, `top_k` caps results
- [X] T008 Confirm Phase 2 tests are red: `uv run --directory memory-server pytest tests/contract/test_tools.py tests/unit/test_index.py -v` — must show failures on T002–T007 targets; no false passes

**Checkpoint**: All new/updated tests failing. Implementation may now begin.

---

## Phase 3: User Story 1 — Recall Succeeds When Ollama Is Down (Priority: P1) MVP

**Goal**: When `EMBEDDING_UNAVAILABLE` is raised (connection failure or timeout), `memory_recall` returns keyword-ranked results instead of raising `ToolError`.

**Independent Test**: Given a populated index and Ollama unavailable (simulate `ConnectionError`), when `memory_recall("technology choices architecture decisions")` is called, the response includes at least one result, `degraded: true` is in the envelope, and no `ToolError` is raised.

### Implementation for User Story 1

- [X] T009 [US1] Implement `keyword_search(table, query, top_k, filter_type, filter_feature, filter_tags, filter_source_file)` in `memory-server/speckit_memory/index.py` — occurrence-count TF scoring: `raw = sum(text.lower().count(term) for term in query_terms for text in [row["content"], row["section"]])`; normalize: `score = raw / max_raw if max_raw > 0 else 0.0`; empty query → score 0.0 for all rows; result dicts constructed explicitly with same field list as `vector_search` (ADR-040, ADR-043); `vector` column excluded from output
- [X] T010 [US1] Modify `memory_recall()` in `memory-server/speckit_memory/server.py`: (a) update exception handler — ALL `ResponseError` → `_embed_error()` as hard ToolError (ADR-044; `_embed_error` already routes 404→MODEL_ERROR, others→UNAVAILABLE ToolError); only `(ConnectionError, OSError, httpx.TransportError)` → set `_degraded=True` (network-layer fallback trigger); (b) add fallback branch calling `keyword_search()` with all filter args; (c) emit `[speckit-memory] WARNING: embedding unavailable — falling back to keyword search` to `sys.stderr`; (d) add `degraded: true` to response envelope only when `_degraded`; (e) skip `min_score` filtering in fallback path (ADR-040); (f) fix `_embed_text()` CONFIG_ERROR message to include `f"(got: {_OLLAMA_BASE_URL!r})"` and name `OLLAMA_BASE_URL` (FR-011); do NOT catch `ToolError` in this handler (invariant: CONFIG_ERROR must propagate as hard error, ADR-039)

**Checkpoint**: `uv run --directory memory-server pytest -m "not integration"` — all Phase 2 tests now pass; full unit+contract suite green.

---

## Phase 4: User Story 2 — Callers Can Distinguish Fallback from Semantic Results (Priority: P2)

**Goal**: The `degraded` flag provides a reliable, single-field signal of which path ran — no string parsing, no error inspection.

**Independent Test**: Two calls — Ollama available (no `degraded` key in response) and Ollama unavailable (`degraded: true` in response) — the caller can branch on `response.get("degraded")` alone.

### Verification for User Story 2

- [X] T011 [US2] Verify US2 contract tests pass: `uv run --directory memory-server pytest tests/contract/test_tools.py -k "degraded"` — `test_recall_degraded_absent_on_semantic_path` and `test_recall_summary_only_no_degraded` must pass; no new implementation required if T010 is correct

**Checkpoint**: US2 acceptance scenarios verified. `degraded` key is absent on semantic path; present on fallback path; absent on summary_only path.

---

## Phase 5: User Story 3 — Filters and Budget Enforcement Apply in Fallback Mode (Priority: P3)

**Goal**: Filter parameters (`filters`, `filter_source_file`, `top_k`) and budget enforcement (`max_chars`, `budget_exhausted`) behave identically in fallback mode as in semantic mode — no silently ignored parameters.

**Independent Test**: Index with chunks from features 004, 005, 006; Ollama unavailable; `memory_recall("decisions", filters={"feature": "005"}, max_chars=500)` — response contains only feature-005 chunks and total content ≤ 500 characters.

### Verification for User Story 3

- [X] T012 [US3] Verify US3 contract tests pass: `uv run --directory memory-server pytest tests/contract/test_tools.py -k "filter or budget or top_k"` — all four T006 tests pass; no new implementation required if T009 (keyword_search filter params) and T010 (wiring + budget enforcement) are correct

**Checkpoint**: US3 acceptance scenarios verified. Filters scope results; budget enforcement applies; `top_k` caps results.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T013 [P] Update `CLAUDE.md` — change 007 status line from "In-progress" to reflect BM25 fallback implemented; confirm `OLLAMA_TIMEOUT` env var entry remains accurate (no change needed)
- [X] T013a Verify `specs/007-bm25-keyword-fallback/contracts/memory_recall.md` matches final `server.py` behavior — confirm score description reflects occurrence-count TF, error routing table matches ADR-044 (all `ResponseError` → hard ToolError), and `min_score` behavioral note is present
- [X] T014 Run full test suite to confirm no regressions: `uv run --directory memory-server pytest -m "not integration"` — all pass
- [X] T015 [P] Commit all changes with `feat(007): BM25 keyword fallback for memory_recall — degraded flag, in-process TF scoring`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 — BLOCKS Phases 3–5
- **Phase 3 (US1)**: Depends on Phase 2 — core implementation; enables US2 + US3 checkpoints
- **Phase 4 (US2)**: Depends on Phase 3 — verification only
- **Phase 5 (US3)**: Depends on Phase 3 — verification only; Phases 4 and 5 can run in parallel
- **Phase 6 (Polish)**: Depends on all story verifications passing

### Within Phase 2 (TDD Gates)

| Must complete FIRST | Before starting | Reason |
|---------------------|-----------------|---------|
| T002 (update T010a) + T003 (MODEL_ERROR + non-404 ResponseError tests) + T004 + T004a (CONFIG_ERROR tests) + T005 + T005a (US2 + stderr warning tests) + T006 + T006a (US3 + min_score ignored tests) | T010 (any server.py change) | All test_tools.py tests must be written and failing before server.py is touched |
| T007 (TestKeywordSearch) | T009 (keyword_search() impl) | TDD: failing unit tests must exist before index.py implementation |

### Within Phase 3 (US1 Implementation)

- **T009 before T010**: `keyword_search()` must exist in `index.py` before `server.py` fallback branch calls it
- T009 and T010 are in different files — T009 can be committed first, T010 second

### Parallel Opportunities

- **Phase 2**: T007 (test_index.py) can run in parallel with T002–T006 (test_tools.py) — different files
- **Phases 4 and 5**: Both are verification-only and independent — can run in parallel after Phase 3
- **Phase 6**: T013 and T015 are [P] — can run after T014

---

## Parallel Execution Examples

```bash
# Phase 2: T007 can start while T002-T006 are in progress (different file):
# → Terminal A: editing tests/contract/test_tools.py (T002-T006)
# → Terminal B: editing tests/unit/test_index.py (T007)

# Phases 4 + 5 verification (after Phase 3 complete):
uv run --directory memory-server pytest tests/contract/test_tools.py -k "degraded"   # T011 (US2)
uv run --directory memory-server pytest tests/contract/test_tools.py -k "filter or budget or top_k"  # T012 (US3)
```

---

## Implementation Strategy

### MVP (Phase 3 Only — User Story 1)

1. Complete Phase 1 (baseline verification)
2. Complete Phase 2 (all TDD gates written and failing)
3. Complete Phase 3 (T009 + T010 — core fallback)
4. **STOP and VALIDATE**: Run `pytest -m "not integration"` — confirm all Phase 2 tests pass
5. US2 and US3 acceptance is implicit (the flag and filters are baked into the US1 implementation)

### Full Feature

1. Phase 1 → Phase 2 → Phase 3 → Phases 4 + 5 (parallel) → Phase 6
2. Each phase is a commit checkpoint

---

## Notes

- `EMBEDDING_CONFIG_ERROR` is raised inside `_embed_text()` before any network call — it propagates as `ToolError` and is never caught by the UNAVAILABLE handler. T010 must NOT add `ToolError` to the exception handler (plan.md invariant block).
- `min_score` is skipped in fallback path by design (ADR-040) — TF scores are not comparable to cosine similarity; callers use `degraded: true` as the quality signal instead.
- `summary_only` path does not call `_embed_text()` and is entirely unaffected — `degraded` must never appear on that path.
- Result dicts from `keyword_search()` must be constructed explicitly (same field list as `vector_search` at index.py:204-215) — returning raw scan rows would include the `vector` column (768 floats).
