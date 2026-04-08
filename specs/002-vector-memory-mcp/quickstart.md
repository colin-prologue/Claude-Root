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

Once published to PyPI, `uvx speckit-memory` is the standard invocation (used in `.mcp.json`).

## Step 1: Configure the MCP server

Add `.mcp.json` to the repo root (already templated):

```json
{
  "mcpServers": {
    "memory": {
      "command": "uvx",
      "args": ["speckit-memory"],
      "env": {
        "MEMORY_INDEX_PATH": ".specify/memory/.index",
        "OLLAMA_BASE_URL": "http://localhost:11434"
      }
    }
  }
}
```

`OLLAMA_BASE_URL` defaults to `http://localhost:11434` — only set it explicitly if you run Ollama on a non-standard port.

## Step 2: Install Ollama and pull the embedding model

```bash
brew install ollama                        # macOS; see ollama.ai for Linux
ollama pull nomic-embed-text              # ~300MB, one-time download per machine
ollama serve                              # start the Ollama server (runs in background)
```

Ollama is a global machine install — you only do this once regardless of how many repos use it.

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
