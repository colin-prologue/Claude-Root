# Implementation Plan: BM25 Keyword Fallback for memory_recall

**Branch**: `007-bm25-keyword-fallback` | **Date**: 2026-04-16 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/007-bm25-keyword-fallback/spec.md`

## Summary

`memory_recall` currently raises a hard `ToolError(EMBEDDING_UNAVAILABLE)` when Ollama is unreachable. Feature 007 adds a BM25/keyword fallback: when `EMBEDDING_UNAVAILABLE` is detected (connection failure or timeout), the tool falls back to in-process term-frequency scoring over the existing LanceDB table scan, returns ranked results, and adds `degraded: true` to the response envelope. `EMBEDDING_CONFIG_ERROR` and `EMBEDDING_MODEL_ERROR` remain hard errors (misconfigurations). The implementation extends two existing files (`index.py`, `server.py`) with no new external dependencies.

## Decision Records

| # | Type | File | Title | Status |
|---|---|---|---|---|
| ADR-039 | Decision | ADR_039_config-error-no-fallback.md | EMBEDDING_CONFIG_ERROR Does Not Trigger BM25 Fallback | Accepted |
| ADR-040 | Decision | ADR_040_fallback-score-normalized.md | Fallback Results Include Normalized [0,1] Score Field | Accepted |
| ADR-041 | Decision | ADR_041_fallback-stderr-warning.md | BM25 Fallback Emits stderr Warning | Accepted |
| ADR-043 | Decision | ADR_043_in-process-tf-scoring.md | In-Process Term-Frequency Scoring for BM25 Fallback | Accepted |
| ADR-044 | Decision | ADR_044_response-error-no-fallback.md | ResponseError Does Not Trigger BM25 Fallback | Accepted |
| LOG-042 | Update | LOG_042_fallback-score-spec-replacement.md | Spec Statement Replacement — Fallback Score Exposure | Resolved |
| LOG-045 | Challenge | LOG_045_response-error-routing-challenge.md | ResponseError Routing Challenge — Hard Error vs Fallback at Task-Gate Review | Resolved |
| LOG-046 | Update | LOG_046_timeout-message-dead-in-recall.md | TimeoutException Message Unreachable in memory_recall | Accepted |
| LOG-047 | Update | LOG_047_silent-fallback-visibility.md | Silent Fallback Visibility Gap | Open |
| LOG-048 | Update | LOG_048_store-sync-fallback-asymmetry.md | Store/Sync Fallback Asymmetry | Open |

## Technical Context

**Language/Version**: Python 3.10+
**Primary Dependencies**: FastMCP 2.0+, LanceDB 0.13+, pyarrow, httpx, ollama SDK — **no new dependencies**
**Storage**: LanceDB embedded (`.specify/memory/.index/chunks.lance/`) — unchanged
**Testing**: pytest + pytest-asyncio 8.0+
**Target Platform**: Local MCP server (macOS/Linux)
**Project Type**: MCP library server
**Performance Goals**: Fallback latency ≤ summary_only table scan (no network calls; in-process only)
**Constraints**: ≤300 LOC PR; no new external deps; no new index files; no changes to chunk schema
**Scale/Scope**: Typical corpus 50-200 chunks; top_k capped at 20

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Before agreeing on this approach, confirm all three passes have been completed:
- [x] **Pass 1 — Assumptions**: "scan_chunks is a sufficient base for keyword scoring" → confirmed; it returns all fields needed for TF scoring. "No new deps are needed" → confirmed after ruling out lancedb[fts]. "Test T010a will break" → confirmed; it must be updated.
- [x] **Pass 2 — Research**: LanceDB FTS ruled out (adds tantivy dep + new index artifacts, violates FR-005/SC-005). In-process TF formula validated against FR-002 (content + section), ADR-040 ([0,1] range), ADR-041 (stderr warning). Research.md written.
- [x] **Pass 3 — Plan scrutiny**: Riskiest decision: exception handler split for MODEL_ERROR vs UNAVAILABLE. Validated: `ollama_sdk.ResponseError` with `status_code == 404` is MODEL_ERROR (hard error). All other `ResponseError` (500, 400, 401, 403 etc.) also raise as hard errors via `_embed_error` — Ollama HTTP errors are not "service unreachable" and must not silently fall back. Only true network-layer exceptions `(ConnectionError, OSError, httpx.TransportError)` trigger fallback — these unambiguously mean the service is unreachable. CONFIG_ERROR is raised before the try block. (ADR-044)

- [x] Principle I: Spec approved, clarifications complete (3 clarifications, 5 ADRs recorded)
- [x] Principle II: No speculative abstractions — adds one function (`keyword_search`) to `index.py` and modifies one path in `server.py`; no new files, no wrappers
- [x] Principle III: TDD confirmed — unit tests for `keyword_search` written before implementation; contract test T010a updated before server.py changes
- [x] Principle IV: P1 (fallback succeeds) → P2 (degraded flag) → P3 (filters/budget) are sequential deliverables; each is testable in isolation
- [x] PR Policy: ~141 LOC estimated — under 300 LOC limit; single PR acceptable

## Project Structure

### Documentation (this feature)

```text
specs/007-bm25-keyword-fallback/
├── plan.md              # This file
├── research.md          # Phase 0: algorithm choice, LOC estimate, T010a impact
├── contracts/
│   └── memory_recall.md # Updated tool contract: degraded flag, score field, error routing
├── checklists/
│   └── requirements.md  # Spec quality checklist (speckit.clarify)
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code Changes

