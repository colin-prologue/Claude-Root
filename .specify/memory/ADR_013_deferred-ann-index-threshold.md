# ADR-013: Deferred ANN Index Creation at 256-Row Threshold

**Date**: 2026-04-08
**Status**: Accepted
**Decision Made In**: memory-server/speckit_memory/index.py:198-210 (detected during consistency audit)
**Related Logs**: None

---

## Context

LanceDB supports IVF-PQ approximate nearest-neighbor (ANN) indexing for fast vector search at scale. Without an explicit index, all searches are brute-force linear scans. ADR-008 listed ANN indexing as a pro of choosing LanceDB, but the implementation does not create an index unconditionally. The typical corpus for this use case (ADR files, spec files, constitution) contains 50–200 chunks — a size range where brute-force search is faster than ANN lookup due to IVF-PQ's query overhead and minimum training data requirements.

## Decision

We will defer ANN index creation until the table exceeds 256 rows. Below that threshold, brute-force search is used. Once the threshold is crossed, `maybe_create_index()` creates an IVF-PQ index automatically. The call is best-effort (failures are non-fatal; brute-force search remains correct in all cases).

## Alternatives Considered

### Option A: Deferred creation at 256-row threshold *(chosen)*

`maybe_create_index(table, min_rows=256)` called after each batch insert and after sync completion.

**Pros**: No wasted index creation for the typical small corpus; index appears automatically if corpus grows; always correct (brute-force fallback)
**Cons**: Threshold is a heuristic; no user visibility into whether ANN index is active

### Option B: Always create index

Create IVF-PQ index unconditionally on every table open/create.

**Pros**: Consistent behavior regardless of corpus size
**Cons**: IVF-PQ requires a minimum number of rows to train (LanceDB raises an error below ~256 rows depending on `num_partitions`); would require special-casing small corpora anyway

### Option C: Never create index

Always use brute-force search.

**Pros**: Simplest; no IVF-PQ API surface
**Cons**: Degrades linearly with corpus size; contradicts ADR-008's stated justification for choosing LanceDB (hybrid search / ANN capability)

## Rationale

The primary use case targets a small, slow-changing corpus of markdown decision records. For this range, brute-force search is not only correct but faster than ANN lookup. The 256-row threshold is the practical minimum for IVF-PQ with default parameters. Implementing a threshold-based approach delivers correct behavior at all corpus sizes without requiring manual intervention.

## Consequences

**Positive**: No IVF-PQ training errors on small corpora; index activates automatically as corpus grows; always correct
**Negative / Trade-offs**: Callers have no direct visibility into whether searches are ANN or brute-force; 256-row threshold is not configurable without a code change
**Risks**: If `create_index()` API changes across LanceDB versions, the call fails silently (caught by `except Exception: pass`); brute-force remains the fallback
**Follow-on decisions required**: None

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-08 | Initial record — decision detected in code during consistency audit | speckit.audit |
