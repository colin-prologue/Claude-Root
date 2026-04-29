# ADR-021: Smoke-Tier Fixture Selection and Cost Cap

**Date**: 2026-04-26
**Status**: Proposed
**Decision Made In**: specs/010-autonomous-workflow/plan.md § Project Structure (closes ADR-017 follow-on)
**Related ADRs**: ADR-017 (hybrid TDD strategy)
**Related Logs**: LOG-007 (codereview model-class diversity — smoke fixture is the substrate)

---

## Context

ADR-017's hybrid test strategy ships a Tier 2 smoke suite that runs `/speckit.run` end-to-end against real subagent dispatches with a token-cost cap. ADR-017 left two follow-on decisions for the plan phase:

1. **Fixture selection** — which feature description(s) exercise the most contract surface per dollar.
2. **Cost cap** — per-run token budget and per-merge total budget.

V1 ships single-mode BLOCKING-everywhere (ADR-014, ADR-015), so the smoke tier's primary job is verifying the **subagent-orchestrator contract** (FR-006 schema conformance, ADR-013 subagent-direct-write protocol, ADR-016 canonical/derivative split). Routing variations (multi-blocker, clarification serialization, target-subset edge cases) are already covered by Tier 1 unit tests against canned fixtures (ADR-019); they do not need real subagent runs.

The remaining contract-coverage need: a single happy path that exercises (a) `specify` writing a per-stage record, (b) `plan` reading prior records and writing its own, (c) the orchestrator's stage-skip path triggered by the FR-026 completeness predicate. This is the **minimum path that touches every part of the contract that the smoke tier exists to verify**.

## Decision

V1 ships **two fixtures and conservative cost caps** (revised 2026-04-26 post-plan-review):

