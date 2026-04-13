# ADR-023: Delete Guard Path Resolution via `_repo_root()` Anchor

**Date**: 2026-04-09
**Status**: Accepted
**Decision Made In**: specs/003-memory-server-hardening/plan.md § Phase 0 Research
**Related Logs**: None

---

## Context

Feature 003 adds a filesystem presence check to `memory_delete`: if the provided `source_file`
resolves to a path that exists on disk, the delete is rejected (FR-009). The implementation must
decide how to resolve the `source_file` string to a filesystem path for the existence check.

This is closely related to ADR-019 (whitelist write guard in `memory_store`), which uses the
`_repo_root()` helper to anchor relative paths. For consistency and to avoid divergence between
the two guards, the delete guard should use the same resolution strategy.

## Decision

The `memory_delete` filesystem existence check resolves `source_file` relative to `_repo_root()`,
matching the path resolution strategy already in `memory_store`. If `Path(_repo_root() / source_file).exists()`
returns True, the delete is rejected. If the file no longer exists on disk (orphaned chunk, deleted
file), the guard does not fire and the delete proceeds.

## Alternatives Considered

### Option A: Resolve via `_repo_root()` *(chosen)*

`Path(_repo_root() / source_file).exists()`

**Pros**: Identical resolution logic across both guards. A given `source_file` string maps to the
same filesystem path in `memory_store` and `memory_delete`, eliminating any guard-bypass via path
representation differences. No new helper function needed.
**Cons**: Only catches relative paths from repo root. An absolute `source_file` value would bypass
the check. Accepted — the spec explicitly scopes the threat model to accidental misuse by skills
following the memory convention (which always uses relative paths or `"synthetic"`).

### Option B: `Path(source_file).resolve()` (absolute resolution)

Resolve to an absolute path regardless of working directory.

**Pros**: Works for absolute paths.
**Cons**: Working directory at server startup is not guaranteed to be the repo root. Would differ
from `memory_store`'s resolution, creating inconsistency between the two guards. Rejected.

### Option C: Block all path-based deletes unconditionally

Always reject `memory_delete(source_file=...)` regardless of filesystem state.

**Pros**: Maximally protective.
**Cons**: Would prevent deletion of orphaned synthetic chunks whose `source_file` is not `"synthetic"`
(legacy data created before ADR-019 enforcement). Overly restrictive for the accidental-misuse
threat model. Callers legitimately need to delete stale synthetic chunks by source_file. Rejected.

## Rationale

Consistency between the two guards (write guard and delete guard) is the primary driver. FR-009
specifies the `_repo_root()` anchor explicitly: "Path comparison MUST resolve paths relative to
the repository root using the same `_repo_root()` anchor as `memory_store`." The orphaned-chunk
exception is intentional — it allows cleanup of legacy data without requiring id-based lookups.

## Consequences

**Positive**: Single path-resolution strategy across both mutation guards. Easy to test: existence
check is a simple filesystem call. Orphaned chunks remain deletable.
**Negative / Trade-offs**: Absolute `source_file` values (unusual, against convention) bypass the
guard. Accepted per spec Assumptions ("symlink/relative-path normalization is not in scope").
**Risks**: Low. The accidental-misuse threat model does not include adversarial path manipulation.
**Follow-on decisions required**: None.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-09 | Initial record | /speckit.plan |
