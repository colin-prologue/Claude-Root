# ADR-012: Branch-Scoped Sandbox for Autonomous Code Actions

**Date**: 2026-04-25
**Status**: Accepted (amended 2026-04-26 post-second-spec-review for sentinel-file placement)
**Decision Made In**: specs/010-autonomous-workflow/spec.md § Clarifications (Q5); amended in second spec-review revision
**Related ADRs**: ADR-016 (sidecar at `.run/`)
**Related Logs**: LOG-009 (stale-lock recovery)

---

## Context

Spec 010 grants the orchestrator full autonomous execution including the `implement`, `codereview`, and `audit` stages (FR-012, originally clarified to Option B in the specify session). Subagents at those stages will write code and make commits without per-action human approval. Without a guardrail boundary defined in the spec, the worst failure modes are unbounded: committing secrets, force-pushing to remote, modifying `main`, deleting files outside the feature scope, modifying CI/CD or hooks.

The decision must be defensive enough to prevent catastrophic blast radius without being so restrictive that the orchestrator cannot do its job.

## Decision

Code-action subagents operate inside a branch-scoped sandbox.

**Allowed**: writing, editing, deleting files inside `specs/[###]/` and the project source tree; running tests; committing to the feature branch.

**Disallowed**: pushing to remote; modifying `main` directly; force operations of any kind (force-push, reset --hard against published commits, etc.); modifying `.gitignore` at runtime; modifying CI/CD configuration; modifying hooks or settings outside the feature scope.

Any disallowed action triggers a halt as a permission failure per ADR-011 (FR-019).

**Amendment (2026-04-26): runtime-process artifacts live under `specs/[###]/.run/`.** The orchestrator's runtime artifacts — sentinel files (`.run/run-lock`, `.run/abort`) and the orchestrator's control-flow sidecar (`.run/control-flow.log`, per ADR-016) — are placed under a per-feature `.run/` subdirectory. The disallow-list rule against runtime `.gitignore` modification is preserved: `specs/*/.run/` is declared once at template setup time (not per-run) so that runtime processes never need to touch `.gitignore`. This resolves the FR-020-vs-sentinel contradiction surfaced in the second spec-review (synthesis C-3) without weakening the runtime-modification prohibition. The cross-project artifact-leakage incident (PHI-006) reinforces this: process-lifecycle artifacts must have a placement that is unambiguous regardless of working directory or auto-compaction state.

## Alternatives Considered

### Option A: Full trust

Subagents have the same capabilities as Claude Code itself.

**Pros**: Maximum autonomy.
**Cons**: Maximum blast radius; one bad run can corrupt `main`, leak secrets, or destroy infrastructure config.

### Option B: Read-only outside feature

Subagents can write inside `specs/[###]/` and source tree only; everything else read-only including `.git` config, hooks, CI files.

**Pros**: Strong containment.
**Cons**: Doesn't differentiate local feature-branch commits (safe) from remote pushes (consequential); blocks legitimate operations like committing.

### Option C: Branch-scoped sandbox *(chosen)*

Write inside feature branch (commits OK); no push, no `main` touches, no force operations, no CI/hook/`.gitignore` modifications.

**Pros**: Restrictive enough to prevent disasters; permissive enough for the orchestrator to do meaningful work; recoverable failure mode (everything is local until the developer decides to push).
**Cons**: Disallow list must be maintained as new categories of risky operations emerge; sandbox enforcement requires hooks or wrapper logic.

### Option D: Defer to checkpoint policy

No hard guardrails; rely on the developer to set BLOCKING checkpoints before risky stages.

**Pros**: Maximum configurability.
**Cons**: Pushes safety burden onto the developer; default behavior is unbounded; relies on humans remembering to gate every risky stage.

## Rationale

Option C aligns the sandbox boundary with what is actually recoverable: anything done on a feature branch locally can be reset, rebased, or abandoned. Anything that escapes to remote, touches shared branches, or rewrites history is much harder to recover from. Locking the sandbox at exactly the recoverability boundary gives the orchestrator full freedom to fail safely.

The disallow-list approach is preferred over an allowlist because the categories of "safe operations" (read, edit, create, commit) are open-ended and frequently extended; the categories of "catastrophic operations" (push, force-anything, modify shared infrastructure) are smaller and more stable.

## Consequences

**Positive**: Worst-case blast radius is bounded to a discardable feature branch; developer retains full control over remote and `main`; clear default expectation for code-action subagents.
**Negative / Trade-offs**: Disallow-list maintenance burden as new risky operations emerge (e.g., new git operations, new third-party tools); sandbox enforcement adds implementation complexity; legitimate workflows that need to touch CI/`.gitignore` will require explicit override (out of scope for V1).
**Risks**: A disallowed operation that isn't on the list could slip through. Mitigation: enforce via tool-level allowlist where possible (PreToolUse hook for git operations); audit subagent commits before any human pushes them.
**Follow-on decisions required**: Planning-phase decision on enforcement mechanism (hook-based interception, prompt-only constraint, both); planning-phase decision on how to handle subagent attempts at disallowed actions (immediate halt vs. silent rejection with continuation); future ADR if the disallow list needs amendment.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-25 | Initial record | Claude (clarification session for spec 010) |
| 2026-04-26 | Amended post-second-spec-review: declared `specs/[###]/.run/` placement for runtime artifacts (sentinels + ADR-016 sidecar); template-time `.gitignore` setup preserves runtime-modification prohibition | Claude (synthesis-judge for spec 010 re-review) |
