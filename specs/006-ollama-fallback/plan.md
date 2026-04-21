# Implementation Plan: Ollama Fallback

**Branch**: `006-ollama-fallback` | **Date**: 2026-04-14 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/006-ollama-fallback/spec.md`

## Summary

Harden the memory server against Ollama unavailability by: (1) raising `ToolError` instead of returning error dicts or crashing, (2) adding a configurable timeout to the Ollama client, (3) restructuring `memory_recall` so `summary_only=True` bypasses embedding entirely via a new table scan path, and (4) fixing `_ensure_init` flag ordering so the server retries init if Ollama was down on first call. No new tools, no new schema changes — purely a resilience improvement on the existing four tools.

## Decision Records

| # | Type | File | Title | Status |
|---|---|---|---|---|
| 032 | ADR | ADR_032_006-scope-errors-vs-bm25.md | Ollama-down scope: structured errors (006) vs. BM25 fallback (007) | Accepted |
| 033 | ADR | ADR_033_mcp-error-channel-strategy.md | MCP error channel strategy: raise ToolError, not return-value dicts | Accepted |
| 034 | LOG | LOG_034_summary-only-ollama-dependency.md | `summary_only` mode does not currently bypass Ollama | Resolved → plan.md |
| 035 | LOG | LOG_035_first-call-done-before-init-success.md | `_ensure_init` sets flag before init succeeds — blocks retry-on-recovery | Resolved → plan.md |
| 036 | LOG | LOG_036_httpx-timeout-exception-catch-gap.md | `httpx.TimeoutException` escapes current catch clauses — FR-004 blocker | Resolved → plan.md |
| 037 | ADR | ADR_037_summary-only-scan-strategy.md | summary_only bypass: table scan without vector | Accepted |
| 038 | LOG | LOG_038_ensure-init-retry-non-embed-tools.md | `_ensure_init` retry-on-every-call adds ~10s latency to `summary_only`/delete after T007 | Open |
| 057 | LOG | LOG_057_memory-repo-root-undocumented.md | `MEMORY_REPO_ROOT` env var introduced here is undocumented in CLAUDE.md | Resolved |

## Technical Context

**Language/Version**: Python 3.10+
**Primary Dependencies**: FastMCP 2.0+, LanceDB 0.13+, `ollama` Python SDK, `httpx` (transitive dependency of ollama SDK)
**Storage**: LanceDB embedded (`.specify/memory/.index/chunks.lance/`) + `manifest.json`
**Testing**: pytest + pytest-asyncio 8.0+
**Target Platform**: Local MCP server (single process, invoked by Claude Code via `.mcp.json`)
**Project Type**: Library (MCP server)
**Performance Goals**: All Ollama calls complete or raise within `OLLAMA_TIMEOUT` seconds (default 10)
**Constraints**: No hangs; no unhandled exceptions when Ollama is unreachable; manifest on disk unchanged if sync fails mid-run
**Scale/Scope**: Solo dev tool; small corpus (~50–200 chunks)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Before agreeing on this approach, confirm all three passes have been completed:
- [x] **Pass 1 — Assumptions**: Every assumption challenged:
  - "httpx.ConnectError is caught by `except ConnectionError`" → **technically false** (not a subclass) but ollama SDK re-raises as Python built-in `ConnectionError` → effectively caught. Verified in SDK source.
  - "summary_only bypasses Ollama today" → **false** (LOG-034). Fixing it requires a new code path.
  - "manifest is atomic on failure" → **true** (`save_manifest` only called at loop end).
  - "ollama.Client accepts timeout=" → **true** (verified in SDK `BaseClient.__init__` signature).
  - "`httpx.TimeoutException` is caught" → **false** (LOG-036). Not in SDK's catch list, not in ours.
- [x] **Pass 2 — Research**: Exception hierarchy verified against live SDK source. Timeout parameter confirmed. `scan_chunks` implementation validated against LanceDB API. research.md records all findings.
- [x] **Pass 3 — Plan scrutiny**: Riskiest decision is the `summary_only` bypass (second code path in `memory_recall`). ADR-037 validates the approach and rejects alternatives. LOC estimate ~130–150 — within the 300 LOC PR limit.

- [x] Principle I: Spec approved with post-review revisions; all LOGs raised during review are resolved in this plan
- [x] Principle II: No speculative abstractions; every change targets a named FR or resolves a LOG; `scan_chunks` is required by FR-006
- [x] Principle III: TDD — contract and unit tests written before `server.py` changes; integration tests before testing against live Ollama
- [x] Principle IV: US-1 (read resilience) and US-2 (write resilience) are independently deliverable in task order; P1 tasks complete before any P2 task begins
- [x] PR Policy: ~130–150 LOC estimate; single PR within 300 LOC limit

## Project Structure

### Documentation (this feature)

```text
specs/006-ollama-fallback/
├── plan.md              # This file
├── research.md          # Phase 0 output: all NEEDS CLARIFICATION resolved
├── data-model.md        # Phase 1 output: environment variables + conceptual states
├── contracts/
│   └── tool-error-contract.md  # Tool error channel delta (ADR-033 breaking change)
└── tasks.md             # Phase 2 output (generated by /speckit.tasks — not this command)
```

### Source Code

```text
memory-server/
  speckit_memory/
    server.py            # Primary target: error handling, summary_only bypass, _ensure_init fix, timeout
    sync.py              # Modify: add timeout param to _ollama_embed
    index.py             # Modify: add scan_chunks function (~20 LOC)
  tests/
    contract/            # Modify: update tool contract tests — ToolError replaces error dict
    unit/                # Add: summary_only bypass tests, _ensure_init tests, exception catch tests
    integration/         # Add: timeout and Ollama-down integration tests (marked, require Ollama)
