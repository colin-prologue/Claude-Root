# Research: Vector-Backed Semantic Memory MCP

**Feature**: 002-vector-memory-mcp
**Date**: 2026-04-06
**Phase**: 0 — Pre-design research

## Decision 1: Vector DB Backend

**Decision**: LanceDB (embedded)
**Rationale**: Daemonless, single-directory storage, mature Python SDK, hybrid search available. ChromaDB eliminated (requires daemon for persistence). SQLite-vec eliminated (weaker Python SDK, no hybrid search).
**Alternatives considered**: SQLite-vec (5MB footprint, simpler, weaker SDK), ChromaDB (daemon required)
**Key risk**: Lance format is younger than SQLite; mitigated by volatile-by-design architecture (re-index from markdown source is always an option)
**ADR**: ADR-008

## Decision 2: MCP Server Runtime

**Decision**: Python + FastMCP
**Rationale**: Embedding model and vector DB ecosystems are Python-first. FastMCP's decorator-based API keeps the server small. Invoked via `uv run --directory memory-server speckit-memory` for monorepo local development (not published to PyPI). TypeScript has more MCP examples but weaker embedding/vector DB library coverage.
**Alternatives considered**: TypeScript + MCP SDK (more examples, weaker vector ecosystem)
**Key risk**: Requires Python 3.10+ on developer machine; uv manages the venv automatically via `uv run`
**ADR**: ADR-009

## Decision 3: Embedding Model

