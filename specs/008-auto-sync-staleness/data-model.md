# Data Model: Auto-Sync Staleness Detection and Memory Opt-In Gate

**Feature**: 008-auto-sync-staleness  
**Date**: 2026-04-17

---

## Manifest (amended)

The manifest is a JSON file at `.specify/memory/.index/manifest.json` that tracks the indexed state of the memory corpus.

**New field**: `last_sync_ts`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | string | yes | Schema version (`"2"`) |
| `embedding_model` | string | yes | Model name used for embedding |
| `embedding_dimension` | integer | yes | Vector dimension (768) |
| `similarity_metric` | string | yes | Distance metric (`"cosine"`) |
| `entries` | object | yes | Per-file index metadata keyed by relative path |
| `last_sync_ts` | float | **new** | Unix timestamp (seconds) of last successful `run_sync()` completion. Absent in pre-008 manifests or newly created manifests. |

**Staleness rule**: `absent` → 0 → treated as stale (triggers re-sync on first post-008 call).

**Write condition**: Written only when `run_sync()` completes without raising an exception. Not written during partial or failed syncs.

---

## Staleness Threshold

| Attribute | Value |
|-----------|-------|
| Source | `MEMORY_STALENESS_THRESHOLD` environment variable |
| Type | float (seconds) |
| Default | `3600.0` (1 hour) |
| Disable | Set to `0` (or any non-positive value) |
| Validation | Non-positive → disabled; non-numeric → disabled (treated as 0, no error raised) |

---

## Constitution Front-Matter (amended)

The constitution file at `.specify/memory/constitution.md` gains an optional YAML front-matter field.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `memory_enabled` | boolean | no | `true` | When `false`, speckit skills skip all `memory_recall` and `memory_store` calls. Direct MCP tool calls are unaffected. |

**Parse rule**: If constitution file is absent, unparseable, or the field is missing, treat as `memory_enabled: true`.

**Unrecognized values** (e.g., `"yes"`, `1`, `null`): treat as `true` (permissive default).

---

## State Transitions

```
Process start
  └─ _first_call_done = False
       │
       ▼
  _ensure_init() called
       │
       ├─ _first_call_done = False ──► run_sync()
       │                               ├─ success → _first_call_done = True
       │                               │             last_sync_ts = time.time()
       │                               └─ failure → _first_call_done = False (retry next call)
       │
       └─ _first_call_done = True ──► _check_staleness()
                                       ├─ threshold = 0 → return (no change)
                                       ├─ time.time() - last_sync_ts <= threshold → return
                                       └─ time.time() - last_sync_ts > threshold
                                           └─ _first_call_done = False → re-sync on next call
```
