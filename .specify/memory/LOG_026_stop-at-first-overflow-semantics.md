# LOG-026: ADR-022 Budget Enforcement Semantics Are Ambiguous

**Date**: 2026-04-12
**Type**: UPDATE
**Status**: Resolved
**Raised In**: `memory-server/speckit_memory/server.py:165` (implementation of feature 003, task T012); surfaced by `/speckit.audit`
**Related ADRs**: ADR-022

---

## Description

ADR-022 describes budget enforcement as "greedy top-down packing: include each chunk in full if adding it would not exceed max_chars; drop it entirely if it would." The phrase "drop it entirely" is ambiguous — it could mean:

1. **Stop-at-first-overflow**: drop the chunk and stop processing entirely (what the code does — `break`)
2. **Skip-and-continue**: drop the chunk but continue checking smaller subsequent chunks

These produce different results when chunks have varying sizes.

## Context

Tasks.md T012 explicitly names "stop-at-first-overflow" as the intended behavior. Test T011b validates stop semantics with a "skipped larger before smaller" scenario. The implementation uses `break` at `server.py:165`.

ADR-022 was written before T012's explicit naming and before T011b was validated, so its language reflects the higher-level intent without specifying the branch behavior.

## Discussion

### Pass 1 — Initial Analysis

"Greedy top-down packing" typically implies a greedy algorithm that processes items in order and makes locally optimal decisions — but doesn't specify whether to stop or skip on a failed item.

### Pass 2 — Critical Review

Stop-at-first-overflow is a deliberate choice over skip-and-continue. Results are already score-ranked; a chunk that doesn't fit is likely semantically important (high score). Skipping it to fill with lower-ranked chunks could produce a misleading result set — the budget is "full" but with less relevant content.

Additionally, stop-at-first-overflow is simpler (a `break` vs. continued iteration) and predictable: callers know results are a contiguous top-N prefix of the ranked list, never a sparse subset.

### Pass 3 — Resolution Path

The decision was implicitly made during implementation. ADR-022 should be updated to clarify.

## Resolution

Stop-at-first-overflow is the correct and intentional semantics. ADR-022 amended to clarify.

**Resolved By**: ADR-022 amendment (below)
**Resolved Date**: 2026-04-12

## Impact

- [x] ADR-022 updated: Amendment History row added to clarify stop-at-first-overflow semantics
