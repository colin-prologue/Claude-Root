# LOG-014: Parameter Naming Drift — `filter` vs `filters` in memory_recall

**Date**: 2026-04-08
**Type**: CHALLENGE
**Status**: Open
**Raised In**: speckit.audit consistency audit — contracts/mcp-tools.md:22 vs server.py:103
**Related ADRs**: None

---

## Description

`contracts/mcp-tools.md` documents the `memory_recall` tool with a parameter named `filter` (singular). The implementation in `server.py:103` declares the parameter as `filters` (plural). These are out of sync — one canonical name should be chosen and both artifacts updated to match.

## Context

The parameter was originally named `filter` in the spec and contract. During code review (2026-04-07), it was renamed to `filters` in the implementation to avoid shadowing Python's built-in `filter()` function. The contract was not updated at the same time.

For MCP callers (Claude Code, skills), FastMCP serializes tool schemas from the Python function signature, so the effective parameter name exposed over the MCP protocol is `filters` (what the code says). The contract is now the stale artifact.

## Discussion

### Pass 1 — Initial Analysis

Two options:
- **Update contract to `filters`** (plural): aligns docs with code and the MCP-exposed schema. The rename rationale (avoids Python builtin shadowing) is valid regardless of language.
- **Revert code to `filter`** (singular): aligns code with docs but re-introduces the shadowing issue.

### Pass 2 — Critical Review

Since FastMCP derives the MCP tool schema from the Python signature, callers already see `filters`. Reverting would require a code change and lose the shadowing fix. The contract update is the lower-risk path.

### Pass 3 — Resolution Path

Update `contracts/mcp-tools.md` to use `filters` throughout. Annotate the rename rationale in a contract comment.

## Resolution

Pending update to `contracts/mcp-tools.md`.

**Resolved By**: N/A (open)
**Resolved Date**: N/A

## Impact

- [ ] Spec updated: specs/002-vector-memory-mcp/spec.md (if `filter` appears there)
- [ ] Plan updated: N/A
- [ ] ADR created/updated: N/A
- [x] Contract to update: specs/002-vector-memory-mcp/contracts/mcp-tools.md — rename `filter` → `filters`
