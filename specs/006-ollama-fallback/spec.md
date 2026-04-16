# Feature Specification: Ollama Fallback

**Feature Branch**: `006-ollama-fallback`
**Created**: 2026-04-13
**Status**: Draft
**Revised**: 2026-04-14 — post-review revisions (see Decision Records)

## Decision Records

| # | Type | File | Title | Status |
|---|---|---|---|---|
| 032 | ADR | ADR_032_006-scope-errors-vs-bm25.md | Ollama-down scope: structured errors (006) vs. BM25 fallback (007) | Accepted |
| 033 | ADR | ADR_033_mcp-error-channel-strategy.md | MCP error channel strategy: raise ToolError, not return-value dicts | Accepted |
| 034 | LOG | LOG_034_summary-only-ollama-dependency.md | `summary_only` mode does not currently bypass Ollama | Resolved → plan.md |
| 035 | LOG | LOG_035_first-call-done-before-init-success.md | `_ensure_init` sets flag before init succeeds — blocks retry-on-recovery | Resolved → plan.md |
| 036 | LOG | LOG_036_httpx-timeout-exception-catch-gap.md | `httpx.TimeoutException` escapes current catch clauses — FR-004 blocker | Resolved → plan.md (impl uses `httpx.TransportError`) |
| 038 | LOG | LOG_038_ensure-init-retry-non-embed-tools.md | `_ensure_init` retry-on-every-call adds ~10s latency to `summary_only`/delete after T007 | Open |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Read Operations Survive Ollama Outage (Priority: P1)

A developer queries the memory server for relevant prior decisions (`memory_recall`) while Ollama is down — perhaps because they haven't started Ollama yet, or it crashed. Today the call fails with an unhandled exception. With this feature, summary-only recall still executes (no embedding needed) and semantic recall fails with a structured, actionable error rather than a crash or hang.

**Why this priority**: Recall is the most frequent operation. A downed Ollama instance should not break reading — only embedding new content requires the service. Graceful degradation here has the highest daily-use impact.

**Independent Test**: Given the memory index contains previously embedded chunks and Ollama is not running, when a developer calls `memory_recall` in `summary_only` mode, then results are returned successfully with no Ollama contact and no error. When called in semantic mode (embedding required), the call returns a structured error within 10 seconds — no crash, no hang, no unhandled exception.

**Acceptance Scenarios**:

1. **Given** the memory index is populated and Ollama is not running, **When** `memory_recall` is called in `summary_only` mode, **Then** results are returned successfully without attempting to contact Ollama
2. **Given** the memory index is populated and Ollama is not running, **When** `memory_recall` is called in semantic mode, **Then** a structured error with `code: "EMBEDDING_UNAVAILABLE"` is returned within 10 seconds — no unhandled exception
3. **Given** Ollama fails during the embedding call with a connection error, **When** the error occurs, **Then** the response includes `code: "EMBEDDING_UNAVAILABLE"` and a `hint` field naming a corrective action

---

### User Story 2 - Write Operations Fail Gracefully with Actionable Errors (Priority: P1)

A developer calls `memory_store` or `memory_sync` while Ollama is unavailable. Today this raises an unhandled exception surfacing as a confusing MCP error. With this feature, the operation returns a structured error immediately — within a bounded timeout — with a clear message telling the developer what to do (start Ollama, check the URL, verify the model is pulled).

**Why this priority**: A hanging `memory_sync` blocks the entire tool and is the highest-friction failure mode in daily use. Graceful write failures prevent silent confusion and reduce debugging time. Elevated to P1 (from original P2) because sync hang is more disruptive than a failed semantic recall.

**Independent Test**: Given Ollama is not running, when a developer calls `memory_store` with any content, then the response is a structured error with `code: "EMBEDDING_UNAVAILABLE"`, a human-readable `message`, a `hint` field with a corrective action (e.g., "run `ollama serve`"), and the call returns within 10 seconds — no hang.

**Acceptance Scenarios**:

1. **Given** Ollama is not running, **When** `memory_store` is called, **Then** a structured error with `code: "EMBEDDING_UNAVAILABLE"` and a `hint` field is returned within 10 seconds
2. **Given** Ollama is running but the configured model is not pulled, **When** `memory_store` or `memory_sync` is called, **Then** the error distinguishes "service unreachable" from "model not found" and includes the model name in the `hint`
3. **Given** `memory_sync` is mid-run and Ollama goes down after some files are embedded, **When** the failure occurs, **Then** the manifest is not written with partial state — no file is marked as indexed unless its vector was successfully stored

---

### Edge Cases

