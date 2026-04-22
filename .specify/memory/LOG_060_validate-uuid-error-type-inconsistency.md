# LOG-060: `_validate_uuid` Raises `ValueError` vs. Module-Wide `ToolError`

**Date**: 2026-04-22
**Type**: QUESTION
**Status**: Open
**Raised In**: /speckit.codereview on branch `skill-plugin-optimization` (devils-advocate blind-spot notes, 2026-04-22)
**Related ADRs**: ADR-009 (Python + FastMCP runtime)

---

## Description

`memory-server/speckit_memory/index.py:59` defines `_validate_uuid(value)` which
raises a bare `ValueError` on malformed UUID input. The rest of the MCP surface
(`server.py`) wraps user-facing errors in `fastmcp.exceptions.ToolError` so they
propagate to the MCP client as structured tool errors rather than internal
tracebacks. `_validate_uuid` is called from `delete_chunk_by_id`
(`index.py:185`) which is invoked by the `memory_delete` tool handler; the
`ValueError` escapes unwrapped.

## Context

Surfaced during the `skill-plugin-optimization` code review as a blind-spot note.
Pre-existing code — not introduced by this branch's ADR-055 refactor, but
noticed while reviewing `index.py`. The error-type inconsistency is currently
masked because client UUIDs are well-formed in normal use; a malformed chunk id
passed to `memory_delete` would produce a stack trace rather than a tidy
`ToolError` envelope.

## Discussion

### Pass 1 — Initial Analysis

Options:
1. Let `_validate_uuid` raise `ToolError` directly. Small change; couples the
   index-layer helper to the MCP framework.
2. Keep `ValueError` at the index layer; have `memory_delete`'s tool handler
   translate `ValueError → ToolError`. Preserves layering; one more line in the
   handler.
3. Leave as-is. Current behavior works for well-formed input; invalid-UUID path
   is a misuse that will surface a traceback but not lose data.

### Pass 2 — Critical Review

Option 2 is the cleanest separation of concerns — the helper doesn't know it
lives behind an MCP tool. The cost is one `try / except ValueError` in the tool
handler. Option 1 bleeds the MCP framework into a pure data helper. Option 3 is
acceptable for a solo-dev tool where malformed UUIDs are a developer error, not
an end-user error surface.

## Resolution

Deferred. Not a correctness bug under normal use. If `memory_delete` ever gets
surfaced in a user-facing skill where a client-supplied id could be malformed
(rather than the current `memory_recall` → delete-by-returned-id flow), promote
to Option 2.

**Resolved By**: N/A (open)
**Resolved Date**: N/A

## Impact

- [ ] Code updated: deferred
- [ ] Spec updated: N/A
- [ ] ADR created/updated: none required
