# LOG-031: Code Review Fast-Follow Items — 005-sync-stale-cleanup

**Date**: 2026-04-13
**Status**: Open
**Type**: QUESTION / CHALLENGE
**Related Feature**: specs/005-sync-stale-cleanup/spec.md
**Raised By**: /speckit.codereview post-implementation review (adversarial panel: code-reviewer + devils-advocate + synthesis-judge)

---

## Context

Feature 005 code review surfaced four fast-follow items after the two pre-merge fixes (S-001: `full+paths` guard, M-001: ADR-030 OSError test) were applied. These are hardening and spec hygiene items — not correctness bugs. None block the current PR.

---

## Open Items

### FF-001 — SC-004 partial-progress error response (S-002)

**Finding**: If `delete_chunks_by_source_file(table, rel)` raises during the cleanup loop (e.g., disk full, I/O error), the exception propagates uncaught out of `run_sync`. The caller gets a raw exception instead of a structured partial-progress response. SC-004 specifies: "the sync response MUST report an error state; the `deleted` field MUST reflect only the chunks actually removed before the error."

**Location**: `memory-server/speckit_memory/sync.py`, cleanup loop (lines ~350-365 after S-001 guard added).

**Fix**: Wrap the cleanup loop in try/except. On exception, return `{"error": {"code": "CLEANUP_PARTIAL", "message": ..., "recoverable": True}, "deleted": partial_count, ...}`. Pattern already exists at the MODEL_MISMATCH path (~line 294).

**Priority**: Low. LanceDB is embedded — realistic failure modes (disk full, corrupt Lance file) are catastrophic for the session regardless. Idempotent retry works safely (manifest not saved until line ~405). But the structured error contract is in the spec and should be honored.

---

### FF-002 — Absolute paths in `paths` cause silent no-op (M-002)

**Finding**: `run_sync(paths=["/absolute/path/to/file.md"])` produces `scoped_files=[]` (the relative-path comparison never matches), reports `indexed=0, skipped=0, deleted=0`, and returns successfully. An LLM agent passing absolute paths gets a convincing-looking empty result with no signal that the call was misconfigured.

**Location**: `memory-server/speckit_memory/sync.py`, lines ~335-338 (scoped_files filter).

**Fix**: At the top of `run_sync`, normalize each path in `paths` to be relative to `repo_root` if it starts with `str(repo_root)`. Or raise `ValueError` on absolute paths. Either eliminates the silent no-op.

**Priority**: Low-medium. LLM agents are realistic callers of `memory_sync(paths=[...])` and may construct absolute paths.

---

### FF-003 — `_setup_repo` dead code in unit tests (S-004)

**Finding**: `_setup_repo` at `memory-server/tests/unit/test_sync.py:28-32` is never called. Its docstring claims 4 return values, type annotation claims 3, body returns 2. A future contributor calling it expecting a 4-tuple would get a silent bug.

**Location**: `memory-server/tests/unit/test_sync.py` lines 28-32.

**Fix**: Delete the function. `tmp_repo_two_files` fixture covers the same setup correctly.

**Priority**: Trivial. Delete on next touch of that file.

---

### FF-004 — Spec FR-001 does not carve out `full=True` rebuilds (M-003)

**Finding**: FR-001 states "the cleanup pass MUST run before the add/update pass on every unscoped sync cycle." A `full=True` sync is also technically unscoped (no `paths` set), but cleanup is correctly skipped because the table is dropped entirely. The exemption is documented in code comments (line ~347) and ADR-027, but not in the spec itself. Strict reading of FR-001 conflicts with the implementation.

**Location**: `specs/005-sync-stale-cleanup/spec.md`, FR-001.

**Fix**: Add FR-001b: "The cleanup pass is skipped when `full=True` because the full rebuild drops and recreates the table, making per-file cleanup a no-op." No code change needed.

**Priority**: Spec hygiene. Amend before running `/speckit.audit`.

---

## Resolution Notes

| Item | Status | Resolved In |
|---|---|---|
| FF-001 | Open | — |
| FF-002 | Open | — |
| FF-003 | Resolved | tests/unit/test_sync.py — dead function deleted (/speckit.audit) |
| FF-004 | Resolved | specs/005-sync-stale-cleanup/spec.md — FR-001b added (/speckit.audit) |

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-13 | Initial record — post-code-review fast-follows | Claude (/speckit.codereview) |
