# LOG-008: Decision Log Unbounded Growth Across Runs

**Date**: 2026-04-26
**Type**: CHALLENGE
**Status**: Open
**Raised In**: specs/010-autonomous-workflow/spec.md § /speckit.review spec gate (Phase C synthesis-judge blind spot)
**Related ADRs**: ADR-010 (stage-boundary log threshold), ADR-013 (subagent writes log directly)

---

## Description

`decisions-log.md` is appended to at every stage boundary by every subagent. A single full-pipeline run produces stage-start + stage-end + subagent-summary entries × 10 stages, plus routing decisions and any escalations. After several runs against the same feature (resumes, re-runs after revision, re-reviews after gate decisions), the file grows without bound. No retention, rotation, or summarization policy is specified.

For V1 (single-feature, often single-run), this is tolerable. For V2 (with US-3's learning loop reading checkpoint files and decision logs across multiple features and runs), the unbounded growth becomes a usability and storage concern.

## Context

Raised by synthesis-judge during Phase C of the spec gate review as a blind spot — neither Phase A reviewer addressed log retention. The judge promoted this to a deferred V2 concern recorded in this LOG.

ADR-013's amendment (subagent-writes-log-directly) does not change the growth profile; it changes who writes, not how much.

## Discussion

### Pass 1 — Initial Analysis

Three growth axes: (a) per-run length (stages × entries-per-stage), (b) re-runs of the same feature (each re-run appends), (c) cumulative across features (learning loop reads logs from multiple features).

For V1 with BLOCKING gates and no learning loop, axis (a) is bounded (~50 entries per run for full pipeline) and axes (b) and (c) are out of scope. V1 ships without retention policy.

### Pass 2 — Critical Review

Three candidate retention strategies for V2:

**Strategy A: Append-only with per-run dividers.** Each run appended after a horizontal divider with timestamp. Reader scrolls to the latest run. Simple; file grows unboundedly but readability stays acceptable up to ~10 runs.

**Strategy B: Per-run log files.** `decisions-log-2026-04-26-run-1.md`, etc. Index file lists runs. Bounded per-file size; learning loop reads index to find recent runs.

**Strategy C: Rolling window with archive.** Latest N runs in `decisions-log.md`; older runs moved to `decisions-log-archive/`. Reader sees recent activity; archive available for deeper analysis.

**Strategy D: Summarization on each new run.** Older runs collapsed into a summary entry; full text moved to archive. Most compact; risk of losing detail needed for learning loop.

### Pass 3 — Resolution Path

Defer to V2 alongside US-3. The learning-loop spec will define what reading patterns it needs; that drives the right retention strategy.

## Resolution

Deferred to V2.

**Resolved By**: V2 spec (with US-3 / learning loop)
**Resolved Date**: N/A

## Impact

- [ ] Spec updated: spec 010 notes log retention is V2 concern
- [ ] Plan updated: N/A
- [ ] ADR created/updated: TBD V2
- [ ] Tasks revised: N/A
