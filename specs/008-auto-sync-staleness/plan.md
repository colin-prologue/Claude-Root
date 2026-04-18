# Implementation Plan: Auto-Sync Staleness Detection and Memory Opt-In Gate

**Branch**: `008-auto-sync-staleness` | **Date**: 2026-04-17 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/008-auto-sync-staleness/spec.md`

## Summary

Add timestamp-based index staleness detection to `_ensure_init()` so the memory server automatically re-syncs when the index is more than `MEMORY_STALENESS_THRESHOLD` seconds old (default 3600s), and add a `memory_enabled` flag to the constitution front-matter so speckit skills can be explicitly disabled for projects that do not use the memory server.

## Decision Records

| # | Type | File | Title | Status |
|---|---|---|---|---|
| LOG-049 | Question | LOG_049_speckit-memory-coupling.md | Speckit Skills Implicitly Require Memory Server | Open → drives this feature |
| ADR-050 | Decision | ADR_050_timestamp-staleness-detection.md | Timestamp-Based Staleness Detection in `_ensure_init` | Accepted |
| ADR-051 | Decision | ADR_051_constitution-memory-gate.md | Constitution Front-Matter as Memory Opt-In Gate | Accepted |

## Technical Context

**Language/Version**: Python 3.10+
**Primary Dependencies**: FastMCP 2.0+, LanceDB 0.13+, httpx, ollama SDK
**Storage**: Manifest JSON (`manifest.json`) in `.specify/memory/.index/`; LanceDB table
**Testing**: pytest + pytest-asyncio 8.0+
**Target Platform**: macOS / Linux (local development)
**Project Type**: MCP server library
**Performance Goals**: Staleness check adds <1ms overhead per recall call when index is fresh (pure in-memory timestamp arithmetic)
**Constraints**: No new external dependencies; sync is synchronous on recall path (background deferral deferred per ADR-050)
**Scale/Scope**: 50–200 markdown files; ADR-013 deferred ANN index threshold unchanged

## Constitution Check

- [x] **Pass 1 — Assumptions**: The existing `_ensure_init` mechanism is the correct hook point. `run_sync` is the correct place to write `last_sync_ts`. Constitution front-matter is the correct home for `memory_enabled`. All challenged: each is the simplest extension of existing patterns.
- [x] **Pass 2 — Research**: Two staleness strategies evaluated (ADR-050); three gate strategies evaluated (ADR-051). No contradictions found. `_strip_frontmatter()` already exists in sync.py — constitution parsing is not a new dependency.
- [x] **Pass 3 — Plan scrutiny**: Riskiest decision is synchronous re-sync on recall path. Risk accepted: sync is bounded (50-200 file corpus) and rare (once per staleness window). Deferred background sync is the right follow-on if latency becomes a problem.

- [x] Principle I: Spec complete and approved before this plan was written
- [x] Principle II: No speculative abstractions — two targeted changes (timestamp field + gate check); no new classes, no new abstractions
- [x] Principle III: TDD confirmed — all server code changes are preceded by failing tests
- [x] Principle IV: P1 (staleness detection) is independently deliverable; P2 (gate) adds no dependency on P1
- [x] PR Policy: Estimated ~80-100 LOC total — well within 300 LOC limit

## Project Structure

### Documentation (this feature)

```text
specs/008-auto-sync-staleness/
├── plan.md              # This file
├── research.md          # Phase 0 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code

```text
memory-server/
  speckit_memory/
    server.py            # modified: MEMORY_STALENESS_THRESHOLD config, import time,
    │                    #   _check_staleness() helper, _ensure_init() staleness branch
    sync.py              # modified: last_sync_ts written to manifest in run_sync()
  tests/
    unit/
      test_staleness.py  # new: TDD tests for staleness logic (no Ollama)

.claude/rules/
  memory-convention.md   # modified: add constitution gate check instruction

.specify/
  memory/
    constitution.md      # modified: add memory_enabled: true to front-matter
    ADR_050_timestamp-staleness-detection.md   # new (written in Phase 0)
    ADR_051_constitution-memory-gate.md        # new (written in Phase 0)
    LOG_049_speckit-memory-coupling.md         # modified: mark resolved, add ADR refs
  templates/
    constitution-template.md   # modified: add memory_enabled field with docs
```

