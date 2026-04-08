# CLAUDE.md

This file is read automatically by Claude Code at the start of every session.
Keep it lean — detailed rules live in `.claude/rules/`.

## Project

**Name**: ClaudeTest
**Description**: [One sentence describing what this project does]
**Status**: [e.g., Active development / Maintenance / Prototype]

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
- 002-vector-memory-mcp: Added Python 3.10+ + FastMCP (MCP server framework), LanceDB (vector DB), ollama (embedding — global system install, no cloud API required)
- 2026-04-03: Added `/speckit.review-profile` command — runs adversarial review against benchmark fixture with Panel Efficiency Report; supports `--compare` mode for FULL/STANDARD/LIGHTWEIGHT comparison
- 2026-04-03: Added benchmark fixture at `specs/000-review-benchmark/fixture/` (spec.md, plan.md, tasks.md), scoring key at `specs/000-review-benchmark/benchmark-key.md`, and run reports at `specs/000-review-benchmark/runs/`

<!-- Update this as features are completed -->


## Active Technologies
- Python 3.10+ + FastMCP (MCP server framework), LanceDB (vector DB), openai (embedding API), ollama (local embedding fallback) (002-vector-memory-mcp)
- LanceDB embedded (`.specify/memory/.index/chunks.lance/`) + JSON manifest (`.specify/memory/.index/manifest.json`) — both gitignored (002-vector-memory-mcp); embeddings via Ollama nomic-embed-text (768 dims, local, no API key)
