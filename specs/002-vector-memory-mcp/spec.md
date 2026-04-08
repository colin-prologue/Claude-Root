# Feature Specification: Vector-Backed Semantic Memory

**Feature Branch**: `002-vector-memory-mcp`
**Created**: 2026-04-06
**Status**: Draft
**Input**: User description: "Vector-backed semantic memory system for the Spec-Kit template."

## Decision Records

| # | Type | File | Title | Status |
|---|---|---|---|---|
| ADR-008 | Decision | [ADR_008_lancedb-vector-backend.md](../../.specify/memory/ADR_008_lancedb-vector-backend.md) | LanceDB as vector index backend | Accepted |
| ADR-009 | Decision | [ADR_009_python-fastmcp-runtime.md](../../.specify/memory/ADR_009_python-fastmcp-runtime.md) | Python + FastMCP as MCP server runtime | Accepted |
| ADR-010 | Decision | [ADR_010_embedding-model-strategy.md](../../.specify/memory/ADR_010_embedding-model-strategy.md) | Ollama nomic-embed-text as the Embedding Model | Accepted |
| ADR-011 | Decision | [ADR_011_self-init-sync-trigger.md](../../.specify/memory/ADR_011_self-init-sync-trigger.md) | Self-initializing sync on first MCP tool call | Accepted |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Semantic Recall Before Planned Work (Priority: P1)

A developer starts a new session and asks a speckit command (e.g., `/speckit.plan`) to generate a plan for a feature. Before generating output, the command recalls semantically relevant prior decisions — ADRs, LOGs, constitution principles — and incorporates them into its reasoning without the developer manually locating and reading those files.

**Why this priority**: This is the core value proposition. Without recall, the memory system has no effect on outcomes. Every other story depends on this working first.

**Independent Test**: Given a project with at least three ADRs in `.specify/memory/`, when `/speckit.plan` is invoked for a new feature that touches a previously-decided concern (e.g., panel composition), then the generated plan references the relevant ADR by number and does not contradict its decision — without the user providing any manual context.

**Acceptance Scenarios**:

1. **Given** a project with indexed ADRs, **When** a speckit command invokes `memory_recall("panel composition")`, **Then** the relevant ADR chunks are returned ranked by semantic similarity within 3 seconds
2. **Given** a query with no close match, **When** `memory_recall` is called, **Then** it returns an empty result set rather than unrelated chunks
3. **Given** metadata filters applied (e.g., `type: "adr"`), **When** `memory_recall` is called, **Then** only chunks matching that type are returned regardless of similarity score

---

### User Story 2 - Index Stays Current Without Manual Effort (Priority: P1)

A developer writes a new ADR, commits it, and starts a new session. The memory index already reflects the new ADR — no manual sync step required. Mid-session, if a file changes before commit, the developer can trigger an explicit sync and immediately query the updated content.

**Why this priority**: A stale index silently degrades quality. If recall returns outdated information, the feature causes harm rather than help. This must work reliably to make story 1 trustworthy.

**Independent Test**: Given a project with an existing index, when a new ADR is written and committed, then a new session's first `memory_recall` query returns content from that ADR without any manual sync step from the developer.

**Acceptance Scenarios**:

1. **Given** a committed markdown file not yet in the index, **When** a new session starts, **Then** the file is detected by mtime diff, embedded, and queryable before any command runs
2. **Given** a file edited mid-session but not yet committed, **When** `memory_sync` is called explicitly, **Then** the updated content is indexed and immediately queryable
3. **Given** the index is deleted entirely, **When** a new session starts or `memory_sync` is called, **Then** the full index is rebuilt from all markdown files without data loss

---

### User Story 3 - Skills Store Work Summaries for Future Recall (Priority: P2)

After `/speckit.specify` or `/speckit.plan` completes, a summary of the output — key decisions made, constraints identified, entities defined — is stored in the memory index. A future session can recall this context without re-reading the full spec or plan artifact.

**Why this priority**: Recall without store means the index only reflects source files, not the reasoning produced by commands. Store closes the feedback loop and makes the index richer over time.

**Independent Test**: Given a completed spec for feature 002, when `memory_recall("vector memory embedding model")` is called in a separate session, then the stored spec summary surfaces the embedding model decision without the caller reading `specs/002-vector-memory-mcp/spec.md`.

**Acceptance Scenarios**:

1. **Given** a speckit command completes successfully, **When** it calls `memory_store` with a summary chunk, **Then** the chunk is embedded and retrievable by semantic query within the same session
2. **Given** a stored chunk with metadata `{type: "spec", feature: "002-vector-memory-mcp"}`, **When** `memory_recall` is called with a filter `{feature: "002-vector-memory-mcp"}`, **Then** only chunks for that feature are returned
3. **Given** a source markdown file is updated and re-indexed, **When** old chunks from a prior embedding of that file exist, **Then** the old chunks are replaced, not duplicated

---

### User Story 4 - Embedding Model Is Configurable (Priority: P2)

A developer can configure which Ollama model is used for embeddings via `OLLAMA_MODEL` env var. Switching models triggers a full re-index (`memory_sync --full`). The configuration does not affect the `memory_recall` / `memory_store` interface seen by skills.