```

**Structure Decision**: No new modules or packages. All changes are targeted modifications to existing files. `scan_chunks` is the only significant addition to the data layer.

## Implementation Design

### Change 1: Timeout configuration (FR-004, FR-005)

**File**: `sync.py`
```python
def _ollama_embed(text: str, base_url: str, model: str, timeout: float = 10.0) -> list[float]:
    import ollama
    client = ollama.Client(host=base_url, timeout=timeout)
    response = client.embed(model=model, input=text)
    return response["embeddings"][0]
```

**File**: `server.py`
```python
_OLLAMA_TIMEOUT = float(os.environ.get("OLLAMA_TIMEOUT", "10"))

def _embed_text(text: str) -> list[float]:
    return _ollama_embed(text, _OLLAMA_BASE_URL, _OLLAMA_MODEL, _OLLAMA_TIMEOUT)
```

Timeout env var read once at module load. Bad value (non-numeric) → `ValueError` at import, caught by MCP framework startup.

### Change 2: Exception catch clauses + ToolError (FR-001, FR-002, FR-003)

**Imports to add in `server.py`**:
```python
import httpx
import ollama as ollama_sdk
from fastmcp.exceptions import ToolError
```

**Helper** (replaces `_api_unavailable`):
```python
def _embed_error(exc: Exception, model: str) -> None:
    """Raise ToolError with category-prefixed message. Never returns."""
    if isinstance(exc, ollama_sdk.ResponseError) and getattr(exc, 'status_code', None) == 404:
        raise ToolError(
            f"EMBEDDING_MODEL_ERROR: model '{model}' is not available. "
            f"Hint: run `ollama pull {model}` to download the model."
        )
    if isinstance(exc, httpx.TimeoutException):
        raise ToolError(
            f"EMBEDDING_UNAVAILABLE: Ollama did not respond within {_OLLAMA_TIMEOUT}s. "
            f"Hint: check that Ollama is running and accessible at {_OLLAMA_BASE_URL}."
        )
    raise ToolError(
        f"EMBEDDING_UNAVAILABLE: Ollama is not reachable at {_OLLAMA_BASE_URL}. "
        f"Hint: run `ollama serve` to start the embedding service."
    )
