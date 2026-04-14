# LOG-029: LOG-018 Unresolved Concerns — De-dupe and Synthetic Purge

**Date**: 2026-04-13
**Type**: QUESTION
**Status**: Deferred
**Raised In**: specs/005-sync-stale-cleanup/spec.md — adversarial spec review (LOG-018-misrep finding)
**Related ADRs**: None

---

## Description

LOG-018 (deferred from feature 003) described three cleanup concerns for the speckit-memory index:

1. **Stale file-synced chunks** — chunks from files that have been deleted/renamed/moved. ✅ Addressed by feature 005.
2. **De-duplication** — chunks with identical content hashes but different IDs. ❌ Not yet addressed.
3. **Synthetic chunk purge** — stale synthetic chunks left by re-run skills (e.g., a second `/speckit.plan` that stored a new summary without deleting the prior one). ❌ Not yet addressed.

Feature 005 partially resolves LOG-018 (concern 1 only). The feature 005 spec originally marked LOG-018 as "Deferred (resolved here)" — this was corrected during review to "Partially resolved." This LOG tracks the two remaining concerns.

## Context

LOG-018 suggested these three concerns form a coherent "index lifecycle" feature. Feature 005 extracts only the stale file cleanup concern because it is the most impactful and least complex. De-duplication and synthetic purge involve different mechanisms and different risk profiles.

De-duplication: requires identifying chunks with matching content across potentially different source files. Risk is LOW (duplicates waste index space but do not produce incorrect results).

Synthetic chunk purge: requires tracking which synthetic chunks are "current" and which are stale. The memory convention (memory-convention.md) specifies that skills should delete prior summary chunks before storing new ones, but this is unenforced. Risk is MEDIUM — stale summaries from prior plan/review runs can influence recall results.

## Discussion

### Pass 1 — Initial Analysis

**De-duplication**: Could be addressed by adding a unique constraint on content hash during index write, or by a periodic de-dup scan. The former changes the indexing behavior; the latter is a cleanup pass. Neither is urgent because duplicates don't corrupt results — they inflate them.

**Synthetic chunk purge**: The root cause is that skills don't reliably clean up prior synthetic chunks. Two paths forward: (a) enforcement at `memory_store` time (reject a second store for the same synthetic key), or (b) periodic purge of synthetic chunks older than N days / superseded by a newer chunk from the same skill. The memory convention already describes the expected behavior; this is about adding enforcement or tooling.

### Pass 2 — Critical Review

Both concerns are lower priority than stale file cleanup. Neither causes data loss. Both can be addressed in a future "index health" feature that builds on the cleanup infrastructure from feature 005.

## Resolution

Deferred to a future feature. Both concerns remain open after feature 005 ships.

**Resolved By**: Deferred
**Resolved Date**: N/A

## Impact

- [x] Spec updated: specs/005-sync-stale-cleanup/spec.md — Decision Records table now references LOG-029
- [ ] Plan updated: N/A
- [ ] ADR created/updated: None
- [ ] Tasks revised: None
