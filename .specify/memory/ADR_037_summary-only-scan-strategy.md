# ADR-037: summary_only Bypass — Table Scan Without Vector

**Date**: 2026-04-14
**Status**: Accepted
**Decision Made In**: specs/006-ollama-fallback/plan.md § Phase 0 Research / research.md Finding 3
**Related Logs**: LOG-034

---

## Context

`memory_recall(summary_only=True)` is intended to return source_file + section metadata without ranking results by relevance. FR-006 requires this mode to succeed when Ollama is unavailable.

The current implementation calls `_embed_text(query)` unconditionally at line 123 of `server.py`, before the `summary_only` flag is checked at line 146. This means Ollama is always contacted, even in summary_only mode — the exact opposite of what FR-006 requires.

Making `summary_only` bypass Ollama requires a second retrieval code path: instead of embedding the query and doing a vector similarity search, retrieve chunks directly from the LanceDB table without a query vector.

## Decision

Add `scan_chunks(table, top_k, filters, filter_source_file)` to `index.py`. In `memory_recall`, check `summary_only` before calling `_embed_text`. If `summary_only=True`, call `scan_chunks` and skip `_embed_text` + `vector_search` entirely. Results are returned without a score field.

`scan_chunks` does a Python-level filter over `table.to_arrow().to_pylist()`, returning rows limited to `top_k`, in insertion order. No semantic ranking.

## Alternatives Considered

### Option A: Table scan, no score field *(chosen)*

Add `scan_chunks` to `index.py`. When `summary_only=True`, skip embedding and return unranked rows.

**Pros**: Satisfies FR-006; zero Ollama contact; ~20 LOC; honest result (no fabricated scores)
**Cons**: Results are unranked; score field absent from summary_only responses when bypassed

### Option B: Always require embedding, even in summary_only mode

Keep current behavior. summary_only fails when Ollama is down.

**Pros**: Consistent code path; consistent result shape (always has score)
**Cons**: Directly contradicts FR-006 (P1 requirement); defeats the purpose of the mode

### Option C: Detect Ollama availability first, choose path accordingly

Issue a health-check call before deciding whether to embed or scan.

**Pros**: Ranked results when Ollama is available; scan fallback when down
**Cons**: Adds one Ollama call per recall in the happy path — extra latency; startup health check is explicitly excluded from 006 scope (spec Out of Scope section)

## Rationale

Option A satisfies FR-006 with minimal code. Option B contradicts the spec. Option C adds a health-check prelude that the spec explicitly excluded.

The missing score field is an acceptable trade-off: `summary_only` callers request a directory of sources (which sections exist), not ranked results. The query parameter is context for future embed-based recall — when Ollama is unavailable, position-order is a correct fallback.

## Consequences

**Positive**: FR-006 satisfied; `memory_recall` usable when Ollama is down; reduces code path complexity in the happy path (no Ollama call needed for summary_only)
**Negative / Trade-offs**: summary_only results are unranked when Ollama is bypassed; score field absent — callers must handle both shapes
**Risks**: A caller that assumes score is always present will KeyError. No known programmatic callers of score in summary_only context; Claude Code displays results as text.
**Follow-on decisions required**: None

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-14 | Initial record | Claude (plan phase) |
