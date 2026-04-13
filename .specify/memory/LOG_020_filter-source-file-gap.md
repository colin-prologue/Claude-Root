# LOG-020: `filter_source_file` Absent from `vector_search()` — Added as FR-010

**Date**: 2026-04-09
**Type**: CHALLENGE
**Status**: Resolved
**Raised In**: specs/003-memory-server-hardening/spec.md — spec review (Phase A, devil's advocate)
**Related ADRs**: ADR-008 (LanceDB vector backend)

---

## Description

US3 (summary-only two-pass retrieval) describes a two-pass pattern where the second pass filters `memory_recall` by `source_file`. This filter parameter does not exist in the current API. `vector_search()` in `memory-server/speckit_memory/index.py` supports `filter_type`, `filter_feature`, and `filter_tags` — no `filter_source_file`.

## Context

Raised during the 003 spec review (Phase A). The devil's advocate confirmed by reading `index.py` that no such parameter exists. US3's independent test — "makes a second targeted `memory_recall` filtered by `source_file`" — was non-executable as written. The product-strategist concurred that this makes it a functional requirement gap, not just a narrative issue.

## Discussion

### Pass 1 — Initial Analysis

US3's two-pass pattern is a stated use case in the feature description and is illustrated in the independent test. If the second pass cannot filter by source_file, the pattern is incomplete. The fix requires adding `filter_source_file` as an optional parameter to `memory_recall` (and by extension to `vector_search()`).

### Pass 2 — Critical Review

The devil's advocate noted the spec text says "two-pass retrieval is a caller-side pattern" and does not enforce a retrieval protocol. The product-strategist maintained that even if the pattern is optional, the independent test is non-executable without the filter — making it a functional requirement.

The synthesis judge agreed: `filter_source_file` must be a functional requirement in the spec, not a plan-phase implementation detail.

### Pass 3 — Resolution Path

Added as FR-010 to the spec. US3 narrative updated to reference `filters: {source_file: "..."}` syntax consistent with existing filter conventions.

## Resolution

Added `filter_source_file` as FR-010 in specs/003-memory-server-hardening/spec.md. Implementation will add the parameter to `vector_search()` in `index.py` and surface it in `memory_recall` in `server.py`.

**Resolved By**: FR-010 added to spec
**Resolved Date**: 2026-04-09

## Impact

- [x] Spec updated: specs/003-memory-server-hardening/spec.md — FR-010 added, US3 narrative updated, FR-008 updated to include `filter_source_file`
- [ ] Plan updated: N/A — not yet planned
- [ ] ADR created/updated: None
- [ ] Tasks revised: None
