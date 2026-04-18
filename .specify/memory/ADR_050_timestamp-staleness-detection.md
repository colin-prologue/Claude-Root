# ADR-050: Timestamp-Based Staleness Detection via `_check_staleness()` in `memory_recall`

**Date**: 2026-04-17
**Status**: Accepted
**Decision Made In**: specs/008-auto-sync-staleness/plan.md § Phase 0 Research
**Related Logs**: LOG-049

---

## Context

`_ensure_init()` (ADR-011) runs a sync exactly once per process lifetime, caching a `_first_call_done` flag. This means any ADRs or spec files created after the initial sync are invisible to `memory_recall` until the server process restarts or `memory_sync()` is called manually. In practice, a developer writing several new ADRs mid-session and then invoking a speckit skill will receive stale recall results silently — no error, no warning, just missing context.

LOG-049 identified this as the root cause of the April 9–17 drift where 37 files went unindexed and proposed two detection strategies: file-count delta (compare crawled file count against manifest entry count) and timestamp delta (compare current time against `last_sync_ts` in the manifest).

## Decision

We will use timestamp-based staleness detection: `memory_recall()` calls `_check_staleness()` on every invocation, before the `summary_only` gate. `_check_staleness()` compares `time.time()` against a `last_sync_ts` field written to the manifest on each successful sync completion. If the elapsed time exceeds `MEMORY_STALENESS_THRESHOLD` (default 3600s), `_first_call_done` is reset to `False` so the next `_ensure_init()` call triggers incremental re-sync. A threshold of 0 disables the check entirely. Placing the check in `memory_recall()` (not `_ensure_init()`) ensures the `summary_only=True` path also triggers staleness detection (H2 fix from task-gate review).

## Alternatives Considered

### Option A: Timestamp delta *(chosen)*

Check `time.time() - manifest.get("last_sync_ts", 0) > threshold`. `_check_staleness()` loads `manifest.json` from disk on each `memory_recall` call — a sub-millisecond local read that does not constitute measurable latency against SC-002. FR-007 explicitly permits this read ("no new file I/O *beyond reading the manifest*"). A missing `last_sync_ts` (pre-008 manifests) evaluates as stale (0 timestamp), which is safe.

**Pros**: Zero filesystem overhead per call; no false positives from file deletions; trivially configurable; single field in existing JSON document
**Cons**: Does not detect staleness faster than the configured window — a new ADR created 1 minute after a sync will not be indexed for up to 59 more minutes (at default threshold)

### Option B: File-count delta

Check `len(crawl_files()) - len(manifest["entries"]) >= threshold_count`. Triggers immediately when files are added.

**Pros**: More sensitive — detects additions within one recall call
**Cons**: Requires a glob scan (~1ms) on every `_ensure_init` call; produces false positives when files are deleted (count drops); the sensitivity is misleading — recall is still semantically stale between sync completion and next recall call regardless

### Option C: Background async re-sync

Trigger sync in a background thread; return stale results immediately while sync runs.

**Pros**: Zero latency impact on the first post-staleness recall
**Cons**: Adds thread lifecycle complexity; results can be stale while sync is in-flight with no signaling; deferred per LOG-049 design notes

## Rationale

File-count delta was rejected because the per-call glob scan adds overhead to every recall (hot path), and the false-positive problem on deletions complicates the trigger logic. The 1-hour default window is sufficient for the typical speckit workflow — a developer does not usually run back-to-back skill calls within the same minute as writing new ADRs. If the window is too large for a given project, `MEMORY_STALENESS_THRESHOLD` can be reduced. Option C is the right long-term solution but is deferred due to complexity.

## Consequences

**Positive**: Index self-heals after each staleness window without any manual action; zero per-call overhead when index is fresh; configurable and disableable
**Negative / Trade-offs**: First recall after threshold crossed may be slower (sync runs synchronously on the recall path); new files are not indexed until the next window boundary
**Risks**: If sync takes longer than expected (large corpus, slow Ollama), the first post-staleness recall blocks for the full sync duration. Mitigation: the window is 1 hour by default, so this occurs at most once per hour
**Follow-on decisions required**: ADR-011 must be amended to document the new `last_sync_ts` write condition and multi-fire trigger behavior

## summary_only Carve-out (LOG-053)

`_check_staleness()` is called on every `memory_recall` invocation including `summary_only=True` calls. When staleness is detected on a `summary_only` call, `_first_call_done` is reset but `_ensure_init()` is NOT called — the actual `run_sync` is deferred to the next non-`summary_only` call. This is intentional: `summary_only` was designed to be Ollama-free (ADR-037); running `run_sync` inline would embed files and break that guarantee. Consequence: a process that only ever issues `summary_only` calls will detect staleness repeatedly but never self-heal. This is an accepted limitation documented in LOG-053. An INFO log is emitted when staleness is detected ("re-sync scheduled on next embedding call") so the operator has a signal.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-17 | Initial record | speckit.plan |
| 2026-04-18 | Architecture revised: staleness check moved from `_ensure_init()` to `memory_recall()` via `_check_staleness()` helper to fix `summary_only` staleness gap (H2, task-gate review). ADR title and Decision body updated. | speckit.analyze |
| 2026-04-18 | Fixed "no additional I/O" prose to match FR-007 wording; added summary_only carve-out section (LOG-053); added INFO log on staleness trigger. Code review findings S-2, S-3. | speckit.codereview |
