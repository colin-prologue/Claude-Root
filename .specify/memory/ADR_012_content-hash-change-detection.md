# ADR-012: SHA-256 Content Hash for Sync Change Detection

**Date**: 2026-04-08
**Status**: Accepted
**Decision Made In**: memory-server/speckit_memory/sync.py:215-223 (detected during code review)
**Related Logs**: None

---

## Context

The incremental sync path (`memory_sync`, `run_sync`) needs to determine which source files have changed since the last index. The original implementation (FR-005, data-model.md) used file modification time (mtime) stored in the manifest. During code review it was identified that mtime is reset by git operations — `git checkout`, `git pull`, and `git reset` all update mtimes to the current timestamp without changing file content. After any branch switch or pull, every indexed file appears stale, triggering unnecessary re-embedding of unchanged content.

## Decision

We will use SHA-256 content hash of file bytes as the change detection key in the manifest, replacing mtime. The manifest format is versioned ("1" → "2") to allow automatic migration on first sync.

## Alternatives Considered

### Option A: SHA-256 content hash *(chosen)*

`hashlib.sha256(path.read_bytes()).hexdigest()` stored as `hash` in each manifest entry.

**Pros**: Stable across all git operations; content-addressed (two files with identical content hash identically); no clock dependency
**Cons**: Slightly more expensive per file than `stat()` (must read file bytes); hash doesn't capture mtime-based metadata the caller might want separately

### Option B: mtime (original)

ISO-formatted `path.stat().st_mtime` stored as `mtime` in each manifest entry.

**Pros**: Zero file-read cost (stat only); matches the original spec (FR-005)
**Cons**: Reset to current time by `git checkout`, `git pull`, `git reset --hard`, and file copy operations — causes all files to appear stale after any git operation, triggering full re-embedding of unchanged content

### Option C: mtime + size composite

Combine mtime with file size as a faster approximation.

**Pros**: Still cheap; size guards against cases where mtime is wrong
**Cons**: Same git-operation fragility as mtime alone; size collision possible (e.g. one byte changed for one byte removed)

## Rationale

mtime is an unreliable change signal for a version-controlled corpus. A developer who runs `git checkout main && git checkout feature` should not pay the cost of re-embedding every file. The spec was written before this failure mode was considered. SHA-256 is stdlib, adds negligible overhead for markdown-sized files (~1-10KB), and eliminates the entire class of spurious-stale-on-checkout bugs.

The manifest version bump ("1" → "2") provides a clean migration path: v1 manifests trigger a one-time full re-index, after which v2 hash-based tracking takes over.

## Consequences

**Positive**: No unnecessary re-embedding after git operations; deterministic behavior regardless of when the checkout happened
**Negative / Trade-offs**: Every sync call reads each file once to hash it (even if skipping re-embedding); previously stored mtime is abandoned, requiring one full re-index to migrate
**Risks**: Hash collision is theoretically possible but negligible (SHA-256, markdown source files)
**Follow-on decisions required**: FR-005 in spec.md and the manifest schema in data-model.md must be updated to reflect hash-based detection (see LOG-015 for tracking)

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-08 | Initial record — decision detected in code during consistency audit | speckit.audit |
