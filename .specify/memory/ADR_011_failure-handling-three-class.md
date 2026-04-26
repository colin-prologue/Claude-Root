# ADR-011: Three-Class Subagent Failure Handling with Auto-Resume on Temporal Failures

**Date**: 2026-04-25
**Status**: Accepted
**Decision Made In**: specs/010-autonomous-workflow/spec.md § Clarifications (Q4)
**Related Logs**: None

---

## Context

A long-running pipeline of subagent dispatches will encounter failures of qualitatively different kinds: transient API rate limits, malformed subagent outputs, tool-permission denials, subagent context exhaustion, and unrecoverable errors. Treating all failures uniformly produces either silent retry loops (auto-retry everything) or wedged pipelines on benign transient issues (halt on everything). Both are user-hostile.

Rate-limit waits and context-window-refresh waits are categorically different from semantic failures: the work is fine, the resource is temporarily unavailable. A 4-hour rate-limit wait is plausible on busy days and may exceed the developer's session lifetime, requiring auto-resume to survive across sessions.

## Decision

Subagent failures are classified into three classes, each handled distinctly:

1. **Temporal failures** — rate-limit responses, context-window-refresh waits. Pause and auto-resume when the resource becomes available, honoring any retry-after duration the API provides. Long waits MUST survive developer-session boundaries by leveraging the same on-disk pipeline state used for FR-007 resume.
2. **Semantic failures** — missing artifact, malformed subagent summary, contract violation. Halt; write structured failure entry to decision log; require explicit developer re-trigger.
3. **Permission and exhaustion failures** — tool denial, subagent context exhausted, unrecoverable error. Halt; log; require explicit re-trigger.

No automatic retry on indeterminate errors.

## Alternatives Considered

### Option A: Auto-retry once, then halt

Single retry on any failure.

**Pros**: Catches transient errors automatically.
**Cons**: Doesn't distinguish temporal from semantic — semantic failures get a wasted retry; doesn't address the rate-limit-wait case where the right behavior is *wait*, not *retry now*.

### Option B: Halt on everything

Any failure halts; developer re-triggers manually.

**Pros**: Simplest model; no surprises.
**Cons**: Pipeline wedges on benign rate-limit responses; user has to manually shepherd what should be a hands-off run.

### Option C: Differentiated handling

Transient errors auto-retry; semantic errors halt; permission denials halt.

**Pros**: Treats different failure modes differently.
**Cons**: "Auto-retry on transient" doesn't fit rate-limit semantics — rate limits need a *wait* with a known duration, not an instant retry.

### Option D: Three-class with auto-resume on temporal *(chosen)*

Refinement of B + C with explicit pause-and-auto-resume for rate-limit-driven waits.

**Pros**: Each failure class gets the appropriate response; rate-limit waits don't wedge the pipeline; semantic failures still halt for human review; no silent retry loops.
**Cons**: Auto-resume across session boundaries requires non-trivial state-survival mechanism; classification logic must be correct to avoid misrouting.

### Option E: Best-effort continue

Log failure and try the next stage anyway.

**Pros**: Pipeline always completes.
**Cons**: Downstream stages will produce garbage when their inputs are broken; defeats the value of having a pipeline.

## Rationale

The user surfaced the rate-limit-pause concern explicitly: "we will likely run out of tokens from time to time — could we pause and autoresume when the window refreshes?" That use case is real, common, and ill-served by either blanket halt or instant retry. Three-class classification is the minimum granularity that handles it correctly while keeping semantic failures loud (which the user wants — they explicitly want to learn from bad judgment calls per SC-005).

## Consequences

**Positive**: Pipeline survives normal-day rate limits without manual babysitting; semantic failures remain visible and require explicit human attention; permission failures halt loudly so the developer knows to fix permissions, not retry.
**Negative / Trade-offs**: Auto-resume across session boundaries requires non-trivial state mechanism; classification logic is a new failure surface (a misclassified failure halts the wrong way).
**Risks**: A semantic failure misclassified as temporal would create a silent retry loop. Mitigation: temporal classification is whitelist-based (specific API error codes / signals), not heuristic; anything not on the whitelist falls through to halt.
**Follow-on decisions required**: Planning-phase decision on the resume mechanism (ScheduleWakeup, scheduled trigger, manual re-trigger after wake); planning-phase decision on temporal-failure whitelist (specific error codes / signals that qualify); planning-phase decision on max wait duration before escalating a temporal failure to halt.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-25 | Initial record | Claude (clarification session for spec 010) |
