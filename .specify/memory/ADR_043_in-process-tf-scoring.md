# ADR-043: In-Process Term-Frequency Scoring for BM25 Fallback

**Date**: 2026-04-16
**Status**: Accepted
**Decision Made In**: specs/007-bm25-keyword-fallback/research.md § Decision: Keyword Scoring Algorithm
**Related Logs**: None

---

## Context

Feature 007 adds a BM25/keyword fallback to `memory_recall`. When `EMBEDDING_UNAVAILABLE` is detected, the tool must return keyword-ranked results rather than a hard error. Two approaches were evaluated: LanceDB's native full-text search (FTS) capability, and in-process term-frequency scoring over the existing table scan.

The spec constraints (FR-005, SC-005) rule out any approach that adds external dependencies or requires a separate search index. LanceDB native FTS fails on both counts. The corpus size (~50-200 chunks for a typical ADR/spec project) makes full BM25 with IDF over-engineered.

## Decision

Use in-process occurrence-count TF scoring: for each chunk, compute `raw_score = sum of occurrences of each query term in (content + section)`; normalize to [0,1] by dividing by the maximum raw score across all candidate chunks (or 1 if max is 0). This gives the best-matching chunk a score of 1.0, non-matching chunks a score of 0.0, and intermediate scores that reflect actual term frequency rather than binary presence. Computed over `chunk.content + chunk.section` with case-folding. No new dependencies. No new index files. Implemented as a new `keyword_search()` function in `index.py`, parallel to `vector_search()`.

## Alternatives Considered

### Option A: In-process occurrence-count TF scoring *(chosen)*

Pure Python term matching over `scan_chunks` table scan. Raw score = sum of term occurrences in content+section; normalized to [0,1] by max-relative normalization across result set.

**Pros**: Zero new dependencies; no new index artifacts; consistent with `scan_chunks` pattern already used by `summary_only`; corpus size (~50-200 chunks) makes simple scoring sufficient; occurrence-count gives graded ranking within a result set (a chunk mentioning "architecture" 5 times scores higher than one mentioning it once); formula produces [0,1] values compatible with the ADR-040 contract
**Cons**: Not true BM25 (no IDF, no document length normalization); ranking quality lower than full BM25 — acceptable per spec; max-relative normalization requires collecting all scores before normalizing (two-step, still O(n))

### Option B: LanceDB native FTS (`lancedb[fts]`)

`create_fts_index()` + `table.search(query, query_type="fts")` using Tantivy under the hood.

**Pros**: True full-text search with proper tokenization; potentially better ranking for multi-term queries
**Cons**: Requires `pip install lancedb[fts]` — adds Rust-compiled `tantivy` extension (new external dependency); creates separate FTS index files in `.lance/` directory; violates FR-005 and SC-005; introduces a new index maintenance concern

### Option C: Full BM25 with IDF

Compute document frequency across corpus per query.

**Pros**: Better ranking accuracy
**Cons**: Requires corpus-wide stats scan (one pass to build IDF table, one to score) — adds complexity without meaningful quality improvement at corpus sizes of 50-200 chunks

## Rationale

Option A was chosen because the two hard constraints (no new deps, no new index artifacts) immediately eliminate Option B. Option C is more accurate than A but the marginal quality improvement doesn't justify the complexity at the expected corpus size. The `degraded: true` flag already communicates to callers that ranking quality is lower — no need to over-engineer the fallback scorer.

## Consequences

**Positive**: Zero new dependencies; no index maintenance; simple formula is auditable and testable; consistent with existing code patterns
**Negative / Trade-offs**: Not true BM25 — no IDF, no length normalization; ranking may not reflect term rarity across corpus
**Risks**: If corpus grows significantly (thousands of chunks), ranking quality gap between TF and BM25 may become noticeable — mitigated by `degraded: true` signal
**Follow-on decisions required**: None

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-16 | Initial record | Claude (speckit.plan research) |
| 2026-04-17 | Updated formula from set-intersection binary presence to occurrence-count TF with max-relative [0,1] normalization — original "unique_matching_terms / total_query_terms" was set membership, not TF; produced wide tie bands at typical corpus size (ADR-043 amendment, task-gate review M-1) | Claude (speckit.review) |
| 2026-04-17 | Documented that the implementation uses Python `str.count()` on lowercased text, which is **substring matching** (not token matching): `"arch"` matches `"architecture"`. This is intentional — partial tokens legitimately surface relevant chunks. Short stop-word tokens (e.g., `"a"`, `"is"`) inflate scores; callers should strip punctuation and avoid stop words. The `keyword_search` docstring carries a `>= 4 char` guideline for reliable ranking. These are caller-contract details, not a change to the scoring formula. | Claude (speckit.audit) |
