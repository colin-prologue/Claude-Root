# LOG-010: Non-Code-Stage Claimed-vs-Actual Artifact Validation Deferred

**Date**: 2026-04-26
**Type**: CHALLENGE
**Status**: Deferred
**Raised In**: specs/010-autonomous-workflow plan-gate review (Phase B, devil's advocate F-09 expansion)
**Related ADRs**: ADR-023 (pre-route linter postcheck — V1 scope), ADR-019 (deterministic core boundary)

---

## Description

ADR-023 ships a pre-route postcheck (`run-postcheck.sh`) that audits a code-action subagent's claims against the actual repository state before the orchestrator routes. The V1 scope is **code-action stages only** (`implement`, `codereview`, `audit`).

Non-code stages (`specify`, `plan`, `tasks`) are **not** validated for claim/actual consistency in V1. A `tasks` subagent that claims to have produced `tasks.md` with N task entries while writing only N-1 entries will not be caught at the gate; the discrepancy surfaces only when a downstream stage reads the file or when the developer notices.

This LOG records the deferred work and the conditions under which V1's scope decision should be revisited.

## Context

Plan-gate review of feature 010 surfaced two related findings:
- F-09 (delivery-reviewer): the orchestrator does not currently audit subagent-claimed artifacts against repository state. Risk concentrated at code-action stages because they produce the records future audits reason from.
- Devil's advocate Phase B (rubber-stamping reframe): BLOCKING checkpoints address the *decision* surface but not the *artifact* surface; the developer needs pre-checked findings to react to.

The fix landed as ADR-023 with code-action scoping. Non-code stages were considered in Option C of ADR-023 and rejected for V1 because:
1. The existing project linters (`check-adr-crossrefs.sh`, `check-prerequisites.sh`) cover the cross-references and file-existence properties of non-code artifacts.
2. The remaining claim/actual properties for non-code stages (e.g., "spec.md FR count matches the claimed count in the decision-log entry") have no existing linter; building one is V2 work.
3. V1 risk concentrates on the code-action surface (audit-substrate contamination via `implement`/`codereview`/`audit` records).

## Discussion

### Pass 1 — Initial Analysis

Non-code stages produce markdown artifacts the developer reads and reviews. The delta between claim and reality is usually visible in a file the developer is about to inspect anyway. The risk-vs-cost ratio of shipping a V1 validator for those stages is unfavorable: most contamination paths route through code-action stages because that's where the audit substrate is generated.

### Pass 2 — Critical Review

The devil's advocate's reframe (V1 is the project's first orchestrator that builds itself) cuts the other way too: a `tasks.md` with phantom test entries propagates into `implement`'s working set, then into `codereview`'s reasoning. The non-code stage's silent contamination becomes the code-action stage's premise.

Counter-argument: the code-action postcheck (ADR-023) catches the downstream effect — `implement` claiming to have written `test_X.bats` when no such file exists is a postcheck failure regardless of whether the upstream `tasks.md` was the true source of the phantom entry. The check at the right layer suffices for V1.

### Pass 3 — Resolution Path

Defer. Re-evaluate at one of two trigger conditions:
- Dogfooding evidence (per SC-008) shows non-code stage contamination making it past code-action postchecks. This would mean the right-layer-check argument is wrong empirically.
- A developer-experience friction emerges (BLOCKING-checkpoint payloads grow noisy because every code-action stage repeats validation that should have happened upstream).

Either trigger justifies the V2 work of building a non-code-stage validator (likely a `run-postcheck.sh` invocation extension with stage-specific check sets).

## Resolution

Deferred to V2. V1 ships ADR-023 with code-action scoping. This LOG remains Open as the tracking record for the V2 follow-on; SC-008's 30-day evaluation is the primary trigger for revisiting.

**Resolved By**: Deferred — V2 follow-on tracked here.
**Resolved Date**: N/A

## Impact

- [X] Plan updated: specs/010-autonomous-workflow/plan.md (Decision Records table includes ADR-023 + this LOG)
- [X] ADR created/updated: ADR-023 (V1 scope locked to code-action stages; this LOG referenced as the deferred work)
- [ ] Tasks revised: N/A (V1 task list reflects ADR-023 scope; V2 work is out of scope for the current `tasks.md`)
