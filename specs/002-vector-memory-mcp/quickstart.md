# Quickstart: Vector-Backed Semantic Memory

**Feature**: 002-vector-memory-mcp
**Time to working**: ~10 minutes (one-time Ollama setup)

## Prerequisites

- Python 3.10+ (`python3 --version`)
- `uv` package manager (`curl -LsSf https://astral.sh/uv/install.sh | sh`)
- Ollama installed globally (`brew install ollama` on macOS) — one-time per machine, not per-repo

## Local development (pre-PyPI)

During development, before the package is published to PyPI, start the server with:

```bash
# From repo root
uv run --directory memory-server python -m speckit_memory.server
```

Or install in editable mode for faster iteration:

```bash
cd memory-server && uv pip install -e . && speckit-memory
```

The package is not published to PyPI. The standard invocation for this monorepo is `uv run --directory memory-server speckit-memory`, as configured in `.mcp.json`.

## Step 1: Configure the MCP server

Add `.mcp.json` to the repo root (already templated):

```json
{
  "mcpServers": {
    "memory": {
      "command": "uv",
      "args": ["run", "--directory", "memory-server", "speckit-memory"],
      "env": {
        "MEMORY_INDEX_PATH": "",
        "OLLAMA_BASE_URL": "http://localhost:11434",
        "OLLAMA_MODEL": "nomic-embed-text"
      }
    }
  }
}
```

This is the pre-PyPI local development configuration (already in `.mcp.json`). `MEMORY_INDEX_PATH` left empty uses the default glob patterns. `OLLAMA_BASE_URL` and `OLLAMA_MODEL` can be omitted to use the defaults.

## Step 2: Install Ollama and pull the embedding model

```bash
brew install ollama                        # macOS; see ollama.ai for Linux
brew services start ollama                 # start as persistent background service (survives reboots)
ollama pull nomic-embed-text              # ~300MB, one-time download per machine
```

Ollama is a global machine install — you only do this once regardless of how many repos use it.

> **Session-only alternative**: `ollama serve` runs Ollama in the foreground for the current terminal session only. Use this if you prefer not to run it as a background service, but you'll need to restart it each session. The `API_UNAVAILABLE` error in the troubleshooting table below means Ollama isn't running.

## Step 3: Verify

Open a Claude Code session. The memory server starts automatically on first use. Test it:

> "Call memory_sync and tell me how many files were indexed."

Expected output: `indexed: N, skipped: 0, deleted: 0` where N = number of `.md` files in `.specify/memory/` and `specs/`.

## Step 4: Add to `.gitignore`

```
.specify/memory/.index/
```

This directory is volatile — never commit it.

## Switching Ollama models

If you switch to a different Ollama embedding model (e.g., `mxbai-embed-large`), you must rebuild the index:

> "Call memory_sync with full: true"

This discards old embeddings (incompatible dimensions) and re-indexes from scratch.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `MODEL_MISMATCH` error | Index built with a different model | Run `memory_sync` with `full: true` |
| `API_UNAVAILABLE` error | Ollama not running | Run `ollama serve` in a terminal, then retry |
| `memory_recall` returns empty | No files indexed yet | Run `memory_sync` first |
| Slow first call per session | First-call sync running | Normal; subsequent calls are fast |

## Falsification criteria

The setup is working correctly when:
1. `memory_sync` returns `indexed > 0` on a fresh repo with ADRs present
2. `memory_recall("panel composition")` returns ADR-007 content without the caller reading the file
3. Deleting `.specify/memory/.index/` and re-running `memory_sync` restores identical results
4. Switching `OLLAMA_MODEL` to a different model and running `memory_sync --full` succeeds without error
