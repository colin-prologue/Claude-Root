# LOG-012: JSONL Truncation Tolerance vs MUST-Coalesce on Halt/Abort

**Date**: 2026-04-26
**Type**: CHALLENGE
**Status**: Open
**Raised In**: specs/010-autonomous-workflow plan-gate review (Phase B, security-reviewer concurrency follow-up)
**Related ADRs**: ADR-016 (canonical/derivative model — MUST-coalesce amendment), ADR-020 (sidecar JSONL format)

---

## Description

ADR-020 designs the sidecar (`.run/control-flow.log`) for truncation tolerance: if the orchestrator process is killed mid-emit, readers drop the malformed last line and proceed. ADR-016 (post-revision) requires that on halt, abort, or permission-failure terminations, the orchestrator MUST append a coalesced control-flow summary to the canonical `decisions-log.md`.

These two properties pull in opposite directions when the orchestrator dies during the coalesce write itself:
- The sidecar's truncation tolerance says "a partial last line is fine; drop it." Applied to the canonical log, this is wrong — the canonical log is markdown, not JSONL, and a partial markdown section is not safely droppable by the same readers.
- The MUST-coalesce requirement says "the canonical log gets the summary on halt/abort." If the orchestrator dies after starting the summary but before completing it, the canonical log carries a truncated entry that fails FR-006 schema validation.

V1 accepts this as a known correctness-vs-resilience tradeoff. The LOG records the failure mode and the V1 mitigation (atomic-write-then-rename for the coalesced summary) so V2 can revisit if the partial-write scenario surfaces in dogfooding.

## Context

The post-plan-review amendments to ADR-016 and ADR-020 surfaced the tension: ADR-016 was strengthened from MAY-coalesce to MUST-coalesce on halt/abort/permission-failure paths (so the canonical log carries the orchestrator's reasoning at the moment a developer needs to retrigger). ADR-020 retained the JSONL truncation-tolerance property for the sidecar.

The security-reviewer's plan-gate Phase B response noted that the MUST-coalesce addition introduces a new partial-write surface on the canonical log path that ADR-013/ADR-016 had explicitly avoided in the single-writer baseline. The orchestrator becomes a writer of the canonical log at termination; if the termination is itself interrupted (signal, OOM, machine sleep), the partial write lands on the markdown artifact subagents otherwise own.

## Discussion

### Pass 1 — Initial Analysis

V1 mitigation: implement the coalesced summary append as **stage-then-rename**:
1. Read current `decisions-log.md` into a temp file in the same directory.
2. Append the coalesced summary block to the temp file.
3. `mv -f` the temp file over `decisions-log.md` (atomic on the same filesystem on macOS/Linux).

Failure modes:
- Crash before step 1: canonical log unchanged; sidecar persists with the events. Acceptable.
- Crash mid-step 2: temp file orphaned; canonical log unchanged. `run-lock.sh acquire` on next run can sweep `.run/*.tmp` and orphaned temps in the feature directory.
- Crash mid-step 3: `mv` is atomic; either old or new file is fully present. Acceptable.

This makes the canonical log resilient to coalesce-time crashes at the cost of one temp-file roundtrip per termination (~5KB read, ~6KB write — negligible).

### Pass 2 — Critical Review

The temp-file approach addresses the partial-write concern but introduces a new failure mode: a stale `.tmp` file in the feature directory after a crashed run. The fix is small (sweep on next acquire), but it's another piece of state to remember.

Alternative: **append-only with sentinel** — write the coalesced summary as a single atomic `printf`-with-sentinel and treat the sentinel's presence as the marker for completeness. Doesn't work for markdown because sections aren't single lines.

Alternative: **drop MUST-coalesce; keep MAY-coalesce**. Reverts the ADR-016 amendment. Loses the developer-facing benefit (canonical log carries the halt reasoning at the moment the developer needs to retrigger). Not chosen because the amendment is itself addressing a plan-gate finding (the audit-trail incompleteness when halt happens mid-pipeline).

### Pass 3 — V1 Decision

Ship the stage-then-rename approach. Document the residual `.tmp` cleanup as part of `run-lock.sh acquire`. Track in this LOG; revisit if dogfooding surfaces a real partial-coalesce incident.

The deeper resilience question — "what if the machine itself dies between step 2 and step 3" — has the same answer as for any local-filesystem write protocol: the canonical log is whatever was on disk at the last `fsync`. V1 does not call `fsync` explicitly; this is consistent with the rest of the project's filesystem usage and is documented as a V2-or-later concern.

## Resolution

Open (V1 mitigation accepted; V2 revisit conditional on dogfooding).

V1 ships:
- Coalesced summary append via stage-then-rename idiom.
- `.run/*.tmp` sweep in `run-lock.sh acquire`.
- This LOG as the tracking record.

V2 reconsiders if a partial-coalesce incident is observed during the SC-008 30-day floor.

**Resolved By**: V1 mitigation in place; V2 follow-on tracked here.
**Resolved Date**: N/A

## Impact

- [X] Plan updated: specs/010-autonomous-workflow/plan.md (Decision Records table includes this LOG)
- [X] ADR created/updated: ADR-016 amended (MUST-coalesce); ADR-020 unchanged (sidecar format remains JSONL with truncation tolerance)
- [ ] Tasks revised: V1 task list adds (a) stage-then-rename in the coalesce path, (b) `.tmp` sweep in `run-lock.sh acquire` (covered by `run-common.sh` introduction)
