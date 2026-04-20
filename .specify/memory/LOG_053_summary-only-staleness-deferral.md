# LOG-053: `summary_only` calls detect staleness but defer re-sync indefinitely

**Date**: 2026-04-18
**Type**: CHALLENGE
**Status**: Resolved — accepted limitation
**Raised In**: `specs/008-auto-sync-staleness/` — code review (speckit.codereview)
**Related ADRs**: ADR-037, ADR-050
**Related LOGs**: LOG-038, LOG-034

---

## Description

FR-002 states: "If the elapsed time exceeds the staleness threshold, the server MUST trigger an incremental re-sync before returning results." `_check_staleness()` is called on every `memory_recall` invocation including `summary_only=True` calls. When staleness is detected on a `summary_only` call, `_first_call_done` is reset to `False` — but `_ensure_init()` (which calls `run_sync`) is skipped, and results are returned from the stale index.

## Why Re-sync Is Deferred

`summary_only=True` was designed to be Ollama-free (ADR-037, LOG-034): it scans the LanceDB table directly without calling any embedding function. `run_sync` requires Ollama to embed new or changed files. Triggering re-sync on the `summary_only` path would:
1. Re-introduce an Ollama dependency on a path designed to avoid it
2. Add ~10s latency to every `summary_only` call when Ollama is unavailable (LOG-038)
3. Contradict the `summary_only` contract observed by callers

## Failure Mode

A process that exclusively issues `summary_only` calls — never a semantic `memory_recall` — will reset `_first_call_done` on every call once the threshold is crossed but will never sync. The stale index persists for the process lifetime. Signal: an INFO log is emitted each time staleness is detected ("re-sync scheduled on next embedding call"), so the operator has visibility.

In practice this is unlikely: `summary_only` is used for quick metadata listings (section names, source files). Skills that list then recall still make a non-summary recall that triggers the deferred sync. A process making only summary calls has limited operational value and is not the primary use case.

## Spec Amendment

FR-002 in `specs/008-auto-sync-staleness/spec.md` has been updated with an explicit carve-out documenting this exception. ADR-050 has been updated with a "summary_only Carve-out" subsection (§ after Consequences).

## Resolution

Accepted limitation. No code change. Mitigation: INFO log on staleness detection; FR-002 and ADR-050 updated to document the exception.

**Resolved Date**: 2026-04-18
**Resolved By**: Code review (speckit.codereview, S-3)

## Impact

- [x] FR-002 in spec.md amended with summary_only exception
- [x] ADR-050 updated with summary_only carve-out section
- [x] INFO log added to `_check_staleness()` when flag is reset (server.py)
