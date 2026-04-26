# ADR-013: Subagent Writes Decision-Log Entry Directly to Disk

**Date**: 2026-04-26
**Status**: Proposed (amended 2026-04-26 post-second-spec-review)
**Decision Made In**: specs/010-autonomous-workflow/spec.md § (post-spec-review revision); supersedes the synthesis half of ADR-010 Option B
**Related ADRs**: ADR-016 (canonical/derivative model — refines write protocol)
**Related Logs**: LOG-006 (TDD strategy), LOG-009 (stale-lock recovery)

---

## Context

ADR-010 chose stage-boundary granularity for `decisions-log.md` and made the orchestrator responsible for synthesizing the log entry from the subagent's returned structured summary. The /speckit.review spec gate surfaced a load-bearing problem with this model: the orchestrator has no independent observation of the subagent's reasoning (per ADR-009), and only thin observation of its filesystem actions. If the returned summary lies, hallucinates "stage complete," omits a failed test run, or fabricates a rationale, every downstream guarantee silently collapses — including SC-002 (no missing decisions), FR-004 (severity-based halting), and SC-005 (learning loop).

A schema for the summary (recommended by both reviewers) makes summaries legible but not trustworthy. The orchestrator still cannot verify the subagent didn't omit, downplay, or fabricate.

## Decision

The subagent writes its decision-log entry directly to `specs/[###-feature-name]/decisions-log.md` during its execution. The orchestrator reads `decisions-log.md` from disk after each stage to determine routing, status, and severity. The orchestrator never trusts a returned summary as the source of truth for routing decisions; the returned summary is metadata about the dispatch (token usage, exit reason), not the audit record.

Subagents conform to a defined log-entry schema: stage, status, timestamp, artifacts written, decisions made, alternatives considered, severity classifications, halt directive.

**Amendment (2026-04-26)**: ADR-016 refines this decision by establishing the subagent as the **canonical** writer of `decisions-log.md` and demoting orchestrator control-flow entries (stage-start, stage-skip, route, abort) to a regenerable sidecar at `specs/[###]/.run/control-flow.log`. The subagent's per-stage record is the irreplaceable witness; the orchestrator's view is reconstructible. This eliminates the two-writer concurrency problem entirely — only one writer holds `decisions-log.md` at any moment. See ADR-016 for the full canonical/derivative model.

## Alternatives Considered

### Option A: Subagent writes log entry directly *(chosen)*

Subagent appends its own entry to `decisions-log.md` during execution; orchestrator reads disk for routing.

**Pros**: Audit log is a real artifact, not a derived one. Removes the lying-summary failure class. Aligns log construction with the entity that has access to the reasoning. The orchestrator's routing logic operates on a stable on-disk artifact rather than a transient returned string.
**Cons**: Subagents must be reliable enough to write the entry before exiting; an interrupted subagent may leave a partial entry. Requires schema enforcement at the subagent contract level.

### Option B: Orchestrator synthesizes from returned summary (current ADR-010 model)

Subagent returns structured summary; orchestrator parses it and writes the log entry.

**Pros**: Single point of log-write logic. Easier to test the log-write code in isolation.
**Cons**: Orchestrator's view of stage outcome is mediated entirely by subagent honesty. A semantically-valid-but-wrong summary is accepted as truth. Cannot detect omitted decisions.

### Option C: Both — subagent writes, orchestrator validates

Subagent writes entry; orchestrator parses returned summary and cross-checks against the entry on disk; mismatch halts pipeline.

**Pros**: Belt-and-suspenders.
**Cons**: Doubles the contract surface (schema + validation rules); adds a class of false-positive halts when subagent and summary diverge for benign reasons. Violates Principle II.

## Rationale

Option A removes a silent-failure class without adding new infrastructure. The schema requirement exists in either model (Option B already needed it per S-6 of the spec review). Shifting the write responsibility to the entity with full visibility into the work done is the cleaner architecture.

Option C was rejected because the cross-check mechanism becomes its own source of bugs; a well-defined schema and disciplined subagent prompt is sufficient.

## Consequences

**Positive**: Decision log is a first-class artifact authored by the entity that has full reasoning context. Orchestrator routing operates on disk state, not transient strings. SC-002 becomes verifiable as "every stage transition appears in the on-disk log."
**Negative / Trade-offs**: Subagent contract must mandate log-entry write before exit; planning phase must specify the schema and recovery behavior when a subagent exits without writing.
**Risks**: Partial-write failures (subagent crashes after starting log entry) — **partial-write recovery protocol deferred to V2** alongside cross-session resume (see ADR-015 and ADR-016). In V1 single-session lifecycle, a partial write means the developer's main session crashed and is visible to them; recovery is manual cleanup, not an automated protocol. The "append-only writes with terminal sentinel, orchestrator detects truncation" mechanism originally sketched in this section is not implemented in V1. Schema drift across subagent versions — mitigation: schema validation on read, halt on malformed entry as semantic failure per FR-019.
**Follow-on decisions required**: Plan-phase decision on log-entry schema (fields, validation); plan-phase decision on subagent prompt structure that enforces write-before-exit. Sidecar format for orchestrator control-flow events (per ADR-016) — JSONL vs structured markdown — is a plan-phase choice.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-26 | Initial record (post-spec-review judge ruling) | Claude (synthesis-judge for spec 010) |
| 2026-04-26 | Amended post-second-spec-review: declared subagent canonical writer per ADR-016; deferred partial-write recovery protocol to V2 | Claude (synthesis-judge for spec 010 re-review) |
