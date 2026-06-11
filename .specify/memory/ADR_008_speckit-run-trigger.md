# ADR-008: `/speckit.run` as Pipeline Orchestrator Trigger

**Date**: 2026-04-25
**Status**: Accepted
**Decision Made In**: specs/010-autonomous-workflow/spec.md § Clarifications (Q1)
**Related Logs**: None

---

## Context

Spec 010-autonomous-workflow introduces an orchestrator that runs multiple speckit pipeline stages sequentially. The trigger mechanism shapes how the feature integrates with existing single-stage commands and how developers discover and invoke the orchestrator.

## Decision

The orchestrator is exposed as a new `/speckit.run` slash command. Existing single-stage commands (`/speckit.specify`, `/speckit.plan`, `/speckit.tasks`, `/speckit.review`, etc.) remain unchanged and continue to work standalone.

## Alternatives Considered

### Option A: New `/speckit.run` slash command *(chosen)*

Single new entry point that takes target stages and checkpoint policy as arguments.

**Pros**: Composes with existing surface; matches the user mental model "one command kicks off the pipeline"; orthogonal to single-stage commands; discoverable via the same slash-command UI.
**Cons**: Adds another command to the project's command inventory.

### Option B: Enhancement flag on `/speckit.specify`

The first stage triggers the rest via a flag like `--through tasks`.

**Pros**: No new command surface.
**Cons**: Conflates two distinct use cases (one stage vs. pipeline); flag-based pipelining hides behavior; awkward when the developer wants to start from a non-`specify` stage.

### Option C: Standalone orchestrator agent

A subagent dispatched via the Agent tool runs the entire pipeline in isolation.

**Pros**: Survives main-session context limits.
**Cons**: Conflates trigger mechanism with execution context — those are orthogonal axes (see ADR-009 for execution context).

### Option D: Config file plus generic trigger

`.specify/orchestrator.yaml` config plus `/speckit.go` trigger.

**Pros**: Same trigger across features.
**Cons**: Config drift; per-feature divergence requires re-editing the same file repeatedly.

## Rationale

`/speckit.run` is the simplest delivery that preserves the existing command surface and gives the orchestrator a clear, dedicated identity. Bundling it into an existing command (Option B) creates two-headed semantics. Pre-coupling to subagent execution (Option C) prematurely binds delivery to runtime architecture — those are decoupled by ADR-009.

## Consequences

**Positive**: Clear separation between single-stage and full-pipeline workflows; existing commands remain usable for ad-hoc operations; new behavior is opt-in.
**Negative / Trade-offs**: Two ways to run any individual stage (standalone command vs. via orchestrator) — risks behavioral divergence if the orchestrator wraps a stage differently than its standalone command.
**Risks**: If the orchestrator's stage invocation diverges from the standalone command behavior, debugging becomes harder. Mitigation: orchestrator dispatches the same skill as the standalone command — no parallel implementation.
**Follow-on decisions required**: ADR-009 (execution context per stage); planning-phase decision on argument syntax for target-stages and checkpoint-policy.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-25 | Initial record | Claude (clarification session for spec 010) |
