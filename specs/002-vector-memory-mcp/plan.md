# Implementation Plan: Vector-Backed Semantic Memory

**Branch**: `002-vector-memory-mcp` | **Date**: 2026-04-06 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/002-vector-memory-mcp/spec.md`

## Summary

Build a local MCP server that exposes four stable tools (`memory_recall`, `memory_store`, `memory_sync`, `memory_delete`) backed by a LanceDB vector index. Markdown source files (ADRs, LOGs, specs, constitution) remain the git-tracked source of truth; the index is a volatile local cache gitignored from the repo. The server is implemented in Python with FastMCP, invoked via `uv run --directory memory-server speckit-memory` (monorepo local install — not published to PyPI). Embeddings use Ollama `nomic-embed-text` (768 dims, local, no cloud API account required — ADR-010). Speckit skills adopt a recall-before / store-after convention to surface prior decisions during planning and audit.

## Decision Records

| # | Type | File | Title | Status |
|---|---|---|---|---|
| ADR-008 | Decision | [ADR_008_lancedb-vector-backend.md](../../.specify/memory/ADR_008_lancedb-vector-backend.md) | LanceDB as vector index backend | Accepted |
| ADR-009 | Decision | [ADR_009_python-fastmcp-runtime.md](../../.specify/memory/ADR_009_python-fastmcp-runtime.md) | Python + FastMCP as MCP server runtime | Accepted |
| ADR-010 | Decision | [ADR_010_embedding-model-strategy.md](../../.specify/memory/ADR_010_embedding-model-strategy.md) | Ollama nomic-embed-text as the Embedding Model | Accepted |
| ADR-011 | Decision | [ADR_011_self-init-sync-trigger.md](../../.specify/memory/ADR_011_self-init-sync-trigger.md) | Self-initializing sync on first MCP tool call | Accepted |
| LOG-014 | Challenge | [LOG_014_filter-parameter-naming-drift.md](../../.specify/memory/LOG_014_filter-parameter-naming-drift.md) | `filter` vs `filters` parameter naming drift in `memory_recall` contract | Open |
| LOG-015 | Update | [LOG_015_unimplemented-error-codes.md](../../.specify/memory/LOG_015_unimplemented-error-codes.md) | Unimplemented error codes (`NO_EMBEDDER_CONFIGURED`, `INDEX_CORRUPT`) in MCP tool contract | Open |
| LOG-016 | Update | [LOG_016_claude-md-placeholder-text.md](../../.specify/memory/LOG_016_claude-md-placeholder-text.md) | CLAUDE.md template placeholders unfilled (raised during 002 audit) | Resolved |
| ADR-055 | Decision | [ADR_055_filter-predicate-shared-helper.md](../../.specify/memory/ADR_055_filter-predicate-shared-helper.md) | Metadata filter predicate — shared helper vs. accepted duplication (Rule of Three hit in `index.py`) | Proposed |
| ADR-056 | Decision | [ADR_056_direct-dependency-declaration-policy.md](../../.specify/memory/ADR_056_direct-dependency-declaration-policy.md) | Declare direct imports (`httpx`, `pyarrow`) in `pyproject.toml` | Accepted |
| LOG-058 | Challenge | [LOG_058_fastmcp-2x-3x-version-drift.md](../../.specify/memory/LOG_058_fastmcp-2x-3x-version-drift.md) | FastMCP 2.x → 3.x installed-version drift vs. declared range | Open |
| LOG-059 | Update | [LOG_059_mcp-tools-contract-superseded.md](../../.specify/memory/LOG_059_mcp-tools-contract-superseded.md) | 002 `mcp-tools.md` superseded by 003/006/007/008 deltas — banner added | Resolved |

## Technical Context

**Language/Version**: Python 3.10+
**Primary Dependencies**: FastMCP (MCP server framework), LanceDB (vector DB), ollama (embedding client — calls local Ollama HTTP API)
**Storage**: LanceDB embedded (`.specify/memory/.index/chunks.lance/`) + JSON manifest (`.specify/memory/.index/manifest.json`) — both gitignored
**Embedding model**: Ollama `nomic-embed-text` (768 dims, global system install, no cloud API account required — ADR-010)
**Testing**: pytest + pytest-asyncio; contract tests against the MCP tool interface; integration tests against a real LanceDB instance (no mocks)
**Target Platform**: macOS / Linux local dev machine (Ollama installed globally)
**Project Type**: Local MCP server (invoked via `uv run --directory memory-server speckit-memory` — monorepo local install, not published to PyPI)
**Performance Goals**: `memory_recall` < 3s for ≤100 indexed files; session-start sync < 500ms when no files changed
**Constraints**: No cloud API accounts; no committed artifacts from the index; index must be fully regeneratable from markdown source
**Scale/Scope**: Solo developer; ≤200 markdown files; no concurrent writers

## Constitution Check

- [x] **Pass 1 — Assumptions**: Key assumptions challenged: (1) solo dev has Python — required; uv handles the venv via `uv run`; (2) Ollama is installed globally — mitigated by one-time `brew install ollama` + model pull, documented in quickstart.md; (3) markdown files are the only knowledge source — scoped explicitly in spec Assumptions section; (4) index volatility is acceptable — confirmed by design (all data in git-tracked markdown)
- [x] **Pass 2 — Research**: All four technology choices researched and ADR'd (ADR-008 through ADR-011). LanceDB, FastMCP, Ollama nomic-embed-text embeddings, and self-init sync all verified against alternatives. Voyage AI and OpenAI both rejected — both require external API accounts outside the developer's existing Claude subscription (ADR-010).
- [x] **Pass 3 — Plan scrutiny**: Riskiest decision is ADR-010 (embedding model). Risk: developer switches models, old index becomes invalid. Validation: manifest records model name; server errors on mismatch with clear remediation (`memory_sync --full`).

- [x] Principle I: Spec written and checklist passed before this plan was written
- [x] Principle II: No speculative abstractions — four tools, one manifest file, one LanceDB table. No repository pattern, no plugin system, no abstraction layers.
- [x] Principle III: TDD — failing tests for each tool contract before implementation; integration tests against real LanceDB (not mocked)
- [x] Principle IV: P1 stories (recall + sync freshness) are independently deliverable; P2 stories (store convention, configurable embedding) depend only on P1 infrastructure
- [x] PR Policy: Four named PRs defined below — each ≤300 LOC

## Project Structure

### Documentation (this feature)

```text
specs/002-vector-memory-mcp/
├── plan.md              ← this file
├── research.md          ← Phase 0 output
├── data-model.md        ← Phase 1 output
├── quickstart.md        ← Phase 1 output
├── contracts/
│   └── mcp-tools.md    ← MCP tool interface contracts
└── tasks.md             ← Phase 2 output (/speckit.tasks)
```

### Source Code

```text
memory-server/
├── pyproject.toml              ← FastMCP + LanceDB + ollama deps
├── speckit_memory/
│   ├── __init__.py
│   ├── server.py               ← FastMCP tool definitions (4 tools)
│   ├── index.py                ← LanceDB read/write operations
│   └── sync.py                 ← Manifest diff + file crawl + embed (calls Ollama directly)
└── tests/
    ├── contract/
    │   └── test_tools.py       ← One test per tool contract (4 tests minimum)
    ├── integration/
    │   ├── test_sync.py        ← Sync with real LanceDB instance
    │   └── test_fault_scenarios.py  ← Fault injection: missing DB, API down, model mismatch
    └── unit/
        └── test_chunker.py     ← Chunking algorithm (heading-split, max size, no-headings)

