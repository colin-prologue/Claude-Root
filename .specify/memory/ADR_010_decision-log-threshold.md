# ADR-010: Stage-Boundary Threshold for Decision-Log Entries

**Date**: 2026-04-25
**Status**: Accepted (granularity); amended by ADR-013 (write-responsibility shifted from orchestrator to subagent)
**Decision Made In**: specs/010-autonomous-workflow/spec.md § Clarifications (Q3)
**Related Logs**: None

---

## Context

Spec 010 introduces a `decisions-log.md` artifact intended as the audit trail and learning surface for autonomous pipeline runs. The original FR-005 stated "every autonomous decision" must be logged — but every model action is in some sense a decision. Without a bounding threshold, the log becomes either noise (every micro-choice) or sparse (only branches), undermining its purpose.

This decision interacts with ADR-009: because stages run in fresh subagents, the orchestrator cannot observe a stage's internal reasoning anyway — only the structured summary it returns. The threshold must align with what the orchestrator can actually observe.

## Decision

The decision log records entries at stage boundaries only: stage start, stage end, stage skip, severity-based escalation, routing choice, and abort trigger. Each subagent's returned structured summary is appended as the per-stage record. Per-stage internal reasoning is captured implicitly via the summary; it is not surfaced as separate log entries.

## Alternatives Considered

### Option A: Verbose — every model judgment

Subagents surface their full reasoning trace; every judgment is a log entry.

**Pros**: Maximum auditability.
**Cons**: Signal buried in noise; conflicts with the subagent execution model (ADR-009) where reasoning is invisible to the orchestrator; log too long to read; fails the SC-005 purpose of identifying bad judgment calls.

### Option B: Stage-boundary only *(chosen)*

Log control transitions plus per-stage subagent summaries.

**Pros**: Readable at human speed; aligns with what the orchestrator can actually observe under ADR-009; signal density supports the SC-005 learning use case.
**Cons**: Within-stage decisions are only visible through the subagent's summary — if the summary omits something, it's lost.

### Option C: Branching only

Log only moments where the orchestrator picked one path over another.

**Pros**: Maximally sparse; only the most consequential choices.
**Cons**: Loses linear-progression context; cannot reconstruct what each stage did, only what was branched.

### Option D: Two-tier (sparse + verbose trace)

`decisions-log.md` for branches plus `trace.md` with everything.

**Pros**: Reader picks the level.
**Cons**: Two artifacts to maintain; verbose tier suffers Option A's drawbacks; doubles spec surface.

## Rationale

Option B's threshold matches the boundary of orchestrator observability under the subagent execution model — the orchestrator sees stage starts, stage ends, and structured summaries. Logging at finer granularity would require the orchestrator to fabricate observations it cannot make. Logging at coarser granularity (Option C) loses the per-stage record that makes the log useful for retrospective analysis.

## Consequences

**Positive**: Log is readable at human speed; structurally aligned with the execution model; serves both SC-002 (no missing decisions) and SC-005 (learning artifact for guardrails).
**Negative / Trade-offs**: Within-stage reasoning relies entirely on subagent summary quality; a subagent that omits a critical judgment from its summary leaves no log trace.
**Risks**: Subagent summary quality variance directly affects log usefulness. Mitigation: the structured-summary contract for subagents (defined in planning) must mandate fields covering decisions made, alternatives rejected, and confidence signals.
**Follow-on decisions required**: Planning-phase decision on the structured-summary schema for subagents; planning-phase decision on log entry schema (timestamps, stage references, decision type taxonomy).

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-25 | Initial record | Claude (clarification session for spec 010) |
| 2026-04-26 | Amended by ADR-013: log-write responsibility shifts from orchestrator (synthesizing returned summary) to subagent (writing entry directly to disk during execution). Stage-boundary granularity preserved. | Claude (synthesis-judge for spec 010 review) |
