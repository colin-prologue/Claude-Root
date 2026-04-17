# Research: BM25 Keyword Fallback (007)

**Date**: 2026-04-16
**Feature**: 007-bm25-keyword-fallback

## Decision: Keyword Scoring Algorithm

**Chosen**: In-process term-frequency (TF) scoring over existing table scan (Option B)

**Rationale**: LanceDB native FTS (Option A) requires `pip install lancedb[fts]`, adding a `tantivy` Rust extension that is a new external dependency. It also creates separate `.lance/` FTS index artifacts on disk. Both violate FR-005 ("no separate search index beyond what is already stored") and SC-005 ("no new external dependencies"). In-process TF scoring requires zero new dependencies and extends the existing `scan_chunks` table-scan pattern already used by the `summary_only` path.

**Alternatives considered**:

| Option | Description | Rejected Because |
|--------|-------------|------------------|
| LanceDB native FTS | `create_fts_index()` + `table.search(query, query_type="fts")` | Requires `lancedb[fts]` extra (adds `tantivy`); creates new index artifacts; violates FR-005, SC-005 |
| BM25 with IDF weighting | Full BM25 with document frequency across corpus | Requires corpus-wide stats per query; adds complexity for marginal ranking improvement at ADR/spec corpus size (~50-200 chunks) |
| In-process TF scoring (chosen) | `score = unique_matching_terms / total_query_terms` → [0,1] | None — meets all constraints |

## Scoring Formula

```
terms = set(query.lower().split())  # deduplicate; lowercase
if not terms:
    score = 0.0  # empty query → all chunks score 0; return in table order
else:
    haystack = (row['content'] + ' ' + row['section']).lower()
    matches = sum(1 for t in terms if t in haystack)
    score = matches / len(terms)  # proportion of query terms found; [0,1]
```

Properties:
- [0,1] normalized (ADR-040: same range as semantic cosine similarity)
- Zero-dependency
- Handles empty query cleanly (score=0 → table order)
- Matches against both `content` and `section` (FR-002)
- Deterministic (same query → same ranking)

## Fallback Trigger Mechanism

The current semantic path catches `(ConnectionError, OSError, httpx.TransportError, ollama_sdk.ResponseError)` and raises `_embed_error(...)`. For 007, this catch block must split on exception type:

- `ollama_sdk.ResponseError` with `status_code == 404` → `EMBEDDING_MODEL_ERROR` → hard error, no fallback (FR-009)
- All other `ollama_sdk.ResponseError` → `EMBEDDING_UNAVAILABLE` → BM25 fallback
- `(ConnectionError, OSError, httpx.TransportError)` → `EMBEDDING_UNAVAILABLE` → BM25 fallback

`EMBEDDING_CONFIG_ERROR` is raised by `_embed_text` before any network call — it already surfaces as a hard `ToolError` and is never caught by the exception handler. No change needed for that path (ADR-039). However, FR-011 requires the message to include the bad URL value — `_embed_text` must be updated to include `_OLLAMA_BASE_URL` in the error string.

## T010a Test Impact

`tests/contract/test_tools.py:247` (`test_recall_semantic_raises_tool_error_when_ollama_down`) currently asserts that `ConnectionError` triggers a `ToolError(EMBEDDING_UNAVAILABLE)`. Feature 007 inverts this: `ConnectionError` now triggers BM25 fallback. The test must be updated to:
1. Assert `degraded: true` is returned (not a ToolError raised)
2. A new test must cover `EMBEDDING_MODEL_ERROR` (404 ResponseError) still raises ToolError

## LOC Estimate

| File | Change | Est. LOC |
|------|--------|----------|
| `speckit_memory/index.py` | Add `keyword_search()` | +30 |
| `speckit_memory/server.py` | Split exception handler, fallback branch, degraded flag, FR-011 fix | +28 |
| `tests/unit/test_index.py` | `TestKeywordSearch` class | +45 |
| `tests/contract/test_tools.py` | Update T010a + new BM25 contract tests | +38 |
| `contracts/memory_recall.md` | Updated tool contract | — |
| **Total** | | **~141 LOC** |

Well within the 300 LOC PR limit (constitution PR Policy).