.specify/memory/.index/         ← gitignored (LanceDB + manifest)
.mcp.json                       ← MCP server registration (repo root)
.claude/rules/memory-convention.md  ← recall-before/store-after convention
```

**Structure Decision**: Single Python package (`memory-server/`) separate from any future `src/` application code. MCP tools live in `server.py`; all LanceDB operations in `index.py`; sync logic isolated in `sync.py`. No `embedders/` directory — with a single Ollama backend there is no abstraction to justify (Principle II). Ollama HTTP calls live directly in `sync.py`.

### PR Split Plan

| PR | Files | Est. LOC | Dependency |
|---|---|---|---|
| PR-1: Core server | `pyproject.toml`, `speckit_memory/__init__.py`, `speckit_memory/server.py`, `speckit_memory/index.py`, `speckit_memory/sync.py`, `tests/contract/test_tools.py`, `tests/unit/test_chunker.py` | ~220 | None |
| PR-2: Integration + fault tests | `tests/integration/test_sync.py`, `tests/integration/test_fault_scenarios.py` | ~130 | PR-1 |
| PR-3: Skill integration | `.mcp.json`, `.claude/rules/memory-convention.md`, skill command updates, `quickstart.md` | ~80 | PR-2 |

All PRs are within the ≤300 LOC limit. Dropping the `embedders/` abstraction layer saves ~60 LOC and eliminates PR-1 from the old plan. If PR-1 grows beyond 270 LOC during implementation, extract `index.py` into its own PR between PR-1 and PR-2.

### Test Coverage Map

The following spec edge cases (spec.md lines 85-90) are explicitly assigned to test files:

| Edge Case | Test File | Test Name (tentative) |
|---|---|---|
| Deleted source file → chunks purged on next sync | `test_sync.py` | `test_deleted_file_purges_chunks` |
| Embedding API unavailable mid-session | `test_fault_scenarios.py` | `test_api_unavailable_returns_recoverable_error` |
| Manifest present but DB file missing → full re-index | `test_fault_scenarios.py` | `test_manifest_without_db_triggers_full_reindex` |
| File with no headings → single chunk | `test_sync.py` | `test_no_headings_produces_single_chunk` |
| `memory_store` with non-existent source → `synthetic: true` | `test_tools.py` | `test_store_nonexistent_source_sets_synthetic_flag` |
| Near-duplicate chunks from different files → both stored | `test_tools.py` | `test_near_duplicate_chunks_both_stored` |
| Score below `min_score` threshold → empty results (scenario 1.2) | `test_tools.py` | `test_recall_below_threshold_returns_empty` |
| Model mismatch detected → `MODEL_MISMATCH` error | `test_fault_scenarios.py` | `test_model_mismatch_errors_clearly` |

## Complexity Tracking

No constitution violations. All complexity is justified by the spec:
- Ollama as the single embedding backend: required by FR-010 and SC-004. No abstraction layer — single backend means direct calls in `sync.py` (Principle II).
- Chunking algorithm (heading-split + max token cap): required by retrieval quality — unspecified chunking produces unacceptable variance in recall results.
