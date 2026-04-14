# ADR-030: Cleanup Detection Strategy — Crawl-Based with Direct-Exists Safety Check

**Date**: 2026-04-13
**Status**: Accepted
**Decision Made In**: specs/005-sync-stale-cleanup/plan.md § Technical Context
**Related Logs**: LOG-028

---

## Context

Feature 005 adds a stale chunk cleanup pass to `run_sync`. The pass must identify
manifest entries whose source files no longer exist on disk, then delete those chunks.

Two approaches exist for detecting "file is gone":

1. **Crawl-based**: check whether the path appears in `crawl_files()` results.
   Missing from crawl = treated as deleted.
2. **Direct-exists**: call `Path(repo_root / rel).exists()` for each manifest entry.
   Returns False = treated as deleted.

The spec edge case requires conservative behavior on filesystem errors: if the
existence check itself fails (permission error, network path unavailable), the
cleanup pass must treat the file as present and NOT delete its chunks.

`crawl_files()` uses `glob.glob` + `Path.is_file()`. A file with a permission error
during globbing is silently absent from the crawl results — this treats it as deleted,
violating the conservative rule. A direct `Path.exists()` check with try/except can
be wrapped to explicitly catch `OSError` and skip the entry.

Additionally, `crawl_files()` only returns files matching configured index glob patterns.
A file that exists on disk but falls outside the current patterns would be treated as
deleted by the crawl-based approach — its chunks would be cleaned up. This is the
correct semantic: if a file is removed from the index configuration, its stale chunks
should be cleaned up.

## Decision

Use the existing crawl-based approach as the primary detection mechanism (preserving
the "outside configured patterns = deleted" semantic), augmented with a direct
`Path.exists()` safety check as a conservative secondary filter in the cleanup loop.

Before deleting chunks for an entry that the crawl did not find, the cleanup loop
calls `(repo_root / rel).exists()` wrapped in `try/except OSError`. If the file
is confirmed to exist (or the check raises an OSError), the entry is skipped — no
deletion occurs. Only entries where `exists()` returns `False` without error proceed
to chunk deletion.

## Alternatives Considered

### Option A: Crawl-based with direct-exists safety check *(chosen)*

Use `find_deleted(manifest, all_files, repo_root)` to identify candidates, then
re-verify each candidate with `(repo_root / rel).exists()` in the cleanup loop.

**Pros**: Handles the "outside configured patterns" case correctly. Conservative on
filesystem errors. Minimal change to existing logic.
**Cons**: Two filesystem operations per stale candidate (crawl miss + exists check).
In practice candidates are rare (0 on clean index), so this is negligible.

### Option B: Direct-exists only — drop crawl-based detection

Replace `find_deleted()` with a loop over manifest entries that calls `Path.exists()`
directly. Skip crawl entirely for the cleanup pass.

**Pros**: Single, explicit check per entry. Conservative by default (try/except).
**Cons**: Loses the "outside configured patterns = deleted" semantic. A file removed
from index patterns but still on disk would never be cleaned up. Requires callers to
understand this semantic difference.

### Option C: Crawl-based only — no direct-exists check

Keep the current `find_deleted()` as-is, skipping the secondary exists check.

**Pros**: Simplest — no change.
**Cons**: Violates the spec's conservative rule for filesystem errors. A file
inaccessible during glob (permission error) is silently treated as deleted.

## Rationale

Option A is the right balance: it preserves a useful invariant (out-of-patterns entries
are cleaned up), adds explicit conservatism for the error case, and avoids changing the
`find_deleted` return contract. The double-check cost is zero for the common case (clean
index, no stale candidates). Option B loses the patterns-driven cleanup semantic. Option C
violates an explicit spec requirement.

## Consequences

**Positive**: Cleanup is conservative on filesystem errors. Configured-patterns
semantic is preserved. No change to existing `find_deleted` function signature.
**Negative / Trade-offs**: Two filesystem operations per stale candidate. Negligible
in practice.
**Risks**: If a file has a permission error during glob AND a permission error
during the direct-exists check, the entry is correctly skipped (conservative). No
data loss risk.
**Follow-on decisions required**: None.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-13 | Initial record | Claude (/speckit.plan) |