```text
memory-server/
  speckit_memory/
    index.py              # ADD keyword_search() — ~30 LOC
    server.py             # MODIFY memory_recall() semantic path — ~28 LOC
                          #   - Split exception handler (MODEL_ERROR vs UNAVAILABLE)
                          #   - Add BM25 fallback branch + degraded flag + stderr warning
                          #   - Fix _embed_text() CONFIG_ERROR message (FR-011)
  tests/
    unit/
      test_index.py       # ADD TestKeywordSearch class — ~45 LOC
    contract/
      test_tools.py       # UPDATE T010a + ADD BM25 contract tests — ~38 LOC
```

**No new files in speckit_memory/; no schema changes; no new dependencies.**

### Key Implementation Details

**`keyword_search()` in index.py** (new function, parallel to `vector_search` and `scan_chunks`):

```python
def keyword_search(
    table, query, top_k=5,
    filter_type=None, filter_feature=None,
    filter_tags=None, filter_source_file=None,
) -> list[dict]:
    # 1. Table scan with existing filter logic (same as scan_chunks)
    # 2. Score each row: raw = sum of occurrences of each query term in content+section (case-folded);
    #    normalize: score = raw / max(raw across all rows) if max > 0 else 0.0
    # 3. Sort descending by score
    # 4. Return top_k with same fields as vector_search (including score)
    #    IMPORTANT: Construct result dicts explicitly (same field list as vector_search
    #    at index.py:204-215). Do NOT return raw scan rows — they include the `vector`
    #    column (768 floats) which must be excluded from the output.
```

**`memory_recall()` semantic path changes in server.py**:

Before (006):
```python
try:
    query_vec = _embed_text(query)
except (ConnectionError, OSError, httpx.TransportError, ollama_sdk.ResponseError) as exc:
    raise _embed_error(exc, _OLLAMA_MODEL)
```

After (007):
```python
_degraded = False
try:
    query_vec = _embed_text(query)
except ollama_sdk.ResponseError as exc:
    raise _embed_error(exc, _OLLAMA_MODEL)  # ALL ResponseError → hard ToolError (ADR-044)
                                             # _embed_error routes 404 → MODEL_ERROR,
                                             # everything else → UNAVAILABLE ToolError
except (ConnectionError, OSError, httpx.TransportError) as exc:
    print("[speckit-memory] WARNING: embedding unavailable — falling back to keyword search", file=sys.stderr)
    _degraded = True
```

> **INVARIANT**: The except block MUST NOT catch `ToolError` or widen to `except Exception`. `ToolError` raised by `_embed_text()` is `EMBEDDING_CONFIG_ERROR` and must propagate as a hard error (ADR-039). `ollama_sdk.ResponseError` must never trigger fallback (ADR-044) — only network-layer exceptions `(ConnectionError, OSError, httpx.TransportError)` represent "service unreachable" and trigger fallback.

**`_embed_text()` CONFIG_ERROR fix** (FR-011):
```python
# Before:
raise ToolError("EMBEDDING_CONFIG_ERROR: OLLAMA_BASE_URL is not a valid HTTP/HTTPS URL. "
                "Hint: check the value of the OLLAMA_BASE_URL environment variable.")
# After:
raise ToolError(
    f"EMBEDDING_CONFIG_ERROR: OLLAMA_BASE_URL is not a valid HTTP/HTTPS URL "
    f"(got: {_OLLAMA_BASE_URL!r}). "
    "Hint: set OLLAMA_BASE_URL to a valid http:// or https:// URL."
)
```

**T010a test update** (contract/test_tools.py): The existing test asserts ToolError is raised on ConnectionError. It must be updated to assert `degraded: true` is returned. A new test must assert that `ollama_sdk.ResponseError(status_code=404)` still raises `ToolError(EMBEDDING_MODEL_ERROR)`.

## Implementation Order Constraints

> **TASK GENERATOR: These ordering rules are HARD DEPENDENCIES. Violating them breaks TDD (Principle III).**

| Must complete FIRST | Before starting | Reason |
|---------------------|-----------------|--------|
| Update T010a contract test (`test_recall_semantic_raises_tool_error_when_ollama_down`) to assert `degraded: true` is returned instead of `ToolError` | Any changes to `server.py` semantic path | T010a currently asserts the behavior that 007 inverts. Changing server.py first would make the old test pass for the wrong reason — the test must fail on `ConnectionError` returning results (not raising) BEFORE the fallback is implemented. |
| Add `keyword_search()` unit tests in `test_index.py` | Implementing `keyword_search()` in `index.py` | TDD: failing tests must exist before implementation |
| Add new contract test asserting `EMBEDDING_MODEL_ERROR` (404 ResponseError) still raises `ToolError` | Splitting the exception handler in `server.py` | Without this test, the MODEL_ERROR no-fallback guarantee (FR-009, ADR-039) has no regression coverage |

**Summary**: Write/update all tests for a given module before touching that module's implementation code. The test layer must be red before the implementation turns it green.

## Complexity Tracking

No violations. Feature adds one function and modifies one code path. No abstractions, no new modules.
