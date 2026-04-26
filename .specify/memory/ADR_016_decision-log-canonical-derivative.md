# ADR-016: Decision-Log Canonical/Derivative Model

**Date**: 2026-04-26
**Status**: Proposed
**Decision Made In**: specs/010-autonomous-workflow/spec.md § (post-second-spec-review revision); refines and amends ADR-013
**Related Logs**: LOG-009 (stale-lock recovery)

---

## Context

ADR-013 inverted the audit-trail model so that subagents write decision-log entries directly to disk instead of returning summaries the orchestrator parses. The second spec-gate review (re-review post-REVISE) raised a follow-on question: if both the subagent (per-stage record) and the orchestrator (control-flow entries — stage-start, stage-skip, route, abort) append to the same `decisions-log.md` from different processes, what is the write protocol? Naive co-equal append-only writes need a locking, atomic-append, or terminal-sentinel format that the spec did not define. The Phase B reviewer recommended a new ADR to specify the protocol.

The reframe surfaced by the consultation: **the two writers are not co-equal.** The subagent's per-stage record is the irreplaceable witness — it captures reasoning, alternatives considered, decisions made, halt directive — content that exists nowhere else. The orchestrator's control-flow entries (which stage started, which was skipped, which was aborted) are derivable from artifact state, git history, file mtimes, and the subagent records themselves.

When two writers have asymmetric durability — one canonical, one derivative — the canonical writer should own the artifact; the derivative writer's contribution should be regenerable, not authored.

## Decision

**The subagent's per-stage record is the canonical content of `decisions-log.md`.** The orchestrator does not append directly; it maintains an in-memory or sidecar log of control-flow events during the run, and at clean termination either (a) appends a single coalesced control-flow summary to the log, or (b) writes its events to a separate `specs/[###]/.run/control-flow.log` that is treated as a regenerable cache.

This eliminates the two-writer concurrency problem. Within a run, only the dispatched subagent writes to `decisions-log.md`. The orchestrator's role is to dispatch, read, route, and (at termination) append a closing summary if needed.

V1 implementation:
- Subagent writes its per-stage record to `decisions-log.md` before exit. This is the only canonical write during stage execution.
- Orchestrator records control-flow events (stage-start, stage-skip-criterion, routing-choice, abort-reason) to a sidecar at `specs/[###]/.run/control-flow.log` during the run.
- On clean termination, the orchestrator appends a single summary entry to `decisions-log.md` consolidating its sidecar events. If the run is interrupted, the sidecar persists at `.run/control-flow.log` and can be reviewed; the subagent records remain authoritative.

This protocol is locking-free: only one writer holds `decisions-log.md` at any given moment (the active subagent during dispatch; the orchestrator only at termination, when no subagent is running).

## Alternatives Considered

### Option A: Two co-equal writers with locking + terminal-sentinel protocol

Both subagent and orchestrator append concurrently; protocol enforces atomic-append with terminal sentinel; orchestrator detects truncation and re-runs.

**Pros**: Single artifact; orchestrator entries are first-class.
**Cons**: Invents a non-trivial concurrent-write protocol; partial-write recovery is its own ADR (deferred to V2 per spec-review F-07); higher implementation surface; violates the durable-store-first asymmetry.

### Option B: Canonical/derivative split *(chosen)*

Subagent is canonical writer of `decisions-log.md`; orchestrator writes to a sidecar derived cache; orchestrator appends a coalesced summary only at clean termination.

**Pros**: No concurrent-write protocol needed (single writer at a time). Canonical content is the irreplaceable witness; cache is regenerable. Aligns with the durable-store-first principle: write the canonical store first, treat the derivative as recoverable. Smallest implementation surface for V1.
**Cons**: Two files to read for a complete picture (log + sidecar) until termination. Sidecar in `.run/` directory means decision log is "incomplete" until termination — but all canonical content is present from the start; the sidecar only adds redundant control-flow legibility.

### Option C: Subagent-only writes; orchestrator entries omitted

Drop orchestrator-authored log entries entirely; rely on subagent records and on-disk artifacts to reconstruct control flow.

**Pros**: Smallest surface possible.
**Cons**: Loses the orchestrator's perspective on routing decisions (e.g., "skipped clarify because no ambiguities") which are part of the audit trail's value. The reasoning for a skip is the orchestrator's, not the subagent's.

## Rationale

Option B respects the actual durability asymmetry: subagent records cannot be reconstructed (they require the subagent's reasoning context); orchestrator records can be reconstructed from artifact state and the canonical log. Treating them as co-equal would impose locking complexity to protect a property (orchestrator log durability) that doesn't need to hold.

A regenerable cache is by definition allowed to fail — if the sidecar is corrupted, the orchestrator regenerates control-flow inference from disk state. The canonical record is the load-bearing artifact and it has exactly one writer.

Option A's terminal-sentinel protocol becomes appropriate only when the system gains cross-session resume requirements (V2). At that point, the sidecar may be promoted to canonical-on-disk-from-the-start; partial-write detection is then a real concern. ADR-013's partial-write recovery protocol is therefore deferred to V2 alongside cross-session resume.

## Consequences

**Positive**: Eliminates the two-writer concurrent-write problem entirely in V1. Simplifies plan-phase work (no locking protocol to specify). Aligns with durable-store-first asymmetry. Allows partial-write recovery to defer to V2.
**Negative / Trade-offs**: A reader inspecting the log mid-run sees subagent records but not orchestrator control-flow events; the sidecar must be read separately. This is acceptable for V1 because mid-run inspection is an edge use case; the developer is BLOCKING-paused and can read both files.
**Risks**: Sidecar file corruption between stages (unlikely — single-writer, append-only) — mitigation: orchestrator regenerates from artifact mtimes + subagent records. Future V2 cross-session resume must reconcile: if the orchestrator session ends mid-run, the sidecar persists; resume reads both canonical log and sidecar to reconstruct state.
**Follow-on decisions required**: Plan-phase decision on sidecar format (JSONL vs structured markdown). V2 ADR for promoting sidecar to canonical-on-disk if cross-session resume requires it (then partial-write protocol becomes relevant).

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-26 | Initial record (post-second-spec-review revision; oracle-sharpened canonical/derivative reframe) | Claude (synthesis-judge for spec 010 re-review) |
