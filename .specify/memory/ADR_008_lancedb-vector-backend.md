# ADR-008: LanceDB as the Vector Index Backend

**Date**: 2026-04-06
**Status**: Accepted
**Decision Made In**: specs/002-vector-memory-mcp/plan.md § Phase 0 Research
**Related Logs**: None

---

## Context

The vector memory MCP server needs a local embedded vector database — one that runs without a server daemon, stores data in a portable directory, and can be installed without complex setup. Three candidates were evaluated: SQLite-vec, LanceDB, and ChromaDB.

## Decision

We will use LanceDB (embedded mode) as the vector index backend because it is daemonless, stores all data in a single directory, and ships with mature Python and JavaScript SDKs.

## Alternatives Considered

### Option A: LanceDB *(chosen)*

Embedded vector database backed by Apache Arrow/Lance format. Single-directory storage. No daemon process. Supports vector, full-text, and SQL queries in one library.

**Pros**: Zero daemon, single `lancedb.connect(path)` call, hybrid search capability, mature Python SDK, ~3.5s faster than SQLite-vec at scale
**Cons**: ~50MB install footprint (vs ~5MB SQLite-vec), less battle-tested than SQLite for edge cases

### Option B: SQLite-vec

Vector search as a SQLite extension. Minimal footprint, single `.db` file.

**Pros**: Extremely lightweight, familiar SQL interface, single-file storage
**Cons**: Node.js embedding integration requires manual plumbing; Python SDK less complete; no hybrid search

### Option C: ChromaDB

Popular vector DB with Python-first SDK.

**Pros**: Rich query API, large community
**Cons**: Requires a daemon process for persistence (in-memory mode loses data on restart); violates zero-server requirement

## Rationale

ChromaDB was eliminated immediately — persistent storage requires a running server process. Between SQLite-vec and LanceDB, LanceDB wins on SDK maturity and future extensibility (hybrid search is available without extra libraries), at a footprint cost that is negligible for a local dev tool.

## Consequences

**Positive**: Zero-daemon setup; single-directory gitignore; hybrid search available if needed later
**Negative / Trade-offs**: 50MB install footprint; Lance format is less familiar than SQLite
**Risks**: LanceDB is younger than SQLite; schema migration may be needed if Lance format evolves. Mitigated by volatile-by-design architecture — re-index rebuilds from markdown source.
**Follow-on decisions required**: ADR-009 (MCP server runtime, which determines which LanceDB SDK to use)

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-06 | Initial record | speckit.plan |
