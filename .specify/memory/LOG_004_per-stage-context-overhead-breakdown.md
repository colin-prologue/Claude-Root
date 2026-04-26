# LOG-004: Granular Per-Stage Context Overhead Breakdown

**Date**: 2026-04-25
**Type**: QUESTION
**Status**: Open
**Raised In**: specs/010-autonomous-workflow/spec.md § Clarifications (Q2 follow-up)
**Related ADRs**: ADR-009

---

## Description

Spec 010 commits to recording total token usage per subagent dispatch (FR-018) but defers granular breakdown of context-overhead sources. The user surfaced this as a learning need: knowing which stage spent how many tokens is useful, but knowing the *composition* of those tokens — system prompt size, MCP server contributions, carried context, iteration count — would directly inform where to optimize and where to add guardrails.

The question this log captures: how do we surface a granular breakdown of subagent context usage, and what mechanism makes those numbers available?

## Context

This question arose during the clarification of Q2 (execution context per stage). The user accepted subagent-per-stage execution (ADR-009) and noted that it would be valuable to track context usage with breakdowns: "loaded scripts, MCP, carried context, iterations." The basic version (per-dispatch token total) is captured in FR-018; the granular version is deferred.

This is non-trivial because the relevant data may not all be directly exposed by Claude Code's Agent tool API. Some categories (system prompt size, MCP server contributions) are environmental and may require tooling outside the orchestrator. Others (iteration count, carried context size) are internal to the subagent and may need a contract for the subagent to self-report.

## Discussion

### Pass 1 — Initial Analysis

Subagent-per-stage execution (ADR-009) makes per-dispatch measurement easier than session-wide tracking — each dispatch is a discrete unit. The Agent tool's response includes some metadata; total token counts are routinely available. But the breakdown into categories the user wants is not natively exposed in a structured way.

Three plausible mechanisms:
1. Subagent self-reports its breakdown in its returned summary (requires every subagent to instrument itself).
2. The orchestrator wraps each Agent dispatch with telemetry that captures what it can observe externally (limited to dispatch-level totals).
3. A separate observability layer (hook-based or post-hoc analysis of session transcripts) computes the breakdown out-of-band.

### Pass 2 — Critical Review

Approach 1 is invasive — every speckit skill would need instrumentation for an observability concern that doesn't change the skill's behavior. That's the wrong place to put this.

Approach 2 only gets the gross numbers — the "carried context" and "iteration count" pieces aren't externally visible to the orchestrator.

Approach 3 is most promising but requires understanding what data Claude Code surfaces about subagent runs (transcript availability, hook event schemas, etc.) before committing to a mechanism. This is groundwork that doesn't exist in the V1 scope.

## Resolution

Deferred. V1 ships with FR-018 (gross per-dispatch token count). Granular breakdown is a follow-on concern requiring (a) investigation of Claude Code's available telemetry hooks, (b) decision on which of the three mechanisms above (or a fourth) is least invasive, and (c) potentially a separate feature spec.

**Resolved By**: Deferred to a follow-on feature
**Resolved Date**: N/A (open)

## Impact

- [x] Spec updated: specs/010-autonomous-workflow/spec.md FR-018 (notes V1 baseline + this LOG for follow-up)
- [ ] Plan updated: N/A (will surface again at planning if telemetry questions arise)
- [ ] ADR created/updated: N/A (no architectural decision yet — this is an open question)
- [ ] Tasks revised: N/A
