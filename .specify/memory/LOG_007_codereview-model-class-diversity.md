# LOG-007: Codereview Model-Class Diversity for Autonomous Pipeline

**Date**: 2026-04-26
**Type**: QUESTION
**Status**: Open
**Raised In**: specs/010-autonomous-workflow/spec.md § /speckit.review spec gate (Phase A devils-advocate blind spot M-4)
**Related ADRs**: ADR-009 (subagent-per-stage execution)

---

## Description

The /speckit.run autonomous pipeline includes `codereview` as a stage that follows `implement`. The implicit safety claim is that codereview provides independent verification of implement's work — catching bugs, missed requirements, and ADR violations before audit and merge. This claim depends on the codereview subagent being independent enough from the implement subagent to produce diverse findings.

Both stages run on the same model class (e.g., Claude Sonnet 4.6 or 4.7) with similar context windows and similar training distributions. Empirical evidence from the review-panel benchmark suggests same-model reviewers produce correlated findings, not independent verification. Without diversity of reasoning, autonomous codereview may rubber-stamp autonomous implement's output, defeating the safety mechanism.

## Context

Raised by devils-advocate Phase A (blind spot M-4) during spec gate review. The reviewer noted no explicit diversity-of-reasoning argument exists in the spec for autonomous codereview's safety claim. The synthesis-judge promoted this to a MED-severity minority finding.

This question matters for V2 expansion (when US-3 and learning loop return) and for any future "expand autonomous code-action gates to OBSERVING" decision. If V2 evidence shows codereview rubber-stamps implement, the OBSERVING expansion path is closed.

## Discussion

### Pass 1 — Initial Analysis

Independent review requires either (a) a different model providing the review, (b) a different prompt structure that elicits different reasoning patterns, or (c) a different evaluation rubric that catches what the writer's rubric missed. Same-model + same-prompt-pattern + same-rubric is unlikely to surface bugs the writer didn't already consider.

### Pass 2 — Critical Review

Three candidate diversification strategies:

**Strategy A: Different model class.** Run implement on Sonnet, codereview on Opus (or vice versa). Highest diversity; highest cost.

**Strategy B: Different prompt structure.** Same model, but codereview prompt explicitly inverts the writer's rubric (e.g., "find the things this code assumes are true that aren't" rather than "review for correctness"). Lower cost; uncertain effectiveness.

**Strategy C: Different evaluation rubric only.** Codereview agent definition includes explicit anti-rubber-stamp prompts and a forced-skepticism protocol (similar to devils-advocate's anti-convergence pattern in the review panel). Lowest cost; may not be sufficient.

**Strategy D: Accept the limitation; rely on audit + manual gate.** Codereview is a soft check; the manual review at PR time is the real gate. Spec acknowledges this by reducing the safety claim's strength.

### Pass 3 — Resolution Path

Resolution requires V1 dogfooding evidence: dispatch implement and codereview subagents on a series of fixtures and measure (a) how often codereview finds issues implement missed, (b) how often codereview's findings overlap with the implementation's known issues. If overlap is high (rubber-stamp), implement Strategy A or B in V2. If overlap is low, codereview is providing independent value at current cost.

## Resolution

Pending V1 dogfooding evidence.

**Resolved By**: V1 dogfooding measurement
**Resolved Date**: N/A

## Measurement Protocol (V1 dogfooding)

To produce evidence that resolves this LOG, capture the following per codereview run during V1 dogfooding (per SC-008's ≥5 runs over 30 days):

| Field | Definition |
|---|---|
| `run_id` | Identifier of the pipeline run (matches the run-lock session id) |
| `feature_id` | Feature spec number (e.g., `010-autonomous-workflow`) |
| `implement_findings_known` | List of issues the developer or implement subagent already flagged (in commit messages, decision-log entries, or implement-stage halt directives) |
| `codereview_findings_raised` | List of findings codereview produced |
| `findings_overlap_count` | Number of `codereview_findings_raised` that match items in `implement_findings_known` |
| `findings_novel_count` | Number of `codereview_findings_raised` not present in `implement_findings_known` |
| `findings_novel_actionable_count` | Of the novel findings, how many addressed defects the developer would have shipped without them |
| `findings_novel_pr_redundant_count` | Of the novel findings, how many the developer would have caught at PR-time review anyway |
| `model_class` | Model class used (e.g., `claude-sonnet-4-6`) |

**Interpretation thresholds** (after ≥5 runs):

- `findings_novel_actionable_count` ≥ 1 across at least 3 of 5 runs ⇒ codereview is providing independent value at current cost; **no V2 diversification needed**.
- `findings_novel_actionable_count` = 0 across 4+ runs AND `findings_overlap_count` ≥ 2 across the same runs ⇒ codereview is rubber-stamping; **V2 ADR for diversification strategy** (different model class, different prompt, or accept-the-limitation per Strategy D).
- Mixed signal ⇒ extend measurement to 10 runs before deciding.

This protocol is the substrate for the ADR-017 smoke tier (Tier 2): the same fixture runs that verify the orchestrator-subagent contract also produce the codereview-vs-implement findings overlap data needed to resolve this LOG. No separate dogfooding harness required.

## Impact

- [x] Spec updated: spec 010 lists this LOG as Open (V1 dogfooding measurement) in Decision Records table
- [x] Measurement protocol defined (this LOG, 2026-04-26)
- [ ] Plan updated: smoke-tier fixture selection (per ADR-017) should record the fields above for each codereview run
- [ ] ADR created/updated: TBD V2 (if measurement shows rubber-stamp, ADR for diversification strategy)
- [ ] Tasks revised: N/A in V1

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-26 | Initial record (spec-gate review M-4) | Claude (synthesis-judge for spec 010) |
| 2026-04-26 | Added measurement protocol with capture template and interpretation thresholds; tied to ADR-017 smoke tier | Claude (plan-phase resolution pass for spec 010) |
