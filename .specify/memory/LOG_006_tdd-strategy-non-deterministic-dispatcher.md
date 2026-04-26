# LOG-006: TDD Strategy for Non-Deterministic LLM Dispatcher

**Date**: 2026-04-26
**Type**: QUESTION
**Status**: Resolved (ADR-017 — 2026-04-26)
**Raised In**: specs/010-autonomous-workflow/spec.md § /speckit.review spec gate (Phase B devils-advocate U-2)
**Related ADRs**: ADR-009 (subagent-per-stage execution), ADR-013 (subagent writes decision-log directly)

---

## Description

The Constitution's Principle III mandates Test-Driven Development: never write implementation code before a failing test exists. The /speckit.run orchestrator dispatches LLM subagents whose output is non-deterministic and parses their summaries (or, post-ADR-013, reads decision-log entries they wrote). Standard TDD assumes the unit under test produces deterministic output for a given input. The orchestrator does not.

How does TDD apply to a feature whose primary functionality is dispatching non-deterministic agents and routing on the results? This question must be answered before plan-phase task ordering is committed.

## Context

Raised during Phase B of the spec gate review (U-2). Both reviewers agreed (PS at 90% concession): the spec does not acknowledge the TDD tension. If left unresolved, the plan author will hit this wall and have to invent a test strategy under pressure, likely producing thin coverage or post-hoc rationalization for skipping TDD.

This is not a request to violate Principle III — it is a request to define what TDD means for this feature class.

## Discussion

### Pass 1 — Initial Analysis

The orchestrator has both deterministic and non-deterministic surfaces. Deterministic: routing logic given a structured log entry, file-path detection, sandbox-allowlist enforcement, severity-threshold parsing, target-pipeline selection-vs-sequence handling. Non-deterministic: every subagent dispatch and every subagent-produced artifact.

TDD applies cleanly to the deterministic surface. The question is what to do about the non-deterministic surface.

### Pass 2 — Critical Review

Three candidate strategies:

**Strategy A: Mock subagents with canned output.** Write tests that pass canned log entries / canned artifact contents to the orchestrator's routing logic and assert the next dispatch happens correctly. Fast, deterministic, testable. Drawback: tests verify the dispatcher, not the system. A subagent that misbehaves in production is not exercised by these tests.

**Strategy B: Integration tests with cost-capped real subagents.** Run real `/speckit.specify` against a fixture description, assert the orchestrator routes to the next stage. Slow, expensive, non-deterministic, flaky. Drawback: cost; flakiness undermines TDD's tight feedback loop.

**Strategy C: Test only the deterministic routing logic; accept the LLM portion as untestable.** Write a Constitution amendment / LOG entry justifying the TDD exemption for orchestrator dispatch and limit testing to routing logic and contract validation.

**Strategy D: Hybrid — Strategy A for unit tests, Strategy B for a small smoke-test suite that runs less frequently (pre-merge, not pre-commit).** Captures the value of both with manageable cost.

### Pass 3 — Resolution Path

Plan author selects a strategy and either justifies it within Principle III or documents the exemption in this LOG and amends the constitution if needed.

## Resolution

Strategy D (hybrid) chosen. ADR-017 codifies a two-tier test strategy: Tier 1 unit tests (TDD-strict, pre-commit) covering all deterministic orchestrator surfaces (FR-006/009/020/021/022/023/024/025/026/027/028 and ADR-016 sidecar protocol); Tier 2 smoke tests (pre-merge, not pre-commit) running 1–2 fixture features end-to-end with cost-capped real subagents to verify the orchestrator-subagent contract. Principle III's exemption is bounded to the LLM-call boundary; the smoke tier is the compensating control.

**Resolved By**: ADR-017 (2026-04-26 plan-phase decision)
**Resolved Date**: 2026-04-26

## Impact

- [ ] Spec updated: specs/010-autonomous-workflow/spec.md adds explicit clarification question for plan author
- [ ] Plan updated: TBD
- [ ] ADR created/updated: TBD (may produce ADR for chosen test strategy)
- [ ] Tasks revised: TBD
