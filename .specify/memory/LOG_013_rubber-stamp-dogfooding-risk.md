# LOG-013: BLOCKING-Gate Rubber-Stamping Dogfooding Risk — "✓ all checks passed" Worsens Honest Signal

**Date**: 2026-04-26
**Type**: Challenge
**Status**: Open (V2 measurement deferred; V1 mitigations only)
**Related**: LOG-011 (BLOCKING-gate rubber-stamping), ADR-023 (pre-route postcheck), helper-contracts.md `run-postcheck.sh` §Output (M-4 contract migration), SC-008
**Origin**: Plan-gate re-review (devil's-advocate preserved dissent — Claim D-1)

---

## Challenge

ADR-023 introduces `run-postcheck.sh` to surface concrete pre-checked findings ("ADR-XYZ referenced but not in repo", "claimed test file not found") inline in the BLOCKING-checkpoint payload for code-action stages. The intent: anchor the developer's `proceed`/`abort` decision on something more durable than a yes/no signal.

The devil's advocate at plan-gate re-review preserved the following dissent and did not withdraw it under cross-examination:

> **The "✓ all checks passed" prompt may be strictly worse than the pre-revision honest signal.** A clean postcheck banner is more reassuring than a payload with no findings, even though they carry identical information ("nothing flagged"). The visual cue tilts the developer toward `proceed` — possibly more strongly than a payload that says nothing at all. The pre-ADR-023 BLOCKING checkpoint at least forced the developer to confront an empty findings section as ambiguous; the postcheck banner converts ambiguity into reassurance.

The risk is asymmetric: when postcheck *finds* a real issue, the inline finding does its job. When postcheck finds nothing, the green banner accelerates rubber-stamping past the threshold the BLOCKING gate was designed to enforce.

This is the dogfooding paradox: V1 builds the orchestrator with the orchestrator. If the postcheck banner systematically degrades pause discipline during V1's own development, the audit substrate the project depends on is contaminated by the very mechanism intended to protect it.

## Context

LOG-011 already tracks the residual rubber-stamping risk and names SC-008 as the measurement plan in spec.md. This LOG narrows the concern to a specific failure mode introduced by ADR-023's mitigation: **the cure may be worse than the disease in the no-findings path**, even if it improves the with-findings path.

The synthesis judge at re-review accepted the postcheck mitigation for spec progress but recorded this as a non-blocking dissent.

## V1 Posture: Mitigations Only, No Measurement

A prior draft of this LOG specified an SC-008 instrumentation chain — wall-clock-delta sidecar field on `run-decide-next.sh`, Branch A/B segmentation by no-findings vs with-findings, a 30-checkpoint kill-switch comparing Branch B rubber-stamp rate against a pre-ADR-023 baseline. **Re-Review #2 (DA finding SR-1, 92% confidence) flagged this as invented infrastructure**: spec.md SC-008 (L173) does not name rubber-stamp rate, wall-clock deltas, Branch A/B, or kill-switch arithmetic; helper-contracts.md `run-decide-next.sh` does not list wall-clock-delta as a MUST-emit field; the kill-switch baseline requires retroactive measurement that the orchestrator is not capturing.

The honest V1 posture is: **ship the mitigations, defer the measurement**. The project context (solo developer, no Branch A/B test infrastructure, dogfooding-during-build) does not support the kill-switch arithmetic the prior LOG draft claimed.

V1 ships ADR-023 as designed with two phrasing/escape-hatch mitigations (below). **No instrumentation, no kill-switch in V1.** A V2 ADR will revisit measurement once the orchestrator stops being its own audit substrate.

## V1 Mitigations (in scope)

1. **No-findings phrasing requirement (contract-anchored, not LOG-anchored)**: per Re-Review #3 M-4, the neutral-phrasing requirement is moved from this LOG into `helper-contracts.md` §`run-postcheck.sh` Output as a normative MUST clause: clean-exit output is a single neutral status line (`postcheck: no findings`) — no iconography, no color, no "✓ all checks passed" affirmation. The contract is the source of truth a future implementer consults; this LOG retains only the rationale (the dogfooding paradox). PR3b-i ships `.claude/commands/speckit.run.md` against the contract; the static-grep test in PR3b-ii asserts the postcheck invocation point in the slash command emits the contracted phrasing on clean exit.
2. **No env-var escape hatch in V1** (per Re-Review #3 M-3 / DA-2): a prior draft of this LOG specified `SPECKIT_POSTCHECK_BANNER=off` as a developer-authored escape hatch. The env var has no implementation owner in any V1 PR (not in `helper-contracts.md`, not in PR3b-i scope) and the project context (solo, async, multi-project) does not support the feedback loop the escape hatch presumes (notice degraded attention → flip env var → author memory entry). **Dropped from V1.** If a V2 ADR introduces banner-toggling, it lives in `helper-contracts.md` with a Tier-1 bats assertion, not in a LOG.

## V2 Trigger Condition (re-evaluation)

This LOG should be re-evaluated when **any one** of the following conditions is met:

1. The orchestrator is no longer dogfooding itself — i.e., a non-trivial feature is implemented end-to-end via `/speckit.run` without the developer also editing the orchestrator's helper scripts in the same branch. At that point, BLOCKING-checkpoint behavior can be observed as a pure-consumer signal.
2. SC-008 is amended in spec.md to incorporate rubber-stamp rate as a measurable outcome (currently it measures "verifiable effort saved" and "zero artifacts the developer would have caught manually"). If SC-008 is widened to include rubber-stamp rate, the measurement chain previously proposed in this LOG (wall-clock-delta sidecar field + Branch A/B segmentation) becomes a candidate V2 ADR.
3. A second developer adopts `/speckit.run` and reports an impression-based concern about the no-findings banner (a concrete external signal).

## Why This Stays Open in V1

The dissent is real and preserved in the audit trail. Closing this LOG would require either:

- Demonstrating the dissent was resolved (it wasn't — it was set aside pending V2 measurement infrastructure), or
- Accepting ADR-023's mitigation as proven (it isn't — it was accepted as the smallest-surface intervention).

Marking it Open with explicit V2 trigger conditions preserves the dissent without inventing V1 instrumentation that the project context cannot support.

---

## Resolution Pointers

This LOG resolves when one of:

1. **A V2 ADR introduces rubber-stamp-rate measurement** (per a SC-008 amendment) and the resulting data either confirms or refutes the no-findings degradation hypothesis.
2. **V2 redesigns the BLOCKING checkpoint surface entirely** (e.g., conversational-checkpoint flow) — close this LOG by reference to that V2 ADR.
3. **The dogfooding context ends** (per V2 trigger #1) and an impression-based developer review of the banner concludes either way.
