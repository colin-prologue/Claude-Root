# LOG-018: Index Cleanup Agent — Deferred to Feature 004

**Date**: 2026-04-09
**Type**: QUESTION
**Status**: Deferred
**Raised In**: specs/003-memory-server-hardening/spec.md — scope discussion during specification
**Related ADRs**: ADR-008 (LanceDB), ADR-011 (self-init sync), ADR-012 (content-hash change detection)

---

## Description

Should the memory server include a cleanup/audit agent that inspects the index for corruption, duplicates, and stale synthetic chunks — and can optionally repair them?

## Context

Raised during 003 scoping. Feature 003 adds a write guard to `memory_store` that prevents future writes to protected on-disk paths. That closes the hole going forward. But it doesn't fix corruption that may already exist in the index from prior skill calls that mistakenly used a real ADR path as `source_file`.

The question was: should cleanup be part of 003 or a separate feature?

## Discussion

### Pass 1 — Initial Analysis

A cleanup agent would address distinct concerns from the write guard:
- Find synthetic chunks whose `source_file` matches a real on-disk path (the corruption 003 prevents going forward)
- De-duplicate chunks with identical content hashes but different IDs
- Purge stale synthetic chunks left by re-run skills (e.g., a second `/speckit.plan` run that stored a new summary without deleting the prior one)
- Optionally: report index health without mutating anything (read-only audit mode)

### Pass 2 — Critical Review

The index is young — accumulated corruption is likely low to zero. The write guard (003 P1) closes the hole going forward, making cleanup less urgent. Adding a fourth story to 003 risks exceeding the 300 LOC PR limit and muddles the feature's focus (hardening the write path vs. repairing the existing state).

Cleanup also pairs naturally with LEARN-3 from LOG-017 (session handoff skill) — both are about deliberate lifecycle management of the index. Together they form a coherent "004: index lifecycle" feature.

### Pass 3 — Resolution Path

Defer to 004. Decision made during 003 spec review.

## Resolution

Deferred to feature 004. The write guard in 003 prevents the primary corruption vector going forward. Cleanup of existing state and the broader index lifecycle tooling (handoff, de-dupe, audit) will be scoped as a distinct feature.

Suggested 004 scope:
- Read-only index health audit (report: duplicates, stale synthetics, protected-path violations)
- De-duplication of chunks with identical content
- Purge of stale synthetic chunks (e.g., from re-run skills without prior chunk deletion)
- Optional: session handoff skill that stores a "where we left off" synthetic chunk (LEARN-3, LOG-017)

**Resolved By**: Deferred to feature 004
**Resolved Date**: 2026-04-09

## Impact

- [ ] Spec updated: specs/003-memory-server-hardening/spec.md — Assumptions section references this LOG
- [ ] Plan updated: N/A — 003 not yet planned
- [ ] ADR created/updated: None
- [ ] Tasks revised: None
