# ADR-033: MCP Error Channel Strategy — Raise ToolError, Not Return-Value Dicts

**Date**: 2026-04-14
**Status**: Accepted
**Decision Made In**: specs/006-ollama-fallback/spec.md (post-review revision)
**Related Logs**: LOG-034, LOG-035, LOG-036

---

## Context

The memory server uses FastMCP as its MCP framework. When Ollama is unavailable, the current code returns structured error dicts as the tool's return value — e.g., `{"error": {"code": "EMBEDDING_UNAVAILABLE", "message": "...", "hint": "..."}}`. This is sent to MCP clients as `isError: false` — a successful tool call that returns an error-shaped payload. Claude Code has no protocol-level signal that the tool failed; it just displays the dict as text.

The MCP protocol has a standard mechanism for tool-level errors: a `CallToolResult` with `isError: true`. FastMCP exposes this via `ToolError` (`fastmcp/exceptions.py:27`). When a tool raises `ToolError`, FastMCP propagates it to the MCP SDK, which returns `isError: true` with the message as content. This is the correct channel for communicating tool failure.

FastMCP already uses this pattern internally — `server.py:1178-1181` catches `httpx.TimeoutException` and wraps it as `ToolError("Upstream request timed out, please retry")`. Our tools should be consistent with the framework.

## Decision

Replace all `return _api_unavailable(...)` calls with `raise ToolError(...)` using human-readable message strings that include the error category and corrective action. Drop the structured `{code, message, hint}` dict format.

Example:
```python
raise ToolError(
    "EMBEDDING_UNAVAILABLE: Ollama is not running. "
    "Hint: run `ollama serve` to start the embedding service."
)
```

## Alternatives Considered

### Option A: Raise ToolError with formatted message string *(chosen)*

Raise `ToolError("CATEGORY: message. Hint: corrective action.")` from all Ollama-unavailability paths.

**Pros**: `isError: true` — correct MCP protocol signal; Claude Code handles tool failures natively; consistent with FastMCP's own internal error handling; simpler than a dict (no schema to maintain)
**Cons**: Error category is embedded in the string, not a parseable field — if a future caller wants to branch on error code programmatically, they'd need to parse the string

### Option B: Return-value dicts (current approach)

Return `{"error": {"code": "...", "message": "...", "hint": "..."}}` as the tool's regular return value.

**Pros**: Structured machine-readable fields; zero migration cost
**Cons**: `isError: false` — callers see a "success" response with an error dict; no protocol-level failure signal; Claude Code may silently display the dict without treating it as a failure

### Option C: Custom ToolError subclass with structured fields

Subclass `ToolError` to carry `code` and `hint` as attributes while still raising for `isError: true`.

**Pros**: Both correct protocol channel and structured fields
**Cons**: Overengineered for a solo-dev tool with no programmatic callers of the error fields today

## Rationale

Option A was chosen. The `recoverable` field was already dropped (ADR-032 review). With it gone, the remaining fields — `code`, `message`, `hint` — are all human-readable strings that fit naturally in a single formatted message. No caller today branches programmatically on the error code. The simplicity principle (NON-NEGOTIABLE per constitution) rules out Option C. Option B uses the wrong protocol channel and risks invisible errors.

The migration cost is bounded: every `return _api_unavailable(...)` in `server.py` becomes a `raise ToolError(...)`. The `_api_unavailable` helper can be removed entirely.

## Consequences

**Positive**: Correct `isError: true` signal to Claude Code; simpler error handling (no dict schema); consistent with FastMCP framework conventions; `_api_unavailable` helper can be deleted
**Negative / Trade-offs**: Error category (`EMBEDDING_UNAVAILABLE`, `EMBEDDING_CONFIG_ERROR`) is a string prefix in the message, not a parseable key — acceptable given no programmatic callers exist today
**Risks**: If a future feature needs to branch on error type, the string-prefix convention would need to be formalized or a structured approach adopted at that point
**Follow-on decisions required**: None

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-14 | Initial record — open pending FastMCP investigation | Claude (post-review revision) |
| 2026-04-14 | Accepted Option A after FastMCP source verification | Claude |
