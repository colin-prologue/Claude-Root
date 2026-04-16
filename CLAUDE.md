# CLAUDE.md

This file is read automatically by Claude Code at the start of every session.
Keep it lean — detailed rules live in `.claude/rules/`.

## Project

**Name**: ClaudeTest
**Description**: A spec-driven development template with multi-agent adversarial review, a local vector memory server for semantic search over ADRs and specs, and bidirectional consistency auditing.
**Status**: Active development

## Stack

| Layer | Technology | Version |
|---|---|---|
| Language | Python | 3.10+ |
| Framework | FastMCP (MCP server) | 2.0+ |
| Database | LanceDB (embedded vector DB) | 0.13+ |
| Embedding | Ollama nomic-embed-text | 768 dims |
| Testing | pytest + pytest-asyncio | 8.0+ |
| Package manager | uv | latest |

## Commands

```bash
# Install dependencies (memory-server)
uv sync --directory memory-server

# Run tests (no Ollama required)
uv run --directory memory-server pytest -m "not integration"

# Run all tests including integration (requires Ollama running)
uv run --directory memory-server pytest

# Start MCP server locally
uv run --directory memory-server speckit-memory

# Environment variables
# OLLAMA_BASE_URL (default: http://localhost:11434)
# OLLAMA_MODEL (default: nomic-embed-text)
# OLLAMA_TIMEOUT (default: 10) — seconds before Ollama calls fail (006-ollama-fallback)
# MEMORY_INDEX_PATH (default: .specify/memory/ADR_*.md,LOG_*.md,constitution.md + specs/*/spec.md,plan.md)
```

## Directory Structure

```
.claude/
  commands/             # Spec-Kit slash commands
  agents/               # Agent personas for /speckit.review and /speckit.audit
  rules/                # Modular instruction files (loaded automatically)
    memory-convention.md  # recall-before / store-after convention for skills
  settings.local.json   # Local settings
.mcp.json               # MCP server registration (memory server)
.specify/
  memory/
    constitution.md     # Project principles + context
    .index/             # GITIGNORED — LanceDB + manifest (volatile cache)
  templates/            # Document templates
  scripts/              # Helper scripts
memory-server/
  pyproject.toml        # speckit-memory package
  speckit_memory/
    server.py           # FastMCP tool definitions (4 tools)
    index.py            # LanceDB read/write operations
    sync.py             # Chunker + manifest diff + embed
  tests/
    contract/           # Tool interface contracts (no Ollama)
    integration/        # Real LanceDB + Ollama tests
    unit/               # Chunker and index unit tests
specs/                  # Feature specifications (one folder per feature)
docs/                   # Long-form documentation
```

## Key Conventions

- Branch naming: `###-feature-name` (e.g., `001-user-auth`)
- Commit format: conventional commits (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`)
- Commit after each completed task
- No credentials or secrets in source — use environment variables
- See `.specify/memory/constitution.md` for full governing principles

## Recent Changes
- 006-ollama-fallback: Ollama resilience — ToolError raises, configurable timeout (`OLLAMA_TIMEOUT`), summary_only bypass via table scan, `_ensure_init` retry fix
- 005-sync-stale-cleanup: Fixed scoped-sync mass-deletion bug (FR-001a), chunk-count bug in `deleted` stat (FR-008), hardened `find_deleted` against malformed/synthetic manifest keys (FR-007), added direct-exists safety check (ADR-030)
- 003-memory-server-hardening: Added mutation protection (write/delete guard), caller-controlled token budget (max_chars), summary-only recall mode, and source filter to memory_recall
- 002-vector-memory-mcp: Added Python 3.10+ + FastMCP (MCP server framework), LanceDB (vector DB), ollama (embedding — global system install, no cloud API required)

<!-- Update this as features are completed -->


## Active Technologies
- LanceDB embedded (`.specify/memory/.index/chunks.lance/`) + `manifest.json` (005-sync-stale-cleanup)
