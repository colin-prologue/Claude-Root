# Research: Ollama Fallback (006)

**Branch**: `006-ollama-fallback`
**Date**: 2026-04-14
**Resolves**: LOG-034, LOG-035, LOG-036

## Finding 1: Ollama SDK Exception Hierarchy (Resolves LOG-036)

**Decision**: Extend all Ollama catch clauses to `(ConnectionError, OSError, httpx.TimeoutException, ollama.ResponseError)`.

**Verified against ollama SDK source** (`_client.py:127-135`):

```python
def _request_raw(self, *args, **kwargs):
    try:
        r = self._client.request(*args, **kwargs)
        r.raise_for_status()
        return r
    except httpx.HTTPStatusError as e:
        raise ResponseError(e.response.text, e.response.status_code) from None
    except httpx.ConnectError:
        raise ConnectionError(CONNECTION_ERROR_MESSAGE) from None
```

Exception paths from the SDK perspective:

| Condition | httpx raises | ollama SDK re-raises | Current catch | Fix needed? |
|---|---|---|---|---|
| Connection refused (Ollama not running) | `httpx.ConnectError` | Python `ConnectionError` (built-in) | ✓ caught by `except ConnectionError` | No |
| Timeout (Ollama slow or hung) | `httpx.TimeoutException` | **not caught** → propagates | ✗ unhandled | Yes |
| Model not found (404) | `httpx.HTTPStatusError` | `ollama.ResponseError(status=404)` | ✗ unhandled | Yes |
| Invalid URL / parse error | `ValueError` (at client init) | `ValueError` | ✗ unhandled | Yes |

**Note**: LOG-036 stated "httpx.ConnectError IS a subclass of ConnectionError (Python built-in)" — this is INCORRECT. `issubclass(httpx.ConnectError, ConnectionError)` is `False`. However, the ollama SDK wraps `httpx.ConnectError` as Python's built-in `ConnectionError`, so the current catch clause happens to work for connection refused. The fix adds the missing exception types.

---

## Finding 2: Ollama SDK Timeout Configuration (FR-004, FR-005)

**Decision**: Configure timeout via `ollama.Client(host=base_url, timeout=N)`. Thread via new `OLLAMA_TIMEOUT` env var (default 10.0 seconds) through `_embed_text` → `_ollama_embed`.

**Verification**: `BaseClient.__init__` in the SDK accepts `timeout: Any = None` as an explicit named parameter (line 85), which flows directly to `httpx.Client(timeout=timeout)`. Default `None` means no timeout — indefinite hang on a slow/dead Ollama instance. Setting `timeout=10.0` bounds all HTTP calls to the Ollama API.

**Threading strategy**: Modify `_ollama_embed(text, base_url, model, timeout)` in `sync.py` to accept and pass `timeout`. Modify `_embed_text(text)` in `server.py` to read `OLLAMA_TIMEOUT` env var and pass it through. No module-level client singleton — keeps the existing per-call pattern.

**Alternatives considered**:
- Module-level singleton client: avoids constructor call overhead. Rejected — changing the existing instantiation pattern for marginal benefit in a sub-1 QPS solo tool violates Principle II.
- Per-request timeout via `httpx.Client.request(timeout=...)`: SDK doesn't expose this at the per-call level. Client-level timeout is the SDK's intended pattern.

---

## Finding 3: summary_only Bypass Strategy (Resolves LOG-034)

**Decision**: Add `scan_chunks(table, top_k, filters, filter_source_file)` to `index.py`. In `memory_recall`, check `summary_only` BEFORE calling `_embed_text`. If `summary_only=True`, call `scan_chunks` and skip embedding entirely. Return results without score field. See ADR-037.

**Code path analysis** (current `server.py`):
```
line 120: _ensure_init()          ← calls run_sync → embed_fn (Ollama)
line 123: _embed_text(query)       ← Ollama call #2 (query vector)
line 146: if summary_only:         ← flag finally checked HERE
```

Both Ollama calls execute before `summary_only` is checked. Fix: check `summary_only` at line 122 (before `_embed_text`), branch to `scan_chunks` path.

**`_ensure_init` behavior**: Already catches all exceptions and continues with a warning. If Ollama is down during self-init, the function prints to stderr and returns — it does NOT crash. So `_ensure_init` in summary_only mode is safe; the only crash source is `_embed_text(query)` at line 123.

**scan_chunks implementation**: LanceDB table supports non-vector queries via Python-level filtering on `table.to_arrow().to_pylist()`. Returns all chunks (or filtered subset), limited to `top_k`, sorted by insertion order. No score field — callers receive `{source_file, section}` in summary_only bypass mode.

---

## Finding 4: `_ensure_init` Flag Ordering Fix (Resolves LOG-035)

**Decision**: Move `_first_call_done = True` assignment to inside the `try` block, AFTER `run_sync` completes successfully.

**Current bug** (server.py lines 73-90):
```python
_first_call_done = True    # set HERE (before run_sync)
try:
    run_sync(...)          # can fail if Ollama is down
except Exception:
    print(warning)
    # _first_call_done is already True → no retry possible
```

**Fix**:
```python
try:
    run_sync(...)
    _first_call_done = True    # set only on success
except Exception:
    print(warning)
    # _first_call_done remains False → next call retries
```

Low-risk change. The flag becomes True only when Ollama was reachable and the index was successfully initialized.

---

## Finding 5: Manifest Atomicity (FR-007)

**Decision**: No change to `run_sync` needed for manifest consistency. `save_manifest` is already called only at the end of the loop — if an exception propagates mid-run, the manifest on disk is unmodified.

**DB partial-state (out of scope)**: If sync crashes after some files are embedded (chunks written to DB) but before `save_manifest`, those chunks exist in the DB but the manifest doesn't record them. On next sync, those files are re-classified as "new" and re-embedded — creating duplicate chunks in the DB until the next `full=True` rebuild. This is a pre-existing data integrity issue unrelated to 006. Noted but not fixed here; deferred to a future LOG.

---

## Finding 6: FR-003 — Three-Category Error Distinction

**Decision**: Distinguish Ollama error conditions using ToolError message prefixes:

| Condition | Exception | ToolError message prefix | Hint |
|---|---|---|---|
| Ollama not running | `ConnectionError` | `EMBEDDING_UNAVAILABLE:` | `run \`ollama serve\`` |
| Ollama timeout | `httpx.TimeoutException` | `EMBEDDING_UNAVAILABLE:` | `check Ollama is running; timeout = {N}s` |
| Model not pulled | `ollama.ResponseError` (status 404) | `EMBEDDING_MODEL_ERROR:` | `run \`ollama pull {model}\`` |
| Invalid URL | `ValueError` from URL parse | `EMBEDDING_CONFIG_ERROR:` | `check OLLAMA_BASE_URL` |

Model-not-found detection: `ollama.ResponseError` exposes `status_code` attribute. HTTP 404 → model not found. All other `ResponseError` status codes → treated as `EMBEDDING_UNAVAILABLE`.
