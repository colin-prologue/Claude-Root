# ADR-009: Subagent-Per-Stage Execution Model

**Date**: 2026-04-25
**Status**: Accepted
**Decision Made In**: specs/010-autonomous-workflow/spec.md § Clarifications (Q2)
**Related Logs**: LOG-004

---

## Context

The orchestrator introduced by spec 010 must run up to 10 sequential pipeline stages (`specify` through `audit`). Each stage's execution context affects context budget consumption, isolation between stages, observability, failure containment, and whether one stage can pollute another's decision-making.

The user's existing manual workflow is to `/clear` between phases specifically to prevent prior-phase context from biasing the next phase's reasoning. Any orchestrator design that re-introduces cross-phase carryover would regress this practice.

## Decision

Every pipeline stage executes in a fresh subagent dispatched by the orchestrator via the Agent tool. The orchestrator itself runs in the main session as a thin coordinator. Each subagent reads its inputs from disk (prior artifacts) and returns a structured summary; the orchestrator does not see the subagent's internal reasoning trace.

## Alternatives Considered

### Option A: All stages in main session

Orchestrator invokes each skill inline; full conversation visibility.

**Pros**: Simplest model; live reasoning visibility; lowest token overhead per stage.
**Cons**: Cross-phase context pollution (regression of user's manual `/clear` practice); 10-stage pipeline blows the main context window; one stage's reasoning biases the next.

### Option B: Subagent per stage *(chosen)*

Every stage dispatches to a fresh subagent.

**Pros**: Full isolation between stages — matches the user's existing `/clear`-between-phases practice; main-session context stays slim regardless of pipeline length; stage failures contained; clean per-stage telemetry.
**Cons**: Token overhead from per-stage cold starts (~9 cold starts on a 10-stage pipeline); no live reasoning visibility within stages; orchestrator can only act on returned summaries, not on in-flight signals.

### Option C: Mixed (short stages in main, long in subagent)

Lightweight stages stay in main; expensive ones dispatch out.

**Pros**: Reduces cold-start overhead for cheap stages.
**Cons**: Inconsistent isolation guarantees; reintroduces partial cross-phase pollution; complicates failure handling (two failure surfaces).

### Option D: Defer (start with main, migrate reactively)

Pick A for V1, migrate to subagents when context proves insufficient.

**Pros**: Simpler V1.
**Cons**: Defers the dominant architectural decision; rework later; first runs will produce data that may not generalize once execution model changes.

## Rationale

The user's manual `/clear`-between-phases practice is itself evidence that cross-phase pollution is a real cost. Option B automates exactly that practice. The token overhead from cold starts is the price for decision independence — a price the user is already paying manually. Option C's hybrid creates inconsistent isolation guarantees and complicates the failure model (ADR-011) without meaningfully improving the user-relevant outcome.

## Consequences

**Positive**: Each stage's reasoning is independent of prior stages; main session context stays light regardless of pipeline length; subagent failures are containable and individually re-runnable; clean per-stage telemetry boundary.
**Negative / Trade-offs**: ~9 subagent cold-starts per full pipeline run; orchestrator cannot interject within a stage; subagent's internal reasoning is not retrievable post-hoc except via the structured summary it returns.
**Risks**: Subagent's structured summary may omit relevant reasoning details that the developer later wants to audit. Mitigation: subagent must write its working artifact to disk (already required by each speckit skill); the artifact is the full record. Decision-log entries reference the artifact paths.
**Follow-on decisions required**: Planning-phase decision on subagent prompt structure (how the orchestrator briefs each stage); per-stage telemetry schema (FR-018 baseline, see LOG-004 for granular extension).

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-25 | Initial record | Claude (clarification session for spec 010) |
