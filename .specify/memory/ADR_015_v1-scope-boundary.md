# ADR-015: V1 Scope Boundary — Trust First, Defer Learning Loop and Temporal Auto-Resume

**Date**: 2026-04-26
**Status**: Accepted (amended 2026-04-26 post-second-spec-review for SC-008 + partial-write deferral)
**Decision Made In**: specs/010-autonomous-workflow/spec.md § (post-spec-review revision)
**Related Logs**: LOG-005 (stage-pair runner fallback), LOG-008 (decision-log unbounded growth), LOG-009 (stale-lock recovery)

---

## Context

The /speckit.review spec gate identified a Principle II Simplicity violation. As written, spec 010 introduces six new artifact types, ~20 functional requirements, an OBSERVING/BLOCKING dual-mode checkpoint system, three-class failure handling with auto-resume across developer-session boundaries, and a learning loop for guardrail discovery — all in a solo-developer template repo with no production users.

Devil's advocate framed the underlying tension: the spec conflates friction-removal (the surface goal) with trust-building (the user's clarification-evidenced goal). The user's clarification answers (Q3 audit-before-implement, Q4 halt-on-semantic-failure, Q5 sandbox) repeatedly chose the safer option when given a choice. This pattern points to trust as the dominant V1 goal.

The right V1 ships infrastructure that **earns** the trust required for V2's autonomy-expansion features. Building the learning loop before the orchestrator has demonstrated correct decisions inverts the dependency.

## Decision

V1 of `/speckit.run` ships a trust-first orchestrator with the following scope cuts:

**Deferred to V2 (in scope after V1 dogfooding produces evidence):**
- US-3 (Checkpoint Files for Learning) — deferred entirely
- FR-013, FR-014 (OBSERVING/BLOCKING dual-mode) — superseded by ADR-014 (BLOCKING-only V1)
- FR-015 (checkpoint decision file structure for learning) — deferred with US-3
- FR-018 (per-dispatch token telemetry in decision log) — deferred; LOG-004 follow-up moves to V2
- FR-019 *temporal auto-resume across developer-session boundaries* — V1 handles temporal failures with halt-and-explicit-retrigger; cross-session auto-resume is V2
- SC-005 (developer can identify incorrect judgment calls from checkpoint files) — depends on US-3, deferred
- ADR-013's partial-write recovery protocol ("append-only writes with terminal sentinel, orchestrator detects truncation") — deferred to V2 alongside cross-session resume. In V1's single-session lifecycle, a partial write is a visible main-session crash and recovery is manual cleanup; the terminal-sentinel protocol becomes load-bearing only when cross-session resume requires it.

**Retained in V1:**
- US-1 (Single-Trigger Pipeline Execution) — core value
- US-2 (Decision Log Review) — primary trust mechanism
- US-4 (Pipeline Resume After Interruption) — resume within a single session, not across sessions
- All FRs not listed as deferred above
- Branch-scoped sandbox (ADR-012)
- Subagent-per-stage execution (ADR-009)
- Stage-boundary log threshold (ADR-010, as amended by ADR-013)
- Three-class failure handling (ADR-011, modified: temporal class halts and requires explicit retrigger in V1; auto-resume is V2)

**Goal hierarchy (added to spec):**
1. Trust through legibility and observability (decision log, BLOCKING gates)
2. Friction removal within trust constraints

**V1-ship-or-retire predicate (added 2026-04-26 post-second-spec-review):**

The second spec-review (Phase B U-2 finding) flagged that SC-001..007 are run-level criteria — they tell us whether a single run succeeded, but not whether V1 *as a release* delivered enough evidence to justify V2 investment. SC-008 fills that gap:

- **SC-008**: After ≥5 full pipeline runs in V1 over a usage period of at least 30 days, the developer can report:
  - **(a)** at least one run where autonomous progression saved verifiable effort vs. manual stage-by-stage execution (completed without requiring more `proceed` interventions than a stage-pair runner would have demanded), AND
  - **(b)** zero runs where autonomous progression produced an artifact the developer would have caught and corrected by manual review.

- **Decision rule**: (a) never met across ≥5 runs over 30 days ⇒ retire `/speckit.run`; the value proposition is unproven. (b) violated even once ⇒ re-evaluate the BLOCKING-everywhere posture and trust-first hierarchy before any V2 expansion.

