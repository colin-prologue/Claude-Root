---
name: LOG-048 — Store/sync fallback asymmetry
description: memory_recall degrades gracefully when Ollama is down; memory_store and memory_sync hard-fail — intentional 007 scope or product gap?
type: project
---

# LOG-048: Store/Sync Fallback Asymmetry

**Date**: 2026-04-17
**Status**: Open — needs product decision if store/sync resilience is a future feature
**Feature**: 007-bm25-keyword-fallback
**Related ADRs**: ADR-032 (006 scope: errors vs BM25), ADR-043 (in-process TF scoring)

---

## Observation

007-bm25-keyword-fallback adds graceful degradation to `memory_recall` only:
- `memory_recall` + Ollama down → BM25 fallback, `degraded: true`, no ToolError
- `memory_store` + Ollama down → hard ToolError (EMBEDDING_UNAVAILABLE)
- `memory_sync` + Ollama down → hard ToolError (EMBEDDING_UNAVAILABLE)

This asymmetry is intentional for the 007 scope (recall-read path is highest-frequency; store/sync are infrequent write operations). However, it was never explicitly decided as a product choice.

## Why This Matters

A user in a CI/CD pipeline that calls `memory_sync` on every merge will hard-fail when Ollama is unavailable (e.g., Ollama service restart, network blip). There is no partial-sync or queue-for-retry option — the sync is a no-op and the index drifts from the file tree until the next successful sync.

## Potential Follow-On Features

- `memory_sync` in "dry run" mode when Ollama is down: log what would have been indexed, queue for retry
- Retry-on-recovery for `memory_store` (similar to `_ensure_init` retry pattern from LOG-035)
- Offline-capable `memory_store` that buffers chunks and embeds on next Ollama-available call

## Status

Not a bug — the spec explicitly scoped 007 to `memory_recall`. Recording as a product question to settle before implementing any store/sync resilience feature. Surfaced by `/speckit.codereview` Phase B.
