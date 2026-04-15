# Tool Error Contract Delta — Feature 006

**Branch**: `006-ollama-fallback`
**Date**: 2026-04-14

## Overview

Feature 006 changes how Ollama-unavailability errors are surfaced to MCP clients. This is a **breaking change** in the error channel, not in the tool signature.

**Before (current)**: Some Ollama errors return a success response with an error-shaped dict:
```json
{ "isError": false, "result": { "error": { "code": "API_UNAVAILABLE", "message": "...", "recoverable": true } } }
```

**After (006)**: All Ollama errors raise `ToolError`, producing an MCP error response:
```json
{ "isError": true, "content": [{ "type": "text", "text": "EMBEDDING_UNAVAILABLE: ..." }] }
```

See ADR-033 for rationale.

---

## Tool Signatures (unchanged)

All four tool signatures remain the same. Only error behavior changes.

### memory_recall

```python
def memory_recall(
    query: str,
    top_k: int = 5,
    min_score: float = 0.5,
    filters: dict | None = None,
    max_chars: int | None = None,
    filter_source_file: str | None = None,
    summary_only: bool = False,
) -> dict
```

**Behavior change**:
- `summary_only=True`: now succeeds without Ollama (table scan, no embedding). See ADR-037.
- `summary_only=False` + Ollama down: raises `ToolError("EMBEDDING_UNAVAILABLE: ...")` instead of returning error dict.
- `summary_only=True` result shape: `{source_file, section}` — **no score field** when Ollama is bypassed.

### memory_store

```python
def memory_store(content: str, metadata: dict) -> dict
```

**Behavior change**: Ollama unavailability raises `ToolError` instead of returning error dict.

### memory_sync

```python
def memory_sync(full: bool = False, paths: list[str] | None = None) -> dict
```

**Behavior change**: Ollama unavailability raises `ToolError` instead of returning error dict.

### memory_delete

```python
def memory_delete(source_file: str | None = None, id: str | None = None) -> dict
```

**No change**: Delete does not require Ollama. Succeeds regardless of Ollama availability (FR-008).

---

## Error Format (post-006)

All Ollama errors are `ToolError` raises with a formatted string message. No structured dict.

Format: `"<CATEGORY>: <plain-language description>. Hint: <corrective action>."`

### Categories

| Category | Condition | Example Message |
|---|---|---|
| `EMBEDDING_UNAVAILABLE` | Ollama not running | `EMBEDDING_UNAVAILABLE: Ollama is not running at http://localhost:11434. Hint: run \`ollama serve\` to start the embedding service.` |
| `EMBEDDING_UNAVAILABLE` | Timeout | `EMBEDDING_UNAVAILABLE: Ollama did not respond within 10s. Hint: check that Ollama is running and accessible at http://localhost:11434.` |
| `EMBEDDING_MODEL_ERROR` | Model not pulled | `EMBEDDING_MODEL_ERROR: model 'nomic-embed-text' is not available. Hint: run \`ollama pull nomic-embed-text\` to download the model.` |
| `EMBEDDING_CONFIG_ERROR` | Invalid URL | `EMBEDDING_CONFIG_ERROR: OLLAMA_BASE_URL is invalid. Hint: check the value of the OLLAMA_BASE_URL environment variable.` |

---

## Unchanged Error Formats (return-value dicts retained)

The following errors are NOT Ollama-related and remain as return-value dicts (no change):

| Tool | Code | Condition |
|---|---|---|
| `memory_recall` | `INVALID_INPUT` | `max_chars <= 0` |
| `memory_store` | `INVALID_SOURCE_FILE` | `source_file != "synthetic"` |
| `memory_sync` | `MODEL_MISMATCH` | Index built with different model |
| `memory_delete` | `INVALID_INPUT` | Both or neither of source_file/id provided |
| `memory_delete` | `PROTECTED_SOURCE_FILE` | File still exists on disk |
| `memory_delete` | `INVALID_INPUT` | Malformed UUID |