**Decision**: Ollama `nomic-embed-text` as the sole embedding backend. No cloud API. *(Amended post-review: Voyage AI was the original default but was dropped — it requires a separate external account outside the developer's existing Claude subscription. See ADR-010 amendment history.)*
**Rationale**: A solo developer with a Claude subscription should not need additional accounts. Ollama is a global machine-level install (one-time `brew install ollama` + model pull). nomic-embed-text produces 768-dim vectors well-suited for retrieval over technical markdown.
**Alternatives considered**: OpenAI (rejected — wrong vendor for Claude stack), Voyage AI (rejected — separate external account required), Anthropic (no public embedding model), sentence-transformers (rejected — ~1GB Python dependency footprint)
**Key risk**: Cross-model index contamination if developer switches models without full re-index. Mitigated by storing model name in manifest and erroring on mismatch.
**ADR**: ADR-010

## Decision 4: Session-Start Sync Trigger

**Decision**: Self-initialize on first MCP tool call (manifest diff, re-embed stale files only)
**Rationale**: Claude Code has no session-start hook — only tool-centric hooks (`PreToolUse`, `PostToolUse`). MCP servers are spawned lazily on first tool reference. Running sync before the first result returns satisfies FR-011 and SC-002 (<500ms when clean) without any external configuration.
**Alternatives considered**: Claude Code settings.json hook (no session-start hook exists), git post-commit hook (adds commit latency, not auto-installed on clone)
**Key risk**: Manifest diff bug → every session pays full re-index cost. Mitigated by simple, well-tested manifest logic.
**ADR**: ADR-011

## Decision 5: Competitive Landscape — Build vs. Adopt

**Decision**: Build a custom LanceDB + FastMCP server rather than adopting an existing MCP memory server.
**Date**: 2026-04-06 (added post-review, pre-tasks)

### Alternatives evaluated

**`modelcontextprotocol/server-memory`** (official Anthropic, TypeScript, ~44k weekly downloads)
- Storage: knowledge graph (entities + relations), local JSONL file. `search_nodes` is keyword/substring only — no vector similarity.
- **Blocker**: Write-only-from-Claude. No file corpus ingestion, no mtime-diff sync. All existing ADRs/LOGs/specs would require manual extraction and population. Designed for Claude to accumulate knowledge mid-session, not to index a pre-existing file corpus.
- **Verdict**: Wrong storage model. Solves a different problem.

**`memory-graph/memory-graph`** (203 stars, SQLite/Neo4j, local-first)
- Graph-based, push-only (explicit `store_memory` calls). Fuzzy/keyword recall. No auto-ingestion of existing files.
- **Verdict**: Same blocker as server-memory. No auto-sync.

**`memorygraph.dev`** (cloud-hosted, paid)
- Cloud product. Not local-first.
- **Verdict**: Out of scope for a local developer tool.

**`tirth8205/code-review-graph`** (5.9k stars, Tree-sitter-based)
- Parses source code for dependency blast-radius mapping. Not relevant to markdown decision-record recall.
- **Verdict**: Wrong problem domain.

**Qdrant RAG MCP** (`ancoleman/qdrant-rag-mcp`, TypeScript, most mature alternative)
- Smart incremental reindexing, markdown support, content-type-specific embeddings. Closest functional match.
- **Gaps**: Requires Qdrant as an external process (not embedded/daemonless), TypeScript (weaker embedding ecosystem), no Ollama-backed local embedding.
- **Verdict**: Viable alternative but requires an external Qdrant daemon, losing the daemonless requirement from ADR-008.

**Fremem** (`iamjpsharma/fremem`, LanceDB + local embeddings + 6 MCP tools)
- Closest architecture to this spec. LanceDB, multi-project isolation, MCP-native.
- **Gaps**: Uses Sentence Transformers (not Ollama nomic-embed-text), no mtime-diff manifest (manual `ingest.sh` only), no ADR/spec taxonomy.
- **Verdict**: Best reference implementation. Use as architecture reference for the LanceDB tool surface and multi-project isolation pattern.

### The graph vs. vector tradeoff

Graph approaches (server-memory, memory-graph) enable richer structured queries ("what decisions are BLOCKED BY the embedding model choice?") but require defining entity types and extracting relations from markdown — significant extra work. Vector search avoids the extraction step and handles fuzzy/cross-vocabulary queries ("what have we decided about error handling?") without manual tagging.

For a corpus of structured-but-untagged markdown files (ADRs, LOGs, specs), vector search is the right fit. Graph approaches would require a preprocessing step that erases the "no manual effort" requirement from User Story 2.

### Core differentiator for building custom

No existing MCP server combines: (1) automatic mtime-diff sync over a pre-existing local markdown corpus, (2) Ollama local embedding with no cloud API dependency, (3) ADR/spec/decision-record taxonomy in chunk metadata, (4) FastMCP + Python (vs. TypeScript dominance in the space). The fundamentals (LanceDB, mtime manifest pattern) are proven — the combination is novel.

**Reference**: Fremem's source code should be reviewed before finalizing tasks.md to identify implementation lessons.

## Decision 6: Post-Implementation Competitive Analysis — Serena

**Decision**: No architecture change; maintain custom LanceDB + FastMCP implementation.
**Date**: 2026-04-09 (added post-002 implementation)

After completing 002, we evaluated [Serena](https://github.com/oraios/serena) (~22k stars), an MCP-based coding agent with a file-based memory system. Serena's memory stores named Markdown files; recall is LLM-routed via filename list in the system prompt — no embeddings, no vector DB, no chunking.

**Why Serena's memory is not a replacement**: The speckit recall pattern (`memory_recall("technology choices architecture decisions")`) is a semantic query where the caller doesn't know the filename. Serena has no answer for this. Its approach degrades past ~50–100 docs as the filename list grows in the system prompt. Our embedding approach is the right architecture for the recall-before convention.

**Serena's core value (not competing)**: LSP-backed symbol retrieval (`find_symbol`, `rename_symbol`, `findReferences`) — fundamentally better than RAG for code editing tasks. This is a different domain.

**Gaps and learnings captured**: LOG-017 (`LOG_017_memory-server-roadmap-serena-learnings.md`) tracks 3 known implementation gaps and 5 Serena-inspired roadmap items for future features (003+).

---

## Resolved Clarifications

All NEEDS CLARIFICATION items from Technical Context are resolved. No open questions remain before Phase 1.
