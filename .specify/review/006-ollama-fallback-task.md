# Review in Progress: 006-ollama-fallback — task gate
**Started**: 2026-04-15T00:19:00Z
**Phase**: complete — awaiting gate decision
**Panel**: devils-advocate

---

## Phase A: Devil's Advocate

### Critical Finding: `_ensure_init` / `summary_only` interaction after T007 flag fix

**T009 claims `memory_recall(summary_only=True)` never calls `_embed_text`**, but `_ensure_init()` calls `run_sync()` which calls `embed_fn` (i.e., `_embed_text`). After T007 moves `_first_call_done = True` inside the try block, `_first_call_done` stays `False` on failure — so every `summary_only=True` call with Ollama down will retry `_ensure_init()`, triggering `run_sync()`, hitting a ~10s embed timeout each time. This violates spec acceptance scenario 1 ("without attempting to contact Ollama"), FR-006, and SC-001.

Confidence: 85%.

### High Finding: Existing contract test will break after T014

`test_tools.py` (existing) has `test_recall_summary_only_omits_content` asserting `assert "score" in entry` for summary_only results. After T014 restructures `memory_recall` to use `scan_chunks` (which returns no score), this test will fail. T010 only covers "semantic mode with Ollama down" — it does not mention updating the existing summary_only contract test to remove the score assertion. This is a regression that will block the test suite.

### Medium Finding: T021 scope ambiguity — two exception handlers in `memory_sync`

`memory_sync` has two distinct exception handlers: (a) `except (ConnectionError, OSError)` and (b) a generic `except Exception` with string matching that also calls `_api_unavailable`. T021 says "replace both existing `_api_unavailable` call sites" without explicitly addressing the string-matching catch. It should be removed (replaced by the broader clause), but this isn't explicit.

### Low Finding: Spec/plan/tasks inconsistency on `OLLAMA_TIMEOUT` non-numeric fallback

Spec edge case: "server must fall back to default timeout with a warning." Plan says: "`ValueError` at import, caught by MCP framework startup." Tasks follow the plan. The spec's stated behavior is not implemented.

### Assumption inventory highlights

| Assumption | Status | Impact |
|---|---|---|
| `_ensure_init` is harmless for `summary_only` after T007 | RISKY — HIGH confidence | Every summary_only call waits ~10s when Ollama is down |
| T004/T005 parallel (different files) | VALIDATED | Safe |
| T016 [P] marker is correct | PLAUSIBLE | Runs after Phase 3 anyway; misleading but not wrong |
| T021 covers both `_api_unavailable` call sites in `memory_sync` | NEEDS CLARIFICATION | One site may be missed |
| Non-numeric `OLLAMA_TIMEOUT` crashes at import | RISKY (spec disagrees) | Minor edge case |

