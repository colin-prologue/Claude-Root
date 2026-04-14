# LOG-028: Orphaned Chunks from Non-Atomic Cleanup

**Date**: 2026-04-13
**Type**: CHALLENGE
**Status**: Open
**Raised In**: specs/005-sync-stale-cleanup/spec.md — adversarial spec review (DA-03, DA-05)
**Related ADRs**: ADR-008 (LanceDB), ADR-012 (content-hash change detection)

---

## Description

The stale chunk cleanup design in feature 005 is manifest-driven: it iterates manifest entries, checks each path against the filesystem, and deletes chunks for missing files. This design has two structural blind spots:

1. **Orphaned chunks**: If the cleanup pass (or any prior sync) crashes after deleting a manifest entry but before deleting the corresponding DB chunks (or vice versa), chunks exist in the DB with no manifest record. These orphans are permanently invisible to manifest-driven cleanup. They persist in the index indefinitely and pollute recall results for files that no longer exist — directly violating SC-001.

2. **Non-atomic manifest/DB operations**: Manifest removal (FR-005) and chunk deletion (FR-004) are not atomic. If the process crashes between the two, the system is in an inconsistent state: the manifest says the file is gone, but the chunks are still in the DB (or the manifest still references a file whose chunks were already deleted). The next sync may double-count deletions or miss them.

## Context

Raised during adversarial review of the feature 005 spec (DA-03: HIGH, DA-05: MEDIUM). The spec acknowledges that "chunks whose source_file does not appear in the manifest are out of scope" but does not create a tracking entry for this known gap.

The manifest-driven cleanup approach (iterating manifest entries) was chosen for simplicity. An alternative is DB-driven cleanup (querying `SELECT DISTINCT source_file FROM chunks WHERE source_file != 'synthetic'`), which would catch orphans the manifest has lost track of. This was explicitly considered and deferred in feature 005 scope.

## Discussion

### Pass 1 — Initial Analysis

The orphan scenario arises from non-atomic writes. LanceDB does not offer multi-operation transactions. Each of the following is a separate write:
- Delete chunks from the LanceDB table (FR-004)
- Remove the manifest entry and save the manifest JSON (FR-005)

A crash between these two operations creates a half-deleted state. Depending on which operation completed:
- Chunks deleted but manifest not updated: next sync re-indexes the file if it still exists (benign), or leaves no record (if file was also deleted, orphan is avoided)
- Manifest updated but chunks not deleted: orphan — chunks with no manifest record, invisible to future cleanup

The second case (manifest-first, then crash before DB delete) is the dangerous scenario.

### Pass 2 — Critical Review

The likelihood of this failure mode in practice is low for a solo developer tool. The cleanup and manifest save happen in sequence without external I/O between them. Crash probability during a local filesystem operation is minimal.

However, the long-term consequence is permanent pollution of recall results with no detection or recovery path. This is a silent correctness failure, not a visible error. The only current recovery is a full re-index (`full=True`), which re-reads all source files from disk.

A DB-driven cleanup approach (query DB for all non-synthetic source_file values, check each against disk) would eliminate the orphan blind spot with ~5 additional lines of code. It was not chosen for feature 005 because it expands scope and adds complexity. But it remains a viable future mitigation.

### Pass 3 — Resolution Path

Deferred to a future feature. For feature 005, the cleanup is designed to handle the common case (file deleted, manifest has record, DB has chunks — all three in sync) and not the crash-recovery case. A `full=True` sync rebuild remains the recovery path for inconsistent state.

## Resolution

Deferred. Manifest-driven cleanup is accepted as the scope of feature 005. Orphaned chunk detection and recovery are not in scope.

**Resolved By**: Deferred — explicit scope decision in feature 005 spec
**Resolved Date**: N/A (open until addressed by a future feature)

## Impact

- [x] Spec updated: specs/005-sync-stale-cleanup/spec.md — Assumptions section acknowledges orphaned chunks out of scope; Decision Records table references LOG-028
- [ ] Plan updated: N/A — not yet planned
- [ ] ADR created/updated: None
- [ ] Tasks revised: None
