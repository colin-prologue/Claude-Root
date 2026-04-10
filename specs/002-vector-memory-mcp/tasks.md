# Tasks: Vector-Backed Semantic Memory

**Input**: Design documents from `specs/002-vector-memory-mcp/`
**Branch**: `002-vector-memory-mcp`
**Generated**: 2026-04-07 | **Revised**: 2026-04-07 (post-review fixes: C1 Phase 2 TDD gap, H1 stale refs, H2 Ollama isolation, H3 LOC estimate, M1-M4)

**Sources**: plan.md (tech stack, PR split), spec.md (4 user stories), data-model.md (Chunk + Manifest schemas), contracts/mcp-tools.md (4 tool contracts), research.md (decisions), quickstart.md (falsification criteria)

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4)
- Exact file paths in all descriptions
- One file, one concern per task

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and package structure. No prior state required.

- [X] T001 Create `memory-server/pyproject.toml` with `[project]` metadata, `speckit-memory` console script entry point, and runtime deps: fastmcp, lancedb, ollama, plus dev deps: pytest, pytest-asyncio
- [X] T002 Create `memory-server/speckit_memory/__init__.py`, `server.py`, `index.py`, `sync.py` as empty module stubs (import-safe, no logic yet)
- [X] T003 [P] Add `.specify/memory/.index/` to `.gitignore` at repo root (volatile index must never be committed)

**Checkpoint**: Package structure exists; `uv run --directory memory-server python -m speckit_memory.server` imports without error.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core data layer shared by all user stories — chunker, LanceDB schema, Manifest I/O, and test infrastructure.

**⚠️ CRITICAL**: No user story implementation can begin until this phase is complete.

- [X] T004 [P] Write unit tests for chunking algorithm in `memory-server/tests/unit/test_chunker.py` — must cover: H1/H2 heading split, max-chunk size with continuation prefix, min-size section merged into following section, no-headings file produces single chunk, YAML frontmatter excluded from chunk content (FAIL before T007)
- [X] T005 [P] Write unit tests for LanceDB and manifest operations in `memory-server/tests/unit/test_index.py` — must cover: table schema initialization, manifest JSON round-trip, insert-batch persists correct fields, delete-by-source-file removes all matching chunks (FAIL before T008) *(added post-review: C1 — Principle III NON-NEGOTIABLE)*
- [X] T006 [P] Create `memory-server/tests/conftest.py` with deterministic fake embedder fixture (callable returning a fixed 768-dim zero vector) for use in contract and unit tests without a live Ollama process *(added post-review: H2 — Ollama test isolation)*
- [X] T007 Implement heading-aware chunking algorithm (H1/H2 split, 1500-token max, 50-char min, `{heading} (continued)` prefix, frontmatter strip) in `memory-server/speckit_memory/sync.py`
- [X] T008 Define `Chunk` LanceDB table schema (id, content, vector, source_file, section, type, feature, date, tags, synthetic) and table initialization in `memory-server/speckit_memory/index.py`
- [X] T009 Implement Manifest JSON read/write (load from `.specify/memory/.index/manifest.json`, save, add/update entry, remove entry) in `memory-server/speckit_memory/index.py`
- [X] T010 Implement insert-chunks-batch LanceDB operation in `memory-server/speckit_memory/index.py`
- [X] T011 [P] Implement delete-all-chunks-by-source-file LanceDB operation in `memory-server/speckit_memory/index.py`

**Checkpoint**: All unit tests pass (`pytest memory-server/tests/unit/`). LanceDB table can be created, written to, and queried programmatically. Fake embedder fixture importable from `conftest.py`.

---

## Phase 3: User Story 1 — Semantic Recall Before Planned Work (Priority: P1) 🎯 MVP

**Goal**: `memory_recall` returns semantically ranked chunks from the indexed corpus within 3 seconds.

**Independent Test**: Given a project with at least three ADRs in `.specify/memory/`, when a speckit command invokes `memory_recall("panel composition")`, then relevant ADR chunks are returned ranked by semantic similarity within 3 seconds — without the user providing manual context.

