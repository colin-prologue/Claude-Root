# ADR-018: Stale-Lock Recovery — `--break-lock` Only in V1

**Date**: 2026-04-26
**Status**: Proposed
**Decision Made In**: specs/010-autonomous-workflow/ (plan-phase resolution of LOG-009)
**Related ADRs**: ADR-012 (branch-scoped sandbox; `.run/` placement), ADR-015 (V1 scope boundary), ADR-016 (canonical/derivative model)
**Related Logs**: LOG-009 (closes)

---

## Context

FR-028 specifies that the orchestrator writes a lock file at `specs/[###]/.run/run-lock` containing its session identifier and a creation timestamp at the start of each dispatch, and removes the lock at clean termination. LOG-009 surfaced the unclean-termination case: a crashed orchestrator session (killed shell, OS crash, compactor interrupt) leaves the lock orphaned. Subsequent invocations halt as permission failures with no documented escape.

Three resolution shapes were considered in LOG-009:

1. **TTL-based**: lock contains creation timestamp; orchestrator considers any lock older than N minutes (e.g., 60) stale and deletes it before proceeding.
2. **PID-aliveness check**: lock contains the session identifier; the orchestrator probes whether that session is still alive.
3. **`--break-lock` flag**: orchestrator halts cleanly when a stale lock is encountered, surfaces the lock contents to the developer, and offers an explicit `/speckit.run --break-lock` command to clear it.

V1's posture (ADR-014 BLOCKING-everywhere; ADR-015 single-session lifecycle) means a stale lock is always either (a) the developer's own crashed session, which they are aware of, or (b) genuinely rare. Cross-session resume is V2 (ADR-015) and only at that point does a true "abandoned by another session" case materialize.

## Decision

V1 ships **`--break-lock` only**. When the orchestrator encounters a lock from a different session, it:

1. Halts as a permission failure per FR-019.
2. Surfaces the lock contents to the developer: file path, recorded session id, creation timestamp.
3. Refuses to proceed without an explicit `/speckit.run --break-lock` invocation.
4. On `--break-lock`, atomically removes the lock and the abort sentinel (if any), records the break event in the orchestrator's sidecar at `specs/[###]/.run/control-flow.log` (per ADR-016), and continues.

No TTL. No PID-aliveness probe. The developer is the recovery mechanism.

This codifies the interim posture already noted in FR-028 as the permanent V1 design.

## Alternatives Considered

### Option A: TTL-based stale detection

Lock auto-staleness based on creation timestamp + N minutes.

**Pros**: Hands-off recovery; no developer intervention.
**Cons**: Introduces a new failure class — concurrent-steal of a healthy long-running stage. The codereview and audit stages can legitimately exceed any reasonable TTL when the diff under review is large. V1 has no other guardrail against this failure class. Choosing N is itself a research question with no good default.

### Option B: PID-aliveness check

Lock-recorded session id is probed for liveness; dead session ⇒ stale.

**Pros**: Avoids TTL's concurrent-steal problem when the session is genuinely dead.
**Cons**: "Session alive" detection in a Claude-Code-managed session is unreliable — auto-resume, compaction, and process re-parenting break naive `kill -0` or PID checks. Cross-machine reuse breaks by design (a lock from one machine cannot be probed from another). Implementing this requires picking a definition of "alive" that doesn't have a clean answer in the current Claude Code lifecycle model.

### Option C: `--break-lock` only *(chosen)*

Developer-in-the-loop recovery with surfaced lock contents.

**Pros**: Lowest false-positive rate (the developer judges whether the lock is genuinely stale). Lowest implementation surface — no probe, no timer, just a flag. Matches V1's BLOCKING-everywhere safety posture (developer is in the loop at every gate; one more gate at recovery time is consistent). The lock contents surface gives the developer the information needed to judge (creation time, session id) without forcing them to inspect the file by hand.
**Cons**: One extra command on every recovery. Developer must judge — a non-technical user might not know what to do with the surfaced session id. Acceptable for V1 because the only V1 user is the project's developer (solo workflow).

### Option D: Hybrid — PID-aliveness with `--break-lock` fallthrough

Try PID probe first; fall through to `--break-lock` prompt if probe is ambiguous.

**Pros**: Hands-off in the common case; safe fallback.
**Cons**: Requires the unreliable PID-aliveness implementation as a prerequisite. The "ambiguous" case is undefined and likely the common case (compaction, auto-resume). Effectively becomes Option C in practice but with extra implementation surface.

## Rationale

V1 is a single-session, BLOCKING-everywhere, trust-first orchestrator (ADR-014, ADR-015). One more developer-in-the-loop moment at recovery time is consistent with the rest of the design. The TTL and PID-aliveness options solve a problem (autonomous recovery) that V1 isn't trying to solve.

The `--break-lock` flag also generalizes cleanly: when V2 introduces cross-session resume, `--break-lock` becomes the *manual* override path, and an *automatic* path (TTL or PID-aliveness, whichever the V2 evidence supports) lands on top of it. V1's choice doesn't preclude V2; it postpones the harder question to the point where there's evidence to answer it.

The lock contents surface (file path, session id, creation timestamp) is information-only — the developer is not asked to parse the file themselves. The `/speckit.run` command help documents the meaning of each field.

## Consequences

**Positive**: Plan-phase blocker (LOG-009) closes. Smallest possible implementation surface. No new failure class introduced. Cleanly extensible in V2.

**Negative / Trade-offs**: Every recovery requires a developer command. Solo-dev V1 user can absorb this; future multi-user contexts (V2+) will likely demand automation.

**Risks**:
- `--break-lock` becomes annoying enough in dogfooding that the developer stops running the orchestrator — mitigation: SC-008's 30-day usage floor surfaces this. If `--break-lock` annoyance is the limiter, V2 picks an automation strategy; if not, V1 ships as-is.
- Developer breaks a lock that was actually held by a healthy session (e.g., long-running implement stage on a separate terminal) — mitigation: lock contents surface includes creation timestamp, which a developer can compare against their own awareness of running processes; the BLOCKING posture means there is at most one orchestrator per feature anyway.

**Follow-on decisions required**:
- V2 ADR for automated stale-lock recovery once cross-session resume requires it. Evidence base: V1 dogfooding logs of `--break-lock` invocations and their causes (genuine crash vs. healthy-but-paused session).

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-26 | Initial record (closes LOG-009) | Claude (plan-phase resolution for spec 010) |