**Fixture 1 — green path**: `tests/smoke/fixtures/feature-min-path.txt` — a synthetic feature description ~250 words long, scoped to require:
- `/speckit.specify` to produce a `spec.md` with all mandatory sections, no `[NEEDS CLARIFICATION]` markers (passes FR-026 predicate).
- `/speckit.plan` to produce a `plan.md` that references one new ADR (verifies the ADR-gate path).
- No `clarify` invocation (intentional — the description is unambiguous so the smoke fixture exercises FR-024's empty-stage-skip path).

Target pipeline: `specify→plan`. Two real subagent dispatches per run on the green path.

**Fixture 2 — halt path** (added post-plan-review): `tests/smoke/fixtures/feature-halt-on-specify.txt` — a synthetic feature description ~150 words long, scoped to require:
- `/speckit.specify` to emit a per-stage record with `halt_directive=true` (e.g., the description contains a deliberate ambiguity that the spec subagent must surface as `[NEEDS CLARIFICATION]`).
- `run-decide-next.sh` outputs `halt:subagent-halt-directive` after stage 1; the orchestrator coalesces and exits before stage 2 runs.

Target pipeline: `specify→plan` (same target string as Fixture 1). One real subagent dispatch per run on the halt path; the second dispatch never fires. This fixture verifies the halt-coalesce path (ADR-016 MUST-coalesce) and the verdict-receipt protocol (ADR-022) on a halt verdict — surfaces that Fixture 1 alone cannot reach.

**Cost caps**:
- **Per-run cap**: 50,000 tokens total (input + output combined). Estimate basis: a typical `specify` dispatch consumes ~10–15K tokens; a typical `plan` dispatch consumes ~20–30K tokens including reading prior artifacts. The green-path fixture lands at ~30–45K; the halt-path fixture lands at ~10–15K (single dispatch, no plan stage). The 50K cap covers both.
- **Per-merge cap**: 100,000 tokens total across both fixtures — green path (~30–45K) plus halt path (~10–15K) is ~40–60K, leaving 40–60K headroom for one re-run if a transient flake occurs. A third attempt is a contract-violation signal per ADR-017 and blocks the merge for investigation rather than spending more budget.

Cost is recorded by the smoke harness reading the Claude Code `usage` field on each Task-tool dispatch and summing. Exceeding the per-run cap halts the run with a budget-exhaustion failure logged to the sidecar; exceeding the per-merge cap blocks the PR.

## Alternatives Considered

### Option A: Two fixtures — green path + halt path *(chosen, revised post-plan-review)*

Two synthetic features; both target `specify→plan`; halt-path fixture terminates after one dispatch.

**Pros**: Covers the two highest-risk smoke surfaces — (a) clean route through the deterministic core (Fixture 1) and (b) the halt-coalesce + verdict-receipt path (Fixture 2). The halt fixture costs ~10–15K (single dispatch) so the marginal spend over Option C is small. Fixture 1 still doubles as the LOG-007 measurement substrate.
**Cons**: Two fixtures to maintain instead of one. Halt-path fixture's specific halt trigger may need re-tuning if the `specify` subagent's halt heuristic changes. Acceptable trade because both fixtures are <300 LOC of bats and the halt-path test catches a contract violation (silent halt-coalesce skip) that no Tier 1 unit test can.

### Option B: Two fixtures — happy path + clarification-required

Same fixture count as Option A but the second fixture exercises `clarify` rather than halt.

**Pros**: Covers the clarification path with real subagent output.
**Cons**: A `clarify` fixture costs roughly the same as a second full `specify→plan` (it adds a third dispatch rather than terminating early). FR-022 is already deterministic and Tier 1 covers it. The halt-path coverage is the higher-risk gap (it touches MUST-coalesce and verdict-receipt). Reconsider in V2 if dogfooding shows clarify-path drift.

### Option C: Single happy-path fixture (original V1 plan, superseded)

One synthetic feature; `specify→plan`; ~30–45K-token budget.

**Pros**: Minimum spend.
**Cons**: Halt-coalesce (ADR-016) and verdict-receipt (ADR-022) paths are unverified at the smoke tier. Both are in-band correctness properties of the deterministic core; smoke is the only tier that exercises them against real subagent output. Superseded by Option A after ADR-016 MUST-coalesce and ADR-022 receipt protocol made the halt path a load-bearing test surface.

### Option D: Full pipeline fixture — `specify→...→audit`

Run the entire pipeline through one fixture.

**Pros**: Verifies the contract for every stage in one fixture run.
**Cons**: Cost balloons to several hundred thousand tokens per run (implement and codereview dispatches dominate). Most stages' contracts are already verified at Tier 1; the marginal coverage is concentrated in the early stages, which Option A already covers. Defer until SC-008's V1 ship-or-retire data is in.

### Option E: No smoke tier — Tier 1 only

Drop Tier 2 entirely; rely on dogfooding to surface contract violations.

**Pros**: Zero token spend.
**Cons**: ADR-017 explicitly rejected this — first real run becoming first integration test is exactly the failure mode the hybrid strategy is meant to prevent. Contract drift would land in production-equivalent code (since the project is the orchestrator).

## Rationale

The smoke tier's purpose is **contract verification, not behavioral coverage**. Two fixtures — one green path, one halt path — cover the two contract surfaces no Tier 1 unit test can reach (real subagent output through the deterministic core, plus the halt-coalesce + verdict-receipt path). Tier 1 still covers the routing matrix exhaustively; the smoke fixtures verify that Tier 1's assumptions hold against actual LLM dispatches.

The halt-path fixture's marginal cost is small (~10–15K tokens — a single specify dispatch terminates the run) because the orchestrator never reaches stage 2. The original Option C analysis assumed two fixtures meant doubling spend; that assumption was wrong for halt fixtures specifically because halt terminates early. Correcting that assumption is what made Option A viable at the same per-merge budget.

50K tokens per run is conservative — well under one Sonnet invocation's full context window — but provides headroom for the green fixture's variability. 100K per merge accommodates both fixtures plus one retry without blowing the gate. These caps are not tight optimizations; they are visible, blockable spending limits that prevent runaway smoke-tier cost from flaky subagents or prompt drift inflating dispatch size.

Fixture 1 doubles as the LOG-007 measurement substrate (codereview model-class diversity), giving the smoke tier secondary value even when the contract-verification work lands cleanly.

## Consequences

**Positive**: ADR-017 follow-on closes. Smoke-tier cost is predictable and capped. Contract-violation signals are clean across both green and halt paths. LOG-007 measurement protocol has its data substrate. Halt-path fixture verifies ADR-016 MUST-coalesce and ADR-022 verdict-receipt against real subagent output — properties no Tier 1 test can validate.

**Negative / Trade-offs**: Coverage is still narrow — green and halt paths only on `specify→plan`. Contract drift on stages outside `specify→plan` lands at first developer use, not at smoke-tier merge gate. Acceptable trade because (a) Tier 1 covers routing exhaustively, (b) those later stages are themselves dogfooded by SC-008's 30-day floor.

**Risks**:
- Per-run cap proves too tight — mitigation: caps are explicit values in `tests/smoke/fixture_min_path.bats` and `tests/smoke/fixture_halt_on_specify.bats`; raise after one run with measured actuals if needed.
- Per-merge cap blocks legitimate work — mitigation: 100K leaves room for both fixtures plus one full retry; a second consecutive failure is contract drift, not budget pressure.
- Halt-path fixture's halt trigger drifts as the `specify` subagent prompt evolves — mitigation: the fixture description is checked into the repo; if a future prompt change causes the trigger to no longer halt, the smoke fail signals the fixture needs retuning (a desired failure mode, not a flake).
- Two-fixture drift undetected on stages outside `specify→plan` — mitigation: re-evaluate at V2 alongside ADR-015 ship-or-retire decision.

**Follow-on decisions required**: None for V1. V2 considers fixture expansion if dogfooding reveals contract drift on stages outside `specify→plan`.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-26 | Initial record (closes ADR-017 follow-on) | Claude (plan-phase for spec 010) |
| 2026-04-26 | Revised: added Fixture 2 (halt path) to verify ADR-016 MUST-coalesce + ADR-022 verdict-receipt against real subagent output; corrected cost analysis (halt fixture terminates after stage 1, marginal cost ~10–15K not double); restructured options (chosen is now Option A two-fixture; original Option C single-fixture documented as superseded) | Claude (synthesis-judge for spec 010 plan-gate revision) |
