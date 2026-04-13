# LOG-025: Truncation-of-Last-Resort Disabled in Summary Mode

**Date**: 2026-04-12
**Type**: UPDATE
**Status**: Resolved
**Raised In**: `memory-server/speckit_memory/server.py:167` (implementation of feature 003, task T012)
**Related ADRs**: ADR-022

---

## Description

Feature 003 introduced truncation-of-last-resort in full-content mode: if `max_chars` is set and no chunk fits, the first chunk is truncated to `max_chars` and returned with `truncated: true`. This prevents callers from receiving an empty result when any content exists.

In summary mode, this fallback is explicitly disabled. If `max_chars` is smaller than any single summary entry, the response returns empty results with `budget_exhausted: true`.

## Context

Arose during implementation of T012 (budget enforcement loop). The truncation logic at `server.py:167` has a guard: `if not packed and results and not summary_only`.

Neither the spec nor the contract documents this edge case — what happens when `summary_only=True` and `max_chars < len(json.dumps(smallest_entry))`.

## Discussion

### Pass 1 — Initial Analysis

Truncation is meaningful in full-content mode because content is a continuous string — truncating it preserves partial information. A 4000-char chunk truncated to 500 chars still contains useful text.

### Pass 2 — Critical Review

A summary entry is not a continuous string — it's `{source_file, section, score}`. Truncating the JSON serialization of a summary entry produces malformed JSON, not a useful partial result. There is no natural "truncate a summary entry" operation.

### Pass 3 — Resolution Path

The correct behavior for summary mode when no entry fits the budget is to return empty results with `budget_exhausted: true`, signaling to the caller that the budget is too small to return even one entry. The caller can then widen the budget or switch to full-content mode with a different top_k.

## Resolution

Truncation-of-last-resort is intentionally disabled in summary mode because summary entries are structured objects, not truncatable strings. The empty-results + `budget_exhausted` response is the correct signal.

**Resolved By**: inline implementation decision during feature 003
**Resolved Date**: 2026-04-12

## Impact

- [x] Contract updated: `specs/003-memory-server-hardening/contracts/memory_recall.md` — Composability section updated to reflect json.dumps measurement (ADR-024)
- [ ] Spec updated: edge case not explicitly documented in spec.md (acceptable — spec covers the happy path; this is a narrowly-scoped edge case)
- [x] ADR created: ADR-024 (summary-mode JSON serialization measurement)
