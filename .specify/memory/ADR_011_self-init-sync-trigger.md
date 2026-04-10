# ADR-011: Self-Initializing Sync on First MCP Tool Call

**Date**: 2026-04-06
**Status**: Accepted
**Decision Made In**: specs/002-vector-memory-mcp/plan.md § Phase 0 Research
**Related Logs**: None

---

## Context

The spec requires (FR-011) that session-start sync complete before any skill invokes `memory_recall`. Three sync trigger strategies were considered: a Claude Code session-start hook, a git post-commit hook, and self-initialization on the first MCP tool call.

## Decision

The MCP server will auto-sync (mtime manifest diff) on the first invocation of any memory tool per process lifetime. No external hook is required.

## Alternatives Considered

### Option A: Self-initialize on first tool call *(chosen)*

MCP servers are spawned lazily by Claude Code on first tool reference. The server runs a manifest diff sync synchronously before returning from the first call, then caches the "synced" state for the process lifetime.

**Pros**: No external configuration; aligns with how Claude Code already works; <50ms overhead when clean; satisfies FR-011 and SC-002 without any hook setup
**Cons**: First call of a session has slightly higher latency; developer has no visibility into when sync runs

### Option B: Claude Code settings.json hook

Use `PreToolUse` or a similar hook to trigger `memory_sync` before any tool call.

**Pros**: Explicit, visible trigger point
**Cons**: Claude Code has no session-start hook — only tool-centric hooks (`PreToolUse`, `PostToolUse`). Wiring a hook to every tool call adds overhead and couples the memory system to the hook configuration unnecessarily. Fragile if hook config is lost.

### Option C: Git post-commit hook

Add a `.git/hooks/post-commit` script that calls `memory_sync` after each commit.

**Pros**: Index always reflects committed state
**Cons**: Adds embedding API latency to every commit; disruptive in fast-commit workflows; requires hook installation per clone (not automatic with `git clone`)

## Rationale

Claude Code's hook system is tool-centric, not session-centric, so Option B cannot deliver a true session-start trigger. Option C adds unacceptable commit friction. Option A exploits the existing MCP lazy-start behavior cleanly: the server initializes, syncs, and is ready — all before the first tool result returns. The `memory_sync` tool remains available for explicit mid-session refresh (satisfying the on-demand requirement from the design conversations).

## Consequences

**Positive**: Zero external configuration; no git hook maintenance; works correctly in all session contexts
**Negative / Trade-offs**: Sync is invisible to the developer; first call per session is slightly slower than subsequent calls
**Risks**: If the manifest diff logic has a bug, every session pays the full re-index cost. Mitigated by keeping the manifest diff implementation simple and well-tested.
**Follow-on decisions required**: None

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-06 | Initial record | speckit.plan |