### Tests for User Story 1

> **Write these tests FIRST, ensure they FAIL before T013**

- [X] T012 [P] [US1] Write contract test for `memory_recall` in `memory-server/tests/contract/test_tools.py` — covers: ranked results returned within 3s, empty result on no match, metadata filter `{type: "adr"}` narrows results, score-below-`min_score` returns empty, near-duplicate chunks from different files both stored (use fake embedder fixture from conftest.py)

### Implementation for User Story 1

- [X] T013 [US1] Implement Ollama embedding HTTP call (POST to `{OLLAMA_BASE_URL}/api/embeddings`, model from `OLLAMA_MODEL` env) in `memory-server/speckit_memory/sync.py`
- [X] T014 [US1] Implement L2-normalize-on-write for chunk vectors before LanceDB insert in `memory-server/speckit_memory/index.py`
- [X] T015 [US1] Implement vector similarity search with metadata pre-filter (AND-combine type/feature/tags filters before ranking) and `min_score` threshold in `memory-server/speckit_memory/index.py`
- [X] T016 [US1] Implement file crawl for configured index paths with type inference from path prefix (ADR_* → adr, LOG_* → log, specs/*/spec.md → spec, constitution.md → constitution) in `memory-server/speckit_memory/sync.py`
- [X] T017 [US1] Implement process-lifetime first-call flag for self-init sync trigger (ADR-011): set flag on server startup, run minimal sync before first tool call returns in `memory-server/speckit_memory/server.py`
- [X] T018 [US1] Implement `memory_recall` FastMCP tool (trigger self-init if first call → embed query → apply filter → vector search → return ranked results with metadata) in `memory-server/speckit_memory/server.py`
- [X] T019 [US1] Wire FastMCP app, `if __name__ == "__main__"` entry point, and `speckit-memory` console script invocation in `memory-server/speckit_memory/server.py`

**Checkpoint**: `pytest memory-server/tests/contract/test_tools.py::test_recall_*` passes. Starting the server and calling `memory_recall("panel composition")` returns ADR chunks in < 3s.

---

## Phase 4: User Story 2 — Index Stays Current Without Manual Effort (Priority: P1)

**Goal**: Session-start sync detects changed files automatically; explicit `memory_sync` handles mid-session updates and full re-index.

**Independent Test**: Given a project with an existing index, when a new ADR is written and committed, then a new session's first `memory_recall` query returns content from that ADR without any manual sync step from the developer.

### Tests for User Story 2

> **Write these tests FIRST, ensure they FAIL before T026**

- [X] T020 [P] [US2] Write contract test for `memory_sync` in `memory-server/tests/contract/test_tools.py` — covers: returns `{indexed, skipped, deleted, duration_ms, model}` stats, `MODEL_MISMATCH` error format (FAIL before T026) *(M2 fix: was "FAIL before T023")*
- [X] T021 [P] [US2] Write integration tests for sync in `memory-server/tests/integration/test_sync.py` — covers: `test_new_file_becomes_queryable`, `test_deleted_file_purges_chunks`, `test_no_headings_produces_single_chunk`, `test_unchanged_file_skipped`, `test_unchanged_file_sync_under_500ms` (assert `duration_ms < 500` when no files changed — SC-002)

### Implementation for User Story 2

- [X] T022 [US2] Implement mtime-diff detection (compare filesystem mtime to manifest entries, classify each file as new/stale/unchanged/deleted) in `memory-server/speckit_memory/sync.py`
- [X] T023 [US2] Implement deleted-file purge in sync (remove LanceDB chunks + manifest entry for files absent from filesystem) in `memory-server/speckit_memory/sync.py`
- [X] T024 [US2] Implement full re-index mode (`full: true`): drop LanceDB table, reset manifest to empty, crawl and embed all configured paths in `memory-server/speckit_memory/sync.py`
- [X] T025 [US2] Implement configurable index paths via `MEMORY_INDEX_PATH` env var with default glob patterns from data-model.md (ADR_*.md, LOG_*.md, constitution.md, specs/*/spec.md, specs/*/plan.md) in `memory-server/speckit_memory/sync.py`
- [X] T026 [US2] Implement `memory_sync` FastMCP tool (orchestrate mtime-diff → embed stale/new → purge deleted → update manifest → return stats) in `memory-server/speckit_memory/server.py`

**Checkpoint**: `pytest memory-server/tests/integration/test_sync.py` passes. New session with a fresh ADR returns it in recall without manual steps.

---

## Phase 5: User Story 3 — Skills Store Work Summaries for Future Recall (Priority: P2)

**Goal**: Speckit skills can persist command output summaries via `memory_store`; stored chunks are immediately queryable and deletable.

**Independent Test**: Given a completed spec for feature 002, when `memory_recall("vector memory embedding model")` is called in a separate session, then the stored spec summary surfaces the embedding model decision without the caller reading `specs/002-vector-memory-mcp/spec.md`.

### Tests for User Story 3

> **Write these tests FIRST, ensure they FAIL before T029**

- [X] T027 [P] [US3] Write contract tests for `memory_store` in `memory-server/tests/contract/test_tools.py` — covers: returns `{id, status: "stored"}`, non-existent `source_file` sets `synthetic: true` flag, stored chunk is queryable within same session
- [X] T028 [US3] Write contract tests for `memory_delete` in `memory-server/tests/contract/test_tools.py` — covers: delete-by-source-file removes all chunks, delete-by-id removes exactly one chunk, providing both or neither returns `INVALID_INPUT`, delete of missing file returns `deleted_chunks: 0` *(M1 fix: [P] removed — same file as T027)*

### Implementation for User Story 3

- [X] T029 [US3] Implement delete-chunk-by-id LanceDB operation in `memory-server/speckit_memory/index.py`
- [X] T030 [US3] Implement `memory_store` FastMCP tool (embed content, assign UUID, set `synthetic: true` if source_file not on disk, persist chunk with all metadata fields) in `memory-server/speckit_memory/server.py`
- [X] T031 [US3] Implement `memory_delete` FastMCP tool (validate exactly-one of source_file/id, dispatch to delete-by-source-file or delete-by-id, return envelope) in `memory-server/speckit_memory/server.py`
- [X] T032 [US3] Add recall-before / store-after convention to `.claude/rules/memory-convention.md` (which skills must recall, which must store, format for stored summaries)

**Checkpoint**: `pytest memory-server/tests/contract/test_tools.py` fully passes. Calling `memory_store` then `memory_recall` in the same session returns the stored chunk.

---

## Phase 6: User Story 4 — Embedding Model Is Configurable (Priority: P2)

**Goal**: Ollama model is configurable via env; switching models triggers full re-index; mismatches produce clear, recoverable errors.

**Independent Test**: Given a project configured to use a local Ollama model, when `memory_recall("ADR panel composition")` is called with no internet access, then relevant chunks are returned correctly.

### Tests for User Story 4

> **Write these tests FIRST, ensure they FAIL before T034**

- [X] T033 [P] [US4] Write fault scenario tests in `memory-server/tests/integration/test_fault_scenarios.py` — covers: `test_model_mismatch_errors_clearly` (MODEL_MISMATCH code, `recoverable: false`), `test_api_unavailable_returns_recoverable_error` (API_UNAVAILABLE, `recoverable: true`), `test_manifest_without_db_triggers_full_reindex`

### Implementation for User Story 4

- [X] T034 [US4] Implement `OLLAMA_MODEL` (default: `nomic-embed-text`) and `OLLAMA_BASE_URL` (default: `http://localhost:11434`) env var config wiring in `memory-server/speckit_memory/server.py`
- [X] T035 [US4] Implement model mismatch detection (compare manifest `embedding_model` + `embedding_dimension` vs current config; return `MODEL_MISMATCH` error with `recoverable: false` and advice to run `memory_sync --full`) in `memory-server/speckit_memory/sync.py`
- [X] T036 [US4] Implement `API_UNAVAILABLE` error path (Ollama HTTP unreachable → return error envelope with `recoverable: true`, leave existing index intact) in `memory-server/speckit_memory/sync.py`
- [X] T037 [US4] Implement manifest-present-but-DB-missing detection → automatically trigger full re-index in `memory-server/speckit_memory/sync.py`

**Checkpoint**: `pytest memory-server/tests/integration/test_fault_scenarios.py` passes. Stopping Ollama mid-session returns `API_UNAVAILABLE` without corrupting the index.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Integration artifacts, calibration, and verification.

- [X] T038 Create `.mcp.json` at repo root with `memory` server entry: command `uv`, args `["run", "--directory", "memory-server", "speckit-memory"]`, env `MEMORY_INDEX_PATH`, `OLLAMA_BASE_URL`, `OLLAMA_MODEL` (monorepo local install — `uvx` not used since package is not published to PyPI)
- [X] T039 [P] Update `CLAUDE.md`: add `memory-server/` to directory structure, add `uv run --directory memory-server python -m speckit_memory.server` to Commands, note env vars
- [X] T040 [P] Run recall quality calibration spike: invoke `memory_recall` with 5 representative queries against actual `.specify/memory/` corpus, record scores at `min_score=0.5`, append threshold recommendation to `specs/002-vector-memory-mcp/data-model.md` calibration note
  - *Note: Template repo — corpus too sparse for meaningful calibration. See data-model.md calibration note. Run in a real project with ≥10 ADRs.*
- [X] T041 Run quickstart.md falsification criteria end-to-end: (1) `memory_sync` returns `indexed > 0`, (2) `memory_recall("panel composition")` returns ADR content, (3) delete index + re-sync restores identical results, (4) switch model + `memory_sync --full` succeeds without error; (5) **manual**: invoke `/speckit.plan` against a project with indexed ADRs, confirm generated output references at least one ADR by number — SC-005 has no automated coverage and requires human observation
  - *Note: Items 1–4 verified via 42/42 passing tests (2026-04-09). SC-005 (item 5) formally deferred to first real project use — template repo corpus too sparse for meaningful validation. Deferral documented in LOG-017.*

**Checkpoint**: All quickstart falsification criteria pass. `.mcp.json` registers the server in Claude Code.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 — **blocks all user stories**
- **Phase 3 (US1)**: Depends on Phase 2 — MVP deliverable
- **Phase 4 (US2)**: Depends on Phase 2; integrates with Phase 3 sync primitives
- **Phase 5 (US3)**: Depends on Phase 2 (index.py) and Phase 3 (server.py server wiring at T019)
- **Phase 6 (US4)**: Depends on Phase 2 (sync.py) and Phase 3 config wiring (T034 adds env vars to T019's server)
- **Phase 7 (Polish)**: Depends on all prior phases complete

### User Story Dependencies

- **US1 (P1)**: Can start after Foundational — MVP; no dependency on US2, US3, US4
- **US2 (P1)**: Can start after Foundational; re-uses sync primitives built in US1 (T013, T016) — implement after US1 for efficiency
- **US3 (P2)**: Can start after Foundational; depends on server.py wiring (T019 from US1)
- **US4 (P2)**: Can start after Foundational; depends on sync.py Ollama call (T013 from US1) and config wiring (T019)

### Within Each User Story

- Contract/integration tests MUST be written and run (FAIL) before implementation begins
- Foundational layer tasks precede tool implementations
- Server.py tool task after all supporting index.py and sync.py tasks

### Parallel Opportunities Per Story

**Phase 2 (Foundational)**:
```
T004 + T005 + T006 — all parallel (three different files: test_chunker.py, test_index.py, conftest.py)
T007 after T004 passes; T008-T011 after T005 passes
```

**US1 (Phase 3)**:
```
T012 (contract test) — parallel with Phase 2 completion check
T013 + T014 + T015 — sequential (embed → normalize → search pipeline)
T016 + T017 — can run in parallel after T013 (different files: sync.py, server.py)
T018 requires T015, T017 complete
T019 requires T018 complete
```

**US2 (Phase 4)**:
```
T020 + T021 — write in parallel (different test files: test_tools.py, test_sync.py)
T022, T023, T024, T025 — all write to sync.py; work sequentially, not in parallel
T026 requires T022-T025 complete
```

**US3 (Phase 5)**:
```
T027 — parallel if resources allow (test_tools.py, first write in this phase)
T028 — after T027 (same file: test_tools.py)
T029 — can start after T005 passes (index.py, independent of T027/T028)
T030 + T031 — sequential in server.py after T029
```

**US4 (Phase 6)**:
```
T033 (fault tests) — parallel with US3 work (different file)
T034 — after T019 (adds to server.py config)
T035 + T036 + T037 — sequential in sync.py after T035 dependency
```

---

## PR Split (from plan.md, estimates revised upward)

| PR | Content | Est. LOC | Tasks |
|---|---|---|---|
| PR-1: Core server | Phase 1–3 + US3 contract tests (T027, T028) + US4 env config (T034) | ~280 *(revised from ~220; if it exceeds 270 LOC, extract T008-T011 as a standalone PR between PR-1 and PR-2)* | T001–T019, T027, T028, T034 |
| PR-2: Integration + fault tests | Phase 4 (T020–T026), US3 impl (T029–T032), US4 faults (T033, T035–T037) | ~130 | T020–T026, T029–T033, T035–T037 |
| PR-3: Skill integration | Phase 7 (T038–T041) | ~80 | T038–T041 |

---

## Implementation Strategy

### MVP (US1 only — PR-1 subset)

1. Complete Phase 1: Setup (T001–T003)
2. Complete Phase 2: Foundational (T004–T011) — **required before anything else**
3. Write US1 contract test (T012) — verify it FAILS
4. Complete US1 implementation (T013–T019)
5. **STOP AND VALIDATE**: `pytest memory-server/tests/` passes; `memory_recall` returns real ADR chunks

### Incremental Delivery

1. Phase 1 + 2 → Foundation ready
2. Phase 3 (US1) → Recall works; PR-1 (minus US3 contract tests) ready to review
3. Phase 4 (US2) → Sync correctness confirmed; PR-2 integration tests ready
4. Phase 5 (US3) → Store/delete works; add to PR-2
5. Phase 6 (US4) → Fault handling complete; PR-2 done
6. Phase 7 (Polish) → PR-3 ready; feature complete

---

## Notes

- [P] = genuinely different files or independent concerns; no shared state with sibling [P] tasks
- TDD is mandatory: every test task must produce a FAILING test before implementation begins
- Commit after each completed task or phase checkpoint
- **Ollama test isolation** (H2): The `conftest.py` fake embedder fixture (T006) makes contract and unit tests runnable without a live Ollama process. Integration tests (`test_sync.py`, `test_fault_scenarios.py`) require Ollama running; mark them with `@pytest.mark.integration` and document that `pytest -m "not integration"` runs without Ollama.
- The chunker (T007) is the highest-risk unit — its output directly determines recall quality. If unit tests (T004) reveal design gaps, fix before proceeding to US1.
- The `min_score=0.5` default (T040 calibration) is unvalidated; do not finalize this value without running T040 against the real corpus.
- **Atomicity of delete-then-insert** (M4 accepted risk): T010 + T011 (and the sync flow that uses them) replace file chunks via delete-then-insert — two separate LanceDB operations with no transaction guarantee. A crash between them leaves that file's chunks absent until the next sync recovers them. This is acceptable for a solo-dev local tool where next-sync recovery is trivial. No transaction layer warranted (Principle II).
- PR-1 LOC estimate is ~280 (revised upward from ~220). If it exceeds 270 LOC during implementation, extract `index.py` tasks (T008–T011) into a standalone PR before PR-1.
