# LOG-011: BLOCKING-Gate Rubber-Stamping Risk

**Date**: 2026-04-26
**Type**: CHALLENGE
**Status**: Open
**Raised In**: specs/010-autonomous-workflow plan-gate review (Phase B, devil's advocate)
**Related ADRs**: ADR-014 (BLOCKING-by-default at code-action gates), ADR-023 (pre-route linter postcheck), ADR-015 (V1 scope boundary)

---

## Description

ADR-014 makes every code-action gate BLOCKING in V1: the developer must explicitly `proceed` before `implement`, `codereview`, or `audit` runs. The intent is to keep a human in the loop on every repository-mutating stage. The risk: BLOCKING is a procedural defense; it does not prevent the developer from reflexively typing `proceed` at every prompt without reading the checkpoint payload.

Under reflexive `proceed` behavior, BLOCKING degrades to OBSERVING-with-extra-keystrokes. The audit-substrate property "every code-action ran with explicit human approval" becomes formally true and substantively false — an outcome strictly worse than OBSERVING because it carries the *appearance* of oversight without the substance.

V1 ships ADR-023's pre-route postcheck as a partial mitigation: BLOCKING checkpoints carry concrete pre-checked findings the developer must react to. But the risk of generic-payload rubber-stamping persists for stages where the postcheck returns clean — the developer sees "✓ all checks passed" and accepts without reading the diff.

## Context

Plan-gate review of feature 010, devil's advocate Phase B reframed a delivery-reviewer finding (F-09: artifact-vs-claim validation gap) by pointing out that BLOCKING-as-mitigation only works if the developer engages. The reframe surfaced the rubber-stamping risk as a separate, structural concern from the artifact-validation gap.

V1's response landed as ADR-023 (give the developer something pre-checked to react to) plus this LOG (track the residual risk). The decision NOT to ship a more aggressive intervention (e.g., enforced wait time, mandatory diff review confirmation) was deliberate: V1 is single-mode and trust-first (ADR-015); friction-heavy gates conflict with the "stable enough to dogfood" goal.

## Discussion

### Pass 1 — Initial Analysis

Possible interventions, ranked by friction:
1. **None**: BLOCKING + ADR-023 postcheck is sufficient.
2. **Minimum-display-time**: refuse `proceed` for the first 3 seconds after the BLOCKING prompt appears.
3. **Diff-acknowledged confirmation**: require the developer to enter a hash of the diff or a short summary before `proceed` is accepted.
4. **OBSERVING demotion**: drop BLOCKING entirely if the data shows it's not adding value; don't carry the false-oversight property.

V1 chose option 1.

### Pass 2 — Critical Review

The minimum-display-time intervention is the cheapest, but it doesn't address the failure mode — a determined rubber-stamper just waits 3 seconds. The diff-acknowledged confirmation works but is intrusive enough to bias developers against the orchestrator entirely; under SC-008's 30-day floor, that bias would surface as "the orchestrator is annoying" rather than as the more accurate "BLOCKING is annoying when it doesn't catch anything." Confounded signal.

The honest case for option 1 is that the rubber-stamping risk is real but unmeasured. Shipping V1 with the minimum mitigation (postcheck findings inline) and the dogfooding floor (SC-008's 30-day data) lets the project measure the rubber-stamp rate before deciding which intervention to invest in.

### Pass 3 — Measurement Plan

For V1 ship-or-retire evaluation (per SC-008), instrument:
- **Time between BLOCKING prompt and `proceed`**: median, p95, count of <3-second responses.
- **`proceed`-rate when postcheck has findings vs clean**: a high `proceed` rate on findings-present checkpoints is a direct rubber-stamping signal.
- **Override frequency**: `route` events with `reason=postcheck-override` per developer per week.

These metrics live in the same `.run/control-flow.log` sidecar (ADR-020) and require no new infrastructure. SC-008's 30-day evaluation reads them.

## Resolution

Open. V1 mitigation is ADR-023 (pre-route postcheck with findings inlined to the BLOCKING payload). Residual rubber-stamping risk is accepted for V1 with measurement plan attached; SC-008's 30-day evaluation is the trigger for either accepting the residual risk, escalating to a friction-heavier intervention, or demoting to OBSERVING (option 4).

**Resolved By**: Pending V1 dogfooding data per SC-008.
**Resolved Date**: N/A

## Impact

- [X] Plan updated: specs/010-autonomous-workflow/plan.md (Decision Records table includes this LOG)
- [X] ADR created/updated: ADR-023 referenced as V1 mitigation; ADR-015 referenced as the trust-first scope that this LOG accepts as a residual risk
- [ ] Tasks revised: V1 task list includes telemetry capture for the metrics above (covered by ADR-020 sidecar fields; no new tasks needed)
