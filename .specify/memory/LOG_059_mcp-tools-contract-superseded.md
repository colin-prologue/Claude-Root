# LOG-059: `specs/002-vector-memory-mcp/contracts/mcp-tools.md` Superseded by 003/006/007/008 Deltas

**Date**: 2026-04-20
**Type**: UPDATE
**Status**: Open
**Raised In**: speckit.audit full-repo findings (2026-04-20) § HIGH H1
**Related ADRs**: None (contract lifecycle, not architectural)

---

## Description

The MCP tool contract in `specs/002-vector-memory-mcp/contracts/mcp-tools.md` is the
baseline reader-facing surface for the memory server. Since 002 shipped, four
subsequent features have added parameters and response fields that are not reflected
in the 002 base contract:

- **003 (memory-server-hardening)** added `max_chars`, `filter_source_file`,
  `summary_only` to `memory_recall`; `token_estimate`, `budget_exhausted`,
  `truncated` to the response envelope
- **006 (ollama-fallback)** changed error channel from envelope-based to ToolError;
  added summary_only bypass path (ADR-037); added `synthetic` flag on result items
- **007 (bm25-keyword-fallback)** added `degraded` flag on the response envelope
- **008 (auto-sync-staleness)** — no contract change, but the staleness side effect
  is worth mentioning in the recall description

Each delta feature has its own contract file describing the change, but the 002
base has not been updated. A new reader starting from 002 gets an inaccurate
picture.

## Context

Surfaced during the full-repo audit on 2026-04-20. The rule-of-three duplicate in
index.py (H3) is the most visible drift; this contract gap is subtler but affects
external callers (LLM agents reading the contract to understand the tool shape).

## Discussion

### Pass 1 — Initial Analysis

Two resolution shapes:
1. **Mark 002 contract superseded.** Add a banner at the top of
   `002/contracts/mcp-tools.md` pointing readers to 006's `contracts/memory-tool-updates.md`
   (or wherever the latest diff lives) as the authoritative surface.
2. **Backfill the 002 contract in place.** Merge the 003/006/007 deltas into the
   002 base so it becomes the single authoritative contract.

### Pass 2 — Critical Review

Option 1 preserves historical accuracy (the 002 contract was true at 002 ship) but
creates a hopping reader experience. Option 2 rewrites history (002's contract no
longer reflects what 002 actually shipped) but gives one canonical contract.

A hybrid is best: keep 002 as-shipped, add a prominent banner at the top listing the
delta features in order with links, and make sure each delta's contract file is
internally complete (not a diff). That's lowest-friction for an LLM reader.

### Pass 3 — Resolution Path

Add a banner to `specs/002-vector-memory-mcp/contracts/mcp-tools.md` enumerating the
delta contract files. Verify each delta file (003, 006, 007) is readable in
isolation. No backfill of the 002 base.

## Resolution

Pending banner addition. No code change.

**Resolved By**: inline edit (banner) when the user approves
**Resolved Date**: N/A

## Impact

- [ ] Spec updated: `specs/002-vector-memory-mcp/contracts/mcp-tools.md` — add
      "Superseded by" banner listing 003, 006, 007 delta contracts
- [ ] Delta contracts audited: confirm `specs/003-memory-server-hardening/contracts/`,
      `specs/006-ollama-fallback/contracts/`, `specs/007-bm25-keyword-fallback/contracts/`
      are each self-contained
- [ ] ADR created/updated: None
