# LOG-038: `_ensure_init` retry-on-every-call affects non-embed tools after T007

**Date**: 2026-04-15
**Type**: CHALLENGE
**Status**: Open
**Raised In**: `specs/006-ollama-fallback/tasks.md` — task gate review
**Related ADRs**: ADR-033, ADR-037

---

## Description

After T007 moves `_first_call_done = True` inside the try block (enabling retry-on-recovery), `_first_call_done` stays `False` whenever Ollama is down. This means every subsequent call to any tool that invokes `_ensure_init()` will re-trigger `run_sync()`, which attempts to embed new/stale files — hitting the ~10s Ollama timeout each time.

For tools that require embedding (`memory_store`, `memory_sync`, semantic `memory_recall`), this retry-on-init behavior is correct and intended. For tools that are Ollama-free by spec (`memory_recall` in `summary_only=True` mode, `memory_delete`), the retry adds unnecessary latency and potentially a ~10s timeout per call — directly violating FR-006, SC-001, and FR-008.

## Context

Surfaced during post-tasks adversarial review of 006-ollama-fallback. The research.md analysis (Finding 3) concluded `_ensure_init` was "safe" for `summary_only` because exceptions are caught and execution continues. That analysis was written before T007 was scoped. Pre-T007, `_first_call_done` was set before the try block, so init fired exactly once regardless of success — harmless. Post-T007, the flag stays `False` on failure, changing the behavior fundamentally.

The plan's pseudocode for `memory_recall` (plan.md, Change 3) shows `_ensure_init()` called unconditionally before the `if summary_only:` branch. This is where the latency is introduced.

## Discussion

### Pass 1 — Initial Analysis

T007 is correct: the flag should only be set on success. But T014 must now account for the interaction. The `summary_only` path already calls `init_table(idx_dir)` directly — it does not need `_ensure_init()` for table access. The only thing `_ensure_init` adds to the `summary_only` path is the auto-sync-on-first-call, which requires Ollama anyway.

### Pass 2 — Critical Review

Three options:
1. Guard `_ensure_init()` in `memory_recall` with `if not summary_only` — simplest, directly fixes the `summary_only` case
2. Pass a `skip_embed=True` flag to `_ensure_init` that short-circuits `run_sync` — adds a parameter to a private function for one use case; overkill
3. Split `_ensure_init` into "ensure table exists" and "auto-sync" — violates Principle II (speculative abstraction)

Option 1 is the correct fix. It is already captured in T014 (task gate review amendment).

### Pass 3 — Resolution Path

The same question applies to `memory_delete`: it calls `_ensure_init()` but does not require embedding (FR-008). After T007, a `memory_delete` call with Ollama down will re-trigger init on every invocation. T023 tests that `memory_delete` succeeds with Ollama unavailable but does not assert it returns quickly — if `run_sync` crawls files and finds stale ones, it will hit the embed timeout before failing and returning.

Scope question for implementer: should `memory_delete` also skip `_ensure_init`, or is the retry-on-init overhead acceptable for delete (lower frequency operation)?

## Resolution

Partially resolved by task amendment. T014 now includes guard: `if not summary_only: _ensure_init()`. The `memory_delete` interaction remains open pending implementer judgment.

**Resolved By**: Inline task amendment (T014 updated in task gate review)
**Resolved Date**: 2026-04-15 (partial — `memory_delete` question open)

## Impact

- [x] Tasks revised: T014 (amended to guard `_ensure_init` behind `if not summary_only`)
- [ ] Tasks revised: T023 — consider adding assertion that `memory_delete` returns within 1s when Ollama is down
- [ ] Plan updated: plan.md Change 3 pseudocode should reflect the `_ensure_init` guard