- What happens when Ollama goes down mid-sync after some chunks have been embedded? The manifest must not mark un-embedded files as indexed.
- What if `OLLAMA_BASE_URL` is syntactically invalid? The error must use a distinct code (`EMBEDDING_CONFIG_ERROR`) — "fix your config" is a different corrective action than "start Ollama."
- What if Ollama returns a malformed embedding response (wrong dimensions, null vector)? The server must not write a corrupt vector to the index.
- What if `memory_recall` is called against an empty index when Ollama is also down? The response should be a valid empty result in summary-only mode, not an error.
- What happens if the timeout environment variable is set to a non-numeric value? The server must fall back to the default timeout with a warning.
- What if `memory_delete` is called when Ollama is down? Delete does not require embedding and should succeed regardless of Ollama availability.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST raise a `ToolError` (not return a value, not raise an unhandled exception) when Ollama is unreachable during any write or embed operation. This produces an `isError: true` MCP response visible to Claude Code as a tool failure. See ADR-033.
- **FR-002**: The `ToolError` message MUST be human-readable and include: the error category as a string prefix (e.g., `EMBEDDING_UNAVAILABLE:`), a plain-language description, and a corrective action hint (e.g., `Hint: run \`ollama serve\``). No structured dict is required.
- **FR-003**: The system MUST distinguish between at least three Ollama error conditions with distinct `ToolError` messages: "service unreachable," "model not found/not pulled," and "configuration error (invalid URL)"
- **FR-004**: All calls that require Ollama MUST time out within a configurable threshold rather than hanging indefinitely. **Note**: implementing this requires catching `httpx.TimeoutException` in addition to `ConnectionError`/`OSError` — see LOG pending item.
- **FR-005**: The timeout threshold MUST be configurable via environment variable with a default of 10 seconds
- **FR-006**: `memory_recall` in `summary_only` mode MUST succeed even when Ollama is unavailable. **Prerequisite**: this requires restructuring `memory_recall` to short-circuit the `_embed_text` call before it fires when `summary_only=True` — the current code calls `_embed_text` unconditionally at line 123 of `server.py`, before `summary_only` is checked at line 146. This code change must be scoped as an explicit task in the plan.
- **FR-007**: A `memory_sync` that fails mid-run (some files embedded, some not) MUST NOT write a manifest that marks un-embedded files as successfully indexed
- **FR-008**: `memory_delete` MUST succeed regardless of Ollama availability — delete operations do not require embedding
- **FR-009**: If `OLLAMA_BASE_URL` is syntactically invalid or produces a non-HTTP protocol error, the response MUST use error code `EMBEDDING_CONFIG_ERROR` and a `hint` naming the misconfigured variable

### Out of Scope

- BM25/keyword search fallback for when Ollama is unavailable. This was the original roadmap intent for feature 006; the scope is reduced here to structured errors and graceful degradation of operations that don't require embedding. BM25 fallback is deferred to feature 007. See ADR (pending) for rationale.
- Retry logic with backoff. A single attempt with a bounded timeout is sufficient; the MCP caller can retry if desired.
- Startup health check. A developer gets equivalent information on the first tool call via the structured error response. Adding a separate startup check is complexity for no new information.
- Alternative embedding providers (e.g., OpenAI). "Fallback" in this feature means continuing to function without embedding, not substituting a different embedding source.

### Key Entities

- **Embedding Availability State**: Whether Ollama is reachable and the configured model is available — checked on each embed call (blocking, timeout-bounded)
- **ToolError message convention**: `"CATEGORY: plain-language description. Hint: corrective action."` — raised (not returned) whenever Ollama is unavailable, producing `isError: true` in the MCP response

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `memory_recall` in summary-only mode succeeds in 100% of calls regardless of Ollama availability
- **SC-002**: Any tool call requiring Ollama returns a structured error within 10 seconds when Ollama is unreachable — no call hangs indefinitely
- **SC-003**: 100% of Ollama-unavailability error responses include a `hint` field with a corrective action
- **SC-004**: A partial `memory_sync` failure leaves the manifest in a consistent state — no file is marked indexed unless its vector was successfully written to the index
- **SC-005**: `memory_delete` succeeds when Ollama is unavailable

## Assumptions

- "Fallback" in this feature means graceful degradation: operations that don't require embedding (summary-only recall, delete) continue working; operations that require embedding fail with structured errors. BM25/keyword search fallback is a separate, follow-on feature (007).
- The existing `_api_unavailable` helper in `server.py` will be removed. All Ollama-unavailability paths will raise `ToolError` instead of returning dicts. See ADR-033.
- The startup health check is intentionally excluded. The first-call error response provides equivalent information with less code.
- The `summary_only` mode in `memory_recall` currently does NOT bypass the embedding call (verified against `server.py`). Making it bypass embedding requires a targeted code change to `memory_recall`; this is an explicit implementation task, not a given.
- `_ensure_init` currently sets `_first_call_done = True` before initialization succeeds. If Ollama is down on the first call, the server will not retry initialization even if Ollama becomes available later. This is a known limitation; fixing it is an implementation task.
