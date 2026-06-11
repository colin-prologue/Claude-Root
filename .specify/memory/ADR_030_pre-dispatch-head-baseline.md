# ADR-030: Pre-Dispatch HEAD as Per-Stage Diff Baseline

**Date**: 2026-05-25
**Status**: Accepted
**Decision Made In**: `.claude/commands/speckit.run.md` lines 60, 106 (post-audit addition)
**Related ADRs**: ADR-019 (deterministic orchestrator core), ADR-023 (pre-route postcheck)
**Related Logs**: LOG-027 (markdown orchestrator testability gap)

---

## Context

After each subagent dispatch, the orchestrator captures `git diff <baseline>..HEAD` into `.run/stage-diff-<stage>.{files,patch}` so a developer can independently audit what a subagent actually changed, rather than trusting the subagent's self-reported summary in `decisions-log.md`.

The baseline choice is non-obvious: options include the repo's initial commit, the start of the `/speckit.run` invocation, the HEAD at the end of the previous stage, or the HEAD immediately before this stage's dispatch. Each produces a different diff scope.

## Decision

The baseline is **`git rev-parse HEAD` recorded immediately before the subagent is dispatched** (written to `.run/pre-dispatch-head`). This is captured per-stage, overwriting the previous value, so each stage's diff reflects only that stage's changes.

```bash
# written in speckit.run.md, step f (pre-dispatch):
git rev-parse HEAD > "$FEATURE_DIR/.run/pre-dispatch-head"

# read after Task tool returns:
pre_head=$(cat "$FEATURE_DIR/.run/pre-dispatch-head" 2>/dev/null || true)
git diff "$pre_head"..HEAD --name-only > "$FEATURE_DIR/.run/stage-diff-${STAGE}.files"
git diff "$pre_head"..HEAD             > "$FEATURE_DIR/.run/stage-diff-${STAGE}.patch"
```

## Alternatives Considered

### Option A: Start-of-run HEAD
Record HEAD once when `run-lock.sh acquire` fires; use it as the baseline for all stages.

**Pros**: Single write; simpler.
**Cons**: Stage N's diff includes all changes from stages 1 through N-1, making it useless for per-stage independent audit. The point is to isolate what each stage did.

### Option B: Previous-stage HEAD
Track the HEAD after each stage completes and use it as the next stage's baseline.

**Pros**: Equivalent to Option C in practice when stages commit atomically.
**Cons**: Subagents do not always commit — they may leave changes staged or unstaged. "After stage completes" is ambiguous if no commit was made. Pre-dispatch HEAD is unambiguous regardless of whether the prior stage committed.

### Option C: Pre-dispatch HEAD *(chosen)*
Record HEAD immediately before dispatching the subagent. Captures the exact state the subagent started from.

**Pros**: Unambiguous regardless of prior-stage commit behavior. Per-stage scope is exact. Overwrites cleanly — no accumulation state to manage.
**Cons**: `.run/pre-dispatch-head` is overwritten each stage; the file only holds the most recent baseline. The `.files`/`.patch` artifacts persist per-stage, so historical baselines are recoverable from them if needed.

## Rationale

Independent auditing requires knowing what changed per stage, not what changed since the run started. Pre-dispatch HEAD is the only baseline that gives exact per-stage scope without depending on subagent commit behavior. The overwrite-per-stage pattern is intentional: the baseline file is a working scratch value, not a history; the history lives in the diff artifacts it produces.

`run-lock.sh acquire` sweeps `.run/stage-diff-*.{files,patch}` at the start of each new run (LOG-012 pattern), so stale diffs from a prior run do not contaminate the current one.

## Consequences

**Positive**: Each `.run/stage-diff-<stage>.patch` is a self-contained, independently verifiable record of what the subagent changed. Developers and future `/speckit.audit` passes can read the patch without trusting `decisions-log.md`.

**Negative / Trade-offs**: `.run/pre-dispatch-head` holds only the most recent baseline. If a stage is interrupted mid-dispatch, the file contains the baseline for the incomplete stage — this is safe (the diff artifact for that stage will simply be absent or empty), but a reader inspecting the file in isolation has no stage label.

**Risks**: None material. The file is written before dispatch and read after; the window for a write/read race is only if the orchestrator process is killed between those two lines, in which case the stage was not dispatched and no diff is expected.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-05-25 | Initial record (post-audit addition; decision was implicit in speckit.run.md post-code-review) | Claude (consistency-auditor follow-through) |
