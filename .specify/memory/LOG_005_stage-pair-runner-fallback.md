# LOG-005: Stage-Pair Runner as V1.5 Fallback

**Date**: 2026-04-26
**Type**: CHALLENGE
**Status**: Open
**Raised In**: specs/010-autonomous-workflow/spec.md § /speckit.review spec gate (Phase B devils-advocate)
**Related ADRs**: ADR-008 (`/speckit.run` trigger), ADR-015 (V1 scope boundary)

---

## Description

During the spec gate review, the devils-advocate raised the strongest dissent: reject this spec entirely and replace it with a smaller "stage-pair runner" — a command that runs the *next* stage, presents results, and one-click-confirms to proceed to the *next-next* stage. No multi-stage autonomy across more than two stages, no decision-log artifact, no checkpoint dual-mode, no auto-resume. The argument: solves ~80% of the typing friction with ~5% of the spec surface and zero Principle II violations.

The synthesis-judge ruled in favor of the middle path (ADR-015 trust-first scope cut) rather than full replacement. This LOG preserves the stage-pair-runner alternative as a V1.5 fallback option in case V1 proves untrustworthy in dogfooding.

## Context

This challenge surfaced after Phase A and during the Phase B consensus-challenge protocol of the spec gate review. The user's clarification answers (Q3, Q4, Q5) repeatedly chose safer options, supporting the DA's framing that trust — not friction — is the user's actual bottleneck. The stage-pair runner is the minimal expression of friction-removal that does not require trust-building infrastructure.

## Discussion

### Pass 1 — Initial Analysis

The DA's argument has three parts: (a) the user has not proven friction is the bottleneck, (b) the user's clarifications repeatedly chose the safer option, (c) Principle II forbids speculative infrastructure. The conclusion: ship a stage-pair runner that removes the typing friction without adding orchestrator infrastructure that hasn't earned its keep.

### Pass 2 — Critical Review

The product-strategist Phase B response rejected the stage-pair runner as the V1 path: it forfeits the multi-stage value proposition entirely; the decision-log artifact (US-2) is the user's stated trust mechanism, and a two-stage runner doesn't produce one; deferring V2 by one cycle doesn't solve the trust problem, only postpones it.

The synthesis-judge sided with the middle path (ADR-015): keep US-1, US-2, US-4 in V1 with BLOCKING gates and no learning loop; preserve the stage-pair runner as a fallback if the middle path fails in dogfooding.

### Pass 3 — Resolution Path

Open this LOG to record the DA's proposal verbatim. If V1 ships per ADR-015 and dogfooding reveals the orchestrator's autonomous decisions are systematically wrong (high override rate, frequent semantic failures, low developer trust in resulting artifacts), fall back to the stage-pair runner as V1.5 before iterating to V2 full autonomy. The fallback path: defer FR-001/FR-002 (multi-stage execution), keep FR-016 (`/speckit.run` slash command) but redefine it to run only the *next* stage, simplify decision log to a per-stage transition record.

## Resolution

Deferred. Status remains Open until V1 dogfooding produces evidence about whether the orchestrator's autonomous decisions are trustworthy.

**Resolved By**: Pending V1 dogfooding evidence
**Resolved Date**: N/A

## Impact

- [ ] Spec updated: specs/010-autonomous-workflow/spec.md (referenced in Decision Records table as alternative)
- [ ] Plan updated: N/A
- [x] ADR created/updated: ADR-015 (V1 scope boundary, references this LOG)
- [ ] Tasks revised: N/A