- **30-day usage floor**: the 5-run threshold without a time floor is gameable (5 throwaway runs on synthetic features in one afternoon would satisfy it). The 30-day floor ensures the runs reflect genuine feature-development cadence, not benchmark theatre.

This is the predicate that closes DA's preserved minority dissent ("V1 may not get used long enough to generate evidence"): if real-world usage doesn't materialize within 30 days, that dissent is empirically validated and `/speckit.run` retires in favor of LOG-005's stage-pair runner.

## Alternatives Considered

### Option A: V1 trust-first, defer learning loop + temporal auto-resume *(chosen)*

Ship ~12-FR V1; validate decision quality before building infrastructure to learn from poor decisions; re-introduce US-3 + OBSERVING + temporal auto-resume in V2 with V1 evidence.

**Pros**: Principle II compliant. V1 surface is small enough to dogfood cleanly. Each V2 feature lands with evidence rather than speculation. Aligns with user's clarification-evidenced trust-first preference.
**Cons**: V1 user experience is more constrained (BLOCKING at every code gate, no unattended runs across sessions). "Autonomous pipeline" value proposition is narrower in V1 than originally specced.

### Option B: Ship spec as written

Full ~20-FR scope including dual-mode, learning loop, temporal auto-resume.

**Pros**: Original V1 vision delivered.
**Cons**: Six new artifact types in one feature; speculative infrastructure (learning loop has no precedent and no implementation path); dangerous default at code gates; Principle II violation; high probability of expensive V1 rework when reality contradicts assumptions.

### Option C: Reject spec; replace with stage-pair runner

DA's strongest dissent — ship only "next stage → present → confirm → next stage" runner; defer multi-stage autonomy to V2 with V1 evidence.

**Pros**: Smallest possible surface. Strongest Principle II compliance. Lowest risk.
**Cons**: Forfeits the multi-stage value proposition entirely in V1; defers the trust-building artifact (decision log) that the user actually asked for; may be too small to learn anything useful from. Preserved as LOG-005 — V1.5 fallback if Option A fails in dogfooding.

## Rationale

Option A is the middle path between "ship everything" and "ship almost nothing." It honors Principle II by deferring speculative infrastructure (learning loop, temporal auto-resume across sessions) while preserving the core trust-mechanism value (decision log, BLOCKING gates, branch-sandbox).

The deferral pattern is deliberate: V1 produces decision-log artifacts that V2's learning loop will consume. Without V1 logs, V2 has no evidence base. The order matters — build the producer first, the consumer second.

The friction-vs-trust tension is resolved by declaring an explicit goal hierarchy in the spec: trust comes first, friction removal is bounded by trust.

## Consequences

**Positive**: V1 is shippable in a constrained scope (~12 FRs vs. ~20). Each V2 expansion lands with evidence. Risk surface for V1 is small enough to dogfood without cost-of-rework concerns. Aligns with user's clarification-evidenced safety preferences.
**Negative / Trade-offs**: V1 user experience requires manual `proceed` at every code gate; long pipelines cannot run unattended overnight. V2 must explicitly justify each re-introduction with V1 evidence (additional documentation overhead). The learning-loop value proposition is delayed by one release cycle.
**Risks**: V1 might feel "too small" to demonstrate the autonomous-pipeline value. Mitigation: V1 still bundles spec→review→clarify→plan→review→tasks under one invocation, which is the bulk of the developer's typing-friction relief. — V2 may not actually need OBSERVING mode if BLOCKING-everywhere proves acceptable in dogfooding. Mitigation: that's the point — let the V1 evidence shape V2 rather than guess now.
**Follow-on decisions required**: V2 ADRs for re-introducing OBSERVING (ADR-014 follow-up), re-introducing US-3 / FR-015 with concrete learning-loop implementation, re-introducing temporal auto-resume with kill-switch and concurrency-lock prerequisites.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-26 | Initial record (post-spec-review judge ruling) | Claude (synthesis-judge for spec 010) |
| 2026-04-26 | Amended post-second-spec-review: added SC-008 + 30-day usage floor as V1-ship-or-retire predicate; deferred ADR-013 partial-write recovery protocol to V2 | Claude (synthesis-judge for spec 010 re-review) |