**Structure Decision**: All changes are targeted modifications to existing files. One new test file. No new modules, no new packages.

## Complexity Tracking

No Principle II violations. Both changes are additive: one new manifest field, one new env var, one small helper function, one field check in convention documentation.

---

## Phase 1: Design & Contracts

### Data Model Changes

**Manifest schema amendment** (no migration required):

```
manifest.json (existing)
  version: "2"                  # unchanged
  embedding_model: string        # unchanged
  embedding_dimension: 768       # unchanged
  similarity_metric: "cosine"    # unchanged
  entries: { ... }               # unchanged
  last_sync_ts: float            # NEW — Unix timestamp of last successful sync
                                 #   absent in pre-008 manifests → treated as stale
```

The `_EMPTY_MANIFEST` constant in `index.py` does NOT need updating — `last_sync_ts` is absent from empty manifests by design (absent = stale = safe default for first run).

**Constitution front-matter amendment**:

```yaml
---
memory_enabled: true   # NEW optional field; default true when absent
---
```

The existing `_strip_frontmatter()` function in `sync.py` parses this format. Skills read it via direct file read + `_strip_frontmatter()`.

### Contracts

No new MCP tool interfaces are added. No contract document is required — this feature modifies internal server behavior and a documentation convention, not the public tool API.

**Behavioral contract addendum to `memory_recall`**:
- Pre-008: `_ensure_init()` runs at most once per process lifetime
- Post-008: `_ensure_init()` may trigger re-sync more than once per process lifetime when the staleness threshold is crossed. Callers see no API change; the latency of a single recall call may be higher after a stale window.

### `_check_staleness()` and `_ensure_init()` Logic (post-008)

`_check_staleness()` is called from `memory_recall()` directly, **before** the `summary_only` gate, ensuring all recall callers (including `summary_only=True`) trigger the staleness check. This fixes the FR-002 invariant and avoids the summary_only regression identified in task-gate review.

```
memory_recall(..., summary_only=False):
    _check_staleness()          # all paths — pure arithmetic, no Ollama (FR-002)
    if not summary_only:
        _ensure_init()          # embed + sync — Ollama required
    ...

_check_staleness():
  if MEMORY_STALENESS_THRESHOLD <= 0:
    return                 # disabled
  try:
    manifest = load_manifest(_index_dir())
    last_sync = manifest.get("last_sync_ts", 0)
    if time.time() - last_sync > MEMORY_STALENESS_THRESHOLD:
      _first_call_done = False
  except Exception as exc:
    print(f"[speckit-memory] WARNING: staleness check failed: {exc}", stderr)

_ensure_init():
  if _first_call_done:
    return                 # no staleness logic here — moved to memory_recall
  try:
    run_sync(...)
    _first_call_done = True
  except Exception as exc:
    print(WARNING, stderr)  # non-fatal; stays False → retries next call
```

**Note**: `_MEMORY_STALENESS_THRESHOLD` is parsed with try/except at module load — non-numeric or non-positive values default to `0.0` (disabled) without raising.

### `run_sync()` Change (post-008)

One line added before the final `save_manifest()` call:

```python
manifest["last_sync_ts"] = time.time()
save_manifest(index_dir, manifest)
```

This line is placed at the end of the function body, after all indexing is complete, so it is written only on successful completion. A raised exception before this line leaves `last_sync_ts` unwritten (or unchanged), preserving staleness.

**Note**: Full rebuilds (`full=True`) reset the manifest to `_EMPTY_MANIFEST` at the start — `last_sync_ts` would be absent in the reset manifest and re-added at the end. This is correct: a fresh rebuild is a fresh sync.

### Constitution Gate Convention (memory-convention.md update)

New section added to `memory-convention.md`:

```
## Constitution gate

Before invoking any memory tool, check the `memory_enabled` field in
constitution.md front-matter. If `memory_enabled: false`, skip all
memory_recall and memory_store calls and continue without error.

If the constitution is absent or unparseable, treat as memory_enabled: true.
```

### Agent Context Update

Running update script after Phase 1 design.

---

## ADR-011 Amendment

ADR-011 documents that `_ensure_init` runs "once per process lifetime". Post-008 this is no longer accurate — it can fire more than once. An amendment entry must be added to ADR-011's Amendment History table as part of this feature.
