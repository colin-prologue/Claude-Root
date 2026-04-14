# ADR-027: Scoped Sync Excludes Stale Chunk Cleanup

**Date**: 2026-04-13
**Status**: Accepted
**Decision Made In**: specs/005-sync-stale-cleanup/spec.md — review gate finding DA-01
**Related Logs**: LOG-028

---

## Context

Feature 005 adds a stale chunk cleanup pass to `memory_sync`. The cleanup pass iterates manifest entries, checks each path against the filesystem, and deletes chunks whose source file no longer exists. The pass runs before the add/update pass.

`memory_sync` already accepts a `paths` parameter that scopes the sync to a specific subset of files. During spec review (DA-01, 95% confidence), it was discovered that `find_deleted` — the function that identifies stale manifest entries — compares the full manifest against the `all_files` list. When `paths` filters `all_files` down to one or two files, `find_deleted` treats every other manifest entry as deleted. Running cleanup in this context would purge the entire index except for the scoped files — a data-destruction bug.

## Decision

The cleanup pass MUST be skipped when `memory_sync` is called with a non-null `paths` parameter. Scoped syncs do not trigger stale chunk cleanup. Cleanup only runs during full (unscoped) syncs.

## Alternatives Considered

### Option A: Skip cleanup on scoped syncs *(chosen)*

When `paths` is non-null, skip the cleanup pass entirely. The add/update pass runs as normal on the scoped files.

**Pros**: Simple, safe, predictable. No risk of mass deletion. Easy to specify and test.
**Cons**: A user who deletes a file and then runs a scoped sync does not get cleanup for the deleted file. They must run a full sync to trigger cleanup.

### Option B: Scope cleanup to the paths subtree

Run cleanup, but only consider manifest entries whose paths fall within the `paths` filter.

**Pros**: More complete — cleanup covers the scoped files.
**Cons**: Requires `find_deleted` to understand the `paths` scope semantics, which it does not today. Adds complexity to a correctness-critical function. The benefit (cleaning up exactly those files) is marginal — a full sync will clean them anyway.

### Option C: Fix `find_deleted` to accept a scoped manifest view

Pass only the relevant manifest entries to `find_deleted` when `paths` is specified.

**Pros**: No behavioral change for callers — cleanup always runs.
**Cons**: Callers are unaware that scoped cleanup has different semantics from full cleanup. The `paths` filter is path-prefix based; it is not always clear which manifest entries "belong" to a given paths filter. Risk of subtle correctness bugs.

## Rationale

Option A is the right default for this feature. The `paths` parameter is designed for targeted re-indexing of specific files (e.g., after a local edit), not for lifecycle management of the full index. Cleanup is a full-index operation by nature — it validates the entire manifest against the filesystem. Mixing scoped add/update semantics with full-manifest cleanup semantics in the same call creates a footgun. Option A keeps the two operations cleanly separated.

Option B can be added later if users find they need cleanup on partial syncs. The cost of deferring it is low (they run a full sync). The cost of getting Option B wrong is data loss.

## Consequences

**Positive**: Scoped syncs are safe regardless of cleanup logic. The `paths` parameter behavior is unchanged.
**Negative / Trade-offs**: Cleanup does not run on scoped syncs. Users who frequently use `paths` must occasionally run a full sync to clean up deleted files.
**Risks**: Users who exclusively use scoped syncs and never run full syncs will accumulate stale chunks indefinitely. This is an accepted trade-off — full sync is the intended maintenance operation.
**Follow-on decisions required**: None.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-13 | Initial record | Claude (spec review DA-01) |