**Why this priority**: Solo developers vary on cost tolerance and offline requirements. Locking to a single provider blocks adoption. However this is P2 because the system can ship with one working default first.

**Independent Test**: Given a project with `OLLAMA_MODEL=nomic-embed-text` and Ollama running locally, when `memory_recall("ADR panel composition")` is called, then relevant chunks are returned correctly without any cloud API call.

**Acceptance Scenarios**:

1. **Given** `OLLAMA_MODEL` is set to a valid model name, **When** any memory operation runs, **Then** embeddings are generated using that model via Ollama HTTP API
2. **Given** `OLLAMA_MODEL` is changed to a different model, **When** `memory_sync --full` is called, **Then** all existing chunks are re-embedded with the new model and old embeddings are discarded
3. **Given** the manifest records a different model than the current config, **When** any tool call triggers sync, **Then** a `MODEL_MISMATCH` error is returned with advice to run `memory_sync --full`

---

### Edge Cases

- What happens when a markdown file is deleted from the repo? Its chunks must be purged from the index on next sync.
- What happens when the embedding model API is unavailable mid-session? The operation fails with a clear error; the existing index remains intact and prior recall still works.
- What happens when two chunks from different files are nearly identical? Both are stored — deduplication is not performed; source file is the unit of identity.
- What happens when the index manifest is present but the DB file is missing? Full re-index is triggered automatically.
- What happens when a markdown file has no headings? It is indexed as a single chunk with section set to the filename.
- What happens when `memory_store` is called with a chunk whose source file does not exist on disk? The chunk is stored with a `synthetic: true` flag in metadata, indicating it was produced by a command rather than sourced from a file.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST expose four MCP tools accessible to any skill or command: `memory_store`, `memory_recall`, `memory_sync`, and `memory_delete`
- **FR-002**: `memory_recall` MUST accept a natural language query and return semantically ranked chunks, each with source metadata (file, section, type, feature, date, tags)
- **FR-003**: `memory_recall` MUST support optional metadata filters (type, feature, tags) that narrow the candidate set before semantic ranking
- **FR-004**: `memory_store` MUST accept content and a metadata object, embed the content, and persist the chunk to the local index
- **FR-005**: `memory_sync` MUST compare file modification times against a manifest, re-embed only changed or new files, and update the manifest
- **FR-006**: `memory_sync` MUST support a full re-index mode that discards all chunks and rebuilds from source markdown files
- **FR-007**: `memory_delete` MUST remove all chunks associated with a given source file path
- **FR-008**: The local index and manifest MUST be gitignored and never appear in commits
- **FR-009**: Deleting the entire index MUST be a safe, recoverable operation — a subsequent sync restores full capability from markdown source files
- **FR-010**: The Ollama embedding model MUST be configurable via environment variable (`OLLAMA_MODEL`) without changing the MCP tool interface; switching models requires a full re-index (`memory_sync --full`)
- **FR-011**: Session-start sync MUST complete before any skill invokes `memory_recall`, and MUST add no perceptible delay when no files have changed
- **FR-012**: Speckit skills (at minimum: specify, plan, audit) MUST follow a recall-before / store-after convention; this convention MUST be documented in `.claude/rules/`
- **FR-013**: Each indexed chunk MUST carry metadata: `source_file`, `type` (adr/log/spec/constitution/synthetic), `section`, `feature`, `date`, `tags`

### Key Entities

- **Chunk**: A discrete piece of indexed content — one section of a markdown file, or a summary stored by a command. Carries an embedding vector and metadata. The unit of recall.
- **Manifest**: A local file mapping `{source_file → last_indexed_mtime}`. Used by sync to detect stale or missing chunks without scanning the full DB.
- **Memory Index**: The local vector database (volatile, gitignored). Contains all chunks and their embeddings. Always regeneratable from source.
- **Embedding Model**: The function that converts text to a numeric vector. Configured per project; swapping the model requires a full re-index.
- **MCP Memory Server**: The local process that owns the index and exposes the four MCP tools to Claude Code and skills.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A skill invoking `memory_recall` receives relevant results in under 3 seconds for a project with up to 100 indexed markdown files
- **SC-002**: Session-start sync adds no perceptible delay (under 500ms) when no markdown files have changed since the last session
- **SC-003**: After deleting the index, a developer can restore full recall capability with a single command, with no information loss — all content remains in git-tracked markdown
- **SC-004**: A developer can switch the Ollama embedding model by changing only the `OLLAMA_MODEL` environment variable — no skill or command modification required
- **SC-005**: Speckit commands that invoke recall demonstrably reference prior decisions in their output, evidenced by ADR/LOG cross-references appearing in generated artifacts
- **SC-006**: Zero chunks from deleted source files remain in the index after a sync cycle completes

## Assumptions

- The project is used by a solo developer or small team; concurrent write access to the index by multiple processes is not in scope
- Markdown files are the only source type indexed; code files, binaries, and non-markdown docs are excluded
- The MCP server runs as a local process on the developer's machine; a remote or cloud-hosted index is out of scope for this version
- `speckit.codereview` and `speckit.brainstorm` are lower priority for memory-awareness and may be addressed in a follow-on feature
- The embedding model produces stable output for identical inputs within a version — embeddings are not expected to change unless the model is explicitly switched
