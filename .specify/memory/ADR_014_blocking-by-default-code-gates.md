# ADR-014: BLOCKING-by-Default at Code-Action Gates in V1

**Date**: 2026-04-26
**Status**: Proposed (amended 2026-04-26 post-second-spec-review for non-code BLOCKING UX)
**Decision Made In**: specs/010-autonomous-workflow/spec.md § (post-spec-review revision); supersedes FR-014 in its current form
**Related Logs**: LOG-005 (stage-pair runner fallback)

---

## Context

FR-014 in the original spec defaults all checkpoints to OBSERVING mode (write decision file, continue without pause) when a developer invokes a full autonomous pipeline run. This includes the gates immediately before code-writing stages: `pre-implement`, `pre-codereview`, `pre-audit`. The /speckit.review spec gate surfaced this as the highest-risk decision in the spec.

Cost asymmetry is severe. OBSERVING saves ~30 seconds of human time per checkpoint. A wrong implementation across 20 files costs 30+ minutes to triage and possibly an hour to redo. The branch-scoped sandbox (ADR-012) prevents catastrophe (no force-push, no main edits) but does nothing to prevent garbage commits on the feature branch. The post-hoc "review checkpoint files" workflow (US-3, SC-005) is aspirational — it depends on the developer reading files cover-to-cover after every successful run, which there is no evidence they will do.

Both reviewers agreed FR-014's default was wrong. PS recommended inverting the default (BLOCKING at code gates, OBSERVING opt-in). DA recommended dropping the dual-mode entirely from V1. The synthesis-judge ruled to drop the dual-mode in V1, consistent with the V2-deferral of US-3 (ADR-015).

## Decision

In V1, all code-action checkpoints (`pre-implement`, `pre-codereview`, `pre-audit`) are BLOCKING. The pipeline pauses, presents the checkpoint summary, and waits for explicit `proceed` or `abort` before continuing. There is no OBSERVING mode in V1; the dual-mode `OBSERVING|BLOCKING` infrastructure (FR-013, FR-014) is removed from V1 scope.

Non-code checkpoints (`pre-plan`, `pre-tasks`) remain BLOCKING-by-default in V1 as well, because V1 has no OBSERVING mode at all. Checkpoint *files* (FR-015) are deferred to V2 alongside the OBSERVING capability.

OBSERVING mode and checkpoint-decision-file production return in V2 alongside US-3's learning loop; that re-introduction will land with empirical evidence about which gates are safe to skip.

**Amendment (2026-04-26): non-code BLOCKING UX semantics.** Code-gate BLOCKING is justified by cost asymmetry of bad commits; non-code-gate BLOCKING (`pre-plan`, `pre-tasks`) is justified differently — it gives the developer a structured mid-run checkpoint to inspect spec/plan artifacts before the next stage commits the orchestrator to a direction. The user-visible semantics at non-code gates:

- **What is presented**: the previous stage's primary artifact path (e.g., `spec.md`, `plan.md`), a one-line outcome summary (status from the subagent's decision-log entry), and the next stage's name. No artifact preview is rendered inline; the developer reads the file directly if they want detail.
- **Allowed actions**: `proceed` (continue to next stage), `abort` (halt the run; sentinel written per FR-027). Editing the artifact mid-pause is **permitted** — the developer may open `spec.md` or `plan.md` in their editor, save changes, and then `proceed`. The orchestrator does not re-run the previous stage; it dispatches the next stage against whatever is on disk at proceed-time.
- **Abort behavior at non-code gates**: artifacts written by completed stages are **retained** on disk (they are part of the audit trail per FR-005/ADR-013). The run-lock and sentinel are atomically removed on abort (per FR-027). The developer can re-trigger `/speckit.run` later; resume detection (FR-026) determines whether to continue from the existing artifacts or start fresh.

This addresses the second-spec-review C-1 finding (BLOCKING semantics at non-code gates undefined) without re-introducing OBSERVING. The single-mode V1 model holds; only the *behavior* at the pause is now spelled out.

## Alternatives Considered

### Option A: Drop dual-mode entirely in V1; BLOCKING everywhere *(chosen)*

V1 ships single-mode (BLOCKING). FR-013, FR-014, FR-015, US-3 all defer to V2.

**Pros**: Smallest V1 surface (Principle II compliance). Eliminates the highest-risk default in the spec. Defers checkpoint-file infrastructure until US-3's learning loop is being built (the only consumer that needs them). Clean re-introduction path in V2.
**Cons**: Loses the "developer can configure per-checkpoint mode" flexibility for V1. Loses OBSERVING for non-code gates where it might be safe (e.g., pre-tasks).

### Option B: Invert default — BLOCKING at code gates, OBSERVING elsewhere

Keep dual-mode; flip FR-014's default at the three code gates only. `--full-yolo` flag opts back into all-OBSERVING.

**Pros**: Preserves US-3's checkpoint-file value while eliminating the unsafe default. Allows OBSERVING for safe-ish gates.
**Cons**: Keeps the dual-mode surface (more code, more spec). US-3 deferral (ADR-015) makes the OBSERVING capability moot for V1 anyway. Adds a `--full-yolo` flag that has no V1 use case.

### Option C: Keep FR-014 as-is

Default OBSERVING everywhere; user adds BLOCKING per gate.

**Pros**: Maximum autonomy by default.
**Cons**: Highest-risk default per Phase A/B reviewer consensus; cost asymmetry argument is decisive.

## Rationale

Option A is consistent with the V2-deferral of US-3 (ADR-015). If the learning-loop infrastructure isn't shipping in V1, the OBSERVING/BLOCKING dual-mode has no V1 consumer. Shipping the dual-mode without a consumer is exactly the speculative infrastructure Principle II forbids.

Option B was the synthesis-judge's preferred ruling under the assumption US-3 stayed in V1. Once US-3 deferred, Option B reduces to "ship dual-mode that nobody uses in V1" — Option A is strictly cleaner.

## Consequences

**Positive**: Smaller V1 spec surface; eliminates the highest-risk default; defers a class of infrastructure (checkpoint files, dual-mode parser, OBSERVING-mode flow) until the learning-loop consumer exists. Aligns V1 with the trust-first goal hierarchy (ADR-015).
**Negative / Trade-offs**: V1 cannot run unattended through code-action stages — every code gate requires explicit human approval. Long pipelines require more wall-clock time because of human pauses. Power users who want unattended runs are blocked until V2.
**Risks**: V1 may feel "too cautious" and undersell the autonomous-pipeline value proposition. Mitigation: V1 still removes per-stage typing for non-code stages and bundles spec→review→clarify→plan→review→tasks under one invocation; the trust value is delivered first, the autonomy ceiling raises in V2.
**Follow-on decisions required**: V2 ADR for re-introducing OBSERVING mode with empirical-evidence requirements (which gates have proven safe).

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-26 | Initial record (post-spec-review judge ruling) | Claude (synthesis-judge for spec 010) |
| 2026-04-26 | Amended post-second-spec-review: added non-code BLOCKING UX semantics paragraph | Claude (synthesis-judge for spec 010 re-review) |