```

**Catch pattern** (used in `memory_store`, `memory_sync`, `memory_recall`):
```python
except (ConnectionError, OSError, httpx.TimeoutException, ollama_sdk.ResponseError) as exc:
    _embed_error(exc, _OLLAMA_MODEL)
```

### Change 3: summary_only bypass (FR-006)

**File**: `index.py` — add `scan_chunks`:
```python
def scan_chunks(
    table: Any,
    top_k: int = 5,
    filter_type: str | None = None,
    filter_feature: str | None = None,
    filter_tags: list[str] | None = None,
    filter_source_file: str | None = None,
) -> list[dict[str, Any]]:
    """Return chunks without vector search. Used for summary_only bypass (ADR-037)."""
    rows = table.to_arrow().to_pylist()
    if filter_type:
        rows = [r for r in rows if r.get("type") == filter_type]
    if filter_feature:
        rows = [r for r in rows if r.get("feature") == filter_feature]
    if filter_tags:
        rows = [r for r in rows if all(t in (r.get("tags") or []) for t in filter_tags)]
    if filter_source_file:
        rows = [r for r in rows if r.get("source_file") == filter_source_file]
    return rows[:top_k]
```

**File**: `server.py` — restructure `memory_recall` preamble:
```python
def memory_recall(..., summary_only: bool = False) -> dict:
    if max_chars is not None and max_chars <= 0:
        return {"error": {"code": "INVALID_INPUT", ...}}

    # LOG-038: skip _ensure_init on summary_only path — post-T007, _ensure_init retries
    # on every call when Ollama is down; summary_only uses init_table() directly.
    if not summary_only:
        _ensure_init()

    # ADR-037: summary_only bypasses Ollama entirely
    if summary_only:
        idx_dir = _index_dir()
        idx_dir.mkdir(parents=True, exist_ok=True)
        table = init_table(idx_dir)
        f = filters or {}
        results = scan_chunks(
            table=table,
            top_k=min(top_k, 20),
            filter_type=f.get("type"),
            filter_feature=f.get("feature"),
            filter_tags=f.get("tags"),
            filter_source_file=filter_source_file,
        )
        results = [{"source_file": r["source_file"], "section": r["section"]} for r in results]
        # budget enforcement, token_estimate, response construction follow...
        ...
        return response

    # Semantic path (Ollama required)
    try:
        query_vec = _embed_text(query)
    except (ConnectionError, OSError, httpx.TimeoutException, ollama_sdk.ResponseError) as exc:
        _embed_error(exc, _OLLAMA_MODEL)
    ...
```

### Change 4: `_ensure_init` flag ordering fix (LOG-035)

```python
def _ensure_init() -> None:
    global _first_call_done
    if _first_call_done:
        return
    idx_dir = _index_dir()
    idx_dir.mkdir(parents=True, exist_ok=True)
    try:
        run_sync(...)
        _first_call_done = True    # ← moved inside try, after successful sync
    except Exception as exc:
        print(f"[speckit-memory] WARNING: auto-init sync failed: {exc}", file=sys.stderr)
        # _first_call_done stays False → next call will retry
```

### Change 5: EMBEDDING_CONFIG_ERROR (FR-009)

Add URL validation at module load or on first embed call. If `OLLAMA_BASE_URL` is not a valid HTTP/HTTPS URL, raise:
```
ToolError("EMBEDDING_CONFIG_ERROR: OLLAMA_BASE_URL is not a valid URL. Hint: check the value of the OLLAMA_BASE_URL environment variable.")
```

Detection: `urllib.parse.urlparse(_OLLAMA_BASE_URL).scheme not in ("http", "https")`. Called in `_embed_text` before creating the client.

## Complexity Tracking

No constitution violations. The only added complexity is `scan_chunks` in `index.py`, which is required by FR-006 and documented in ADR-037.
