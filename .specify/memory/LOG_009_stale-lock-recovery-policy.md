# LOG-009: Stale-Lock Recovery Policy

**Date**: 2026-04-26
**Type**: Question
**Status**: Resolved (ADR-018 — 2026-04-26)
**Raised In**: specs/010-autonomous-workflow/spec.md § FR-028 (post-second-spec-review revision)
**Related**: ADR-012 (sandbox), ADR-016 (sidecar at .run/)

---

## Question

What is the recovery path when `specs/[###]/.run/run-lock` is left orphaned by a crashed orchestrator session?

The second spec-gate review (Phase A finding F-05; Phase C C-5) flagged that FR-028's "lock removed at clean termination" leaves no recovery path for the unclean-termination case. A crashed main session, killed shell, or compactor that interrupted the orchestrator leaves the lock file in place; future invocations against that feature halt as permission failures with no documented escape.

Three resolution shapes are plausible; the plan phase must pick one before implementation begins:

1. **TTL-based**: lock contains a creation timestamp; orchestrator considers any lock older than N minutes (e.g., 60) stale and deletes it before proceeding. Risk: a long-running stage exceeds N and a concurrent invocation steals the lock from a healthy session.

2. **PID-aliveness check**: lock contains the session identifier (already specified) and the orchestrator checks whether that session is still alive. Risk: in a Claude-Code-managed session, "alive" detection may not be reliable across compaction/auto-resume; cross-machine reuse breaks.

3. **`--break-lock` flag**: orchestrator halts cleanly when a stale lock is encountered, presents the lock contents (creation time, session id) to the developer, and offers an explicit `/speckit.run --break-lock` command to clear it. Risk: extra step on every recovery; developer must read the lock contents to make a judgment call.

## Context for Plan Phase

V1 ships with single-session lifecycle (ADR-015 defers cross-session resume to V2). In V1, a stale lock is always either (a) the developer's own crashed session or (b) very rare. Option 3 (`--break-lock` with developer in the loop) has the lowest false-positive rate and matches V1's BLOCKING-everywhere safety posture. Option 1 (TTL) is more hands-off but introduces a new class of failure (concurrent steal of healthy lock) that V1's other guardrails do not protect against.

A pragmatic V1 default may combine Options 2 and 3: PID-aliveness check first; if ambiguous, fall through to `--break-lock` developer prompt. This is a plan-phase implementation decision, not a spec-phase requirement.

## Resolution Trigger

Plan phase author selects an option (or hybrid) and writes ADR-017 with the rationale. This LOG closes when ADR-017 is created.

## Resolution

Option 3 (`--break-lock` only) chosen for V1. ADR-018 codifies developer-in-the-loop recovery: orchestrator halts on stale lock, surfaces lock contents (file path, session id, creation timestamp), and refuses to proceed without an explicit `/speckit.run --break-lock` invocation. No TTL, no PID-aliveness probe — those options introduced new failure classes or unreliable detection that V1 isn't equipped to handle. The `--break-lock` flag generalizes cleanly to V2 as the manual override alongside whatever automation the V2 evidence base supports.

**Resolved By**: ADR-018 (2026-04-26 plan-phase decision)
**Resolved Date**: 2026-04-26

> Note: ADR-017 was originally reserved by this LOG for the stale-lock decision; the actual numbering allocates ADR-017 to LOG-006's TDD strategy (resolved in the same plan-phase pass) and ADR-018 to this LOG. Sequential allocation by resolution order, not by LOG number.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-26 | Opened during spec-gate re-review (Phase C synthesis recommendation) | Claude (synthesis-judge for spec 010 re-review) |
