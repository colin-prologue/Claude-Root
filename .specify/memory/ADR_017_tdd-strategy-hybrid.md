# ADR-017: Hybrid Test Strategy for Non-Deterministic Dispatcher

**Date**: 2026-04-26
**Status**: Proposed
**Decision Made In**: specs/010-autonomous-workflow/ (plan-phase resolution of LOG-006)
**Related ADRs**: ADR-009 (subagent-per-stage execution), ADR-013 (subagent writes decision-log directly), ADR-016 (canonical/derivative model)
**Related Logs**: LOG-006 (closes)

---

## Context

Constitution Principle III (NON-NEGOTIABLE) mandates Test-Driven Development: no implementation code before a failing test. The `/speckit.run` orchestrator dispatches LLM subagents whose output is non-deterministic and routes on the on-disk artifacts they produce (per ADR-013/ADR-016). Standard TDD assumes the unit under test is deterministic for a given input; the orchestrator is not.

LOG-006 raised this as a plan-phase blocker. Without a defined strategy, the plan author would either invent thin coverage under pressure or post-hoc rationalize a Principle III violation. The question is not "should we do TDD" — it is "what does TDD mean for a system whose primary work is dispatching non-deterministic agents?"

The orchestrator surface decomposes cleanly:

- **Deterministic**: routing logic given a structured `decisions-log.md` entry; FR-026 completeness predicate; FR-021 multi-blocker collection; FR-022 clarification serialization; FR-023 spec-already-exists routing; FR-027/FR-028 sentinel and lock semantics; sandbox allowlist enforcement (FR-020); target-pipeline selection-vs-sequence handling (FR-009); FR-006 schema validation on read.
- **Non-deterministic**: every subagent dispatch and every artifact a subagent produces.

TDD applies cleanly to the first surface. The second needs a different control.

## Decision

V1 ships a **two-tier hybrid test strategy**:

**Tier 1 — Unit (TDD-strict, runs pre-commit)**

Tests pass canned `decisions-log.md` entries, canned artifact contents, and canned filesystem states to the orchestrator's pure functions and assert the next dispatch (or halt, or skip, or route) is correct. This tier is genuinely deterministic and follows Principle III without exemption.

Mandatory coverage at this tier:
- FR-006 schema validation (well-formed entries pass; malformed entries halt as semantic failure per FR-019)
- FR-026 completeness predicate per stage artifact
- FR-021 multi-blocker collection (no halt-on-first-match)
- FR-022 clarification serialization (no parallel prompts)
- FR-023 spec-already-exists routing (resume vs `--force` halt)
- FR-024 empty-stage-output logging (explicit `stage-skip` entry)
- FR-025 below-halt-threshold continuation
- FR-027 atomic sentinel + lock removal on abort
- FR-028 lock acquisition, conflict halt, and `--break-lock` clearing (per ADR-018)
- FR-020 sandbox allowlist (each disallowed action triggers permission halt)
- FR-009 target-pipeline contiguity validation
- ADR-016 sidecar write protocol (orchestrator writes to `.run/control-flow.log`, never to `decisions-log.md` during stage execution)

This tier is the source of truth for orchestrator correctness. It runs on every commit.

**Tier 2 — Smoke (runs pre-merge, not pre-commit)**

A small fixture suite (target: 1–2 fixture features) runs the orchestrator end-to-end against real `/speckit.specify` and `/speckit.plan` subagent dispatches, with a token-cost cap per run. Asserts the contract between orchestrator and subagent: subagents conform to FR-006 schema, write their per-stage record before exit (per ADR-013), and the orchestrator routes correctly on real subagent output.

Smoke-tier flakiness is expected and budgeted: a smoke failure that does not reproduce in unit tests is a contract-violation signal, not a bug-in-orchestrator signal. Repeated smoke failures across runs trigger investigation; isolated flakes are tolerated.

This tier protects against the failure mode unit tests cannot catch: the subagent contract drifting silently from what the orchestrator expects.

## Alternatives Considered

### Option A: Mocks-only (Strategy A from LOG-006)

Pros: fast, deterministic, fully TDD-compliant.
Cons: tests verify the orchestrator alone, not the system; the subagent contract is unverified end-to-end; first real run is the first integration test — exactly the failure mode Principle III is meant to prevent.

### Option B: Real-subagent integration only (Strategy B from LOG-006)

Pros: tests the real system.
Cons: cost; flakiness destroys the pre-commit feedback loop; TDD becomes ceremonial because no developer runs flaky tests on every change.

### Option C: Routing-logic-only with constitution exemption (Strategy C from LOG-006)

Pros: smallest surface; honest about non-determinism.
Cons: leaves the orchestrator-subagent contract unverified; the FR-006 schema is the load-bearing interface and must be exercised against real subagent output before merge.

### Option D: Hybrid — unit + smoke *(chosen)*

Pros: pre-commit feedback loop preserved; subagent contract verified before merge; exemption is bounded to the LLM-call boundary (the smoke tier itself is the compensating control); aligns with the durable-store-first architecture (ADR-013/ADR-016) — the on-disk artifacts the smoke tier produces are themselves the test evidence.
Cons: two test tiers to maintain; smoke-tier cost is real (token spend per pre-merge run).

## Rationale

The hybrid strategy honors Principle III's *intent* — tests catch defects before code — without pretending a non-deterministic surface is testable like a pure function. The exemption is precisely scoped: only the LLM call itself is exempted, and the smoke tier is the compensating control that verifies the contract end-to-end. Routing logic, schema validation, and control-flow primitives remain TDD-strict.

The two-tier separation matches developer feedback-loop economics. Pre-commit must stay fast and deterministic or it gets bypassed. Pre-merge can absorb cost and flakiness because it runs on a smaller cadence and with explicit human awareness.

Option D's smoke tier doubles as the LOG-007 measurement protocol substrate: the same fixture runs that verify the contract also produce the codereview-vs-implement findings overlap data needed to resolve LOG-007's empirical question.

## Consequences

**Positive**: Plan-phase blocker (LOG-006) closes. Principle III honored with bounded, named exemption. Two-tier separation matches the orchestrator's actual surface decomposition. Smoke tier amortizes across LOG-007 measurement.

**Negative / Trade-offs**: Two test tiers to maintain. Smoke-tier token cost is recurring. CI configuration must distinguish pre-commit from pre-merge tiers.

**Risks**:
- Smoke-tier flakiness rate exceeds tolerance — mitigation: budget the flakiness explicitly; investigate only repeated failures across runs; isolated flakes do not block merge.
- Subagent contract drifts and unit tests pass while smoke tier catches it late — acceptable: that is exactly what the smoke tier exists for.
- Token cost exceeds budget — mitigation: cap fixture count at 2 in V1; reassess at V2 with dogfooding evidence on actual cost.

**Follow-on decisions required**:
- Plan-phase decision on smoke-tier fixture selection (which feature descriptions exercise the most contract surface per dollar).
- Plan-phase decision on smoke-tier cost cap (per-run token budget; per-merge total budget).
- V2 ADR if smoke-tier flakiness rate proves intolerable and a third tier or different control is needed.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-26 | Initial record (closes LOG-006) | Claude (plan-phase resolution for spec 010) |
