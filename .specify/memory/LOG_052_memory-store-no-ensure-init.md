# LOG-052: `memory_store` intentionally skips `_ensure_init` — store-before-recall race accepted

**Date**: 2026-04-18
**Type**: CHALLENGE
**Status**: Resolved — accepted risk
**Raised In**: `specs/008-auto-sync-staleness/` — code review (speckit.codereview)
**Related ADRs**: ADR-011, ADR-033
**Related LOGs**: LOG-038

---

## Description

Commit `dc28b8a` (fix(006): codereview) removed the `_ensure_init()` call from `memory_store` to avoid doubling the Ollama timeout budget when the server is unavailable. LOG-038 classified `memory_store` as a tool requiring embedding and stated retry-on-init behavior was "correct and intended." The removal contradicts that classification and creates a latent risk: if `memory_store` is the first tool invoked on a cold process, a subsequent `memory_recall` will trigger `run_sync` — which may execute a full rebuild (e.g., on version migration) — wiping the synthetic chunk just stored.

## Rationale for Removal

Before T007 (006-ollama-fallback), `_ensure_init` set `_first_call_done = True` before the try block, so it fired exactly once regardless of outcome — harmless. After T007, `_first_call_done` stays `False` when Ollama is down. Calling `_ensure_init` from `memory_store` therefore re-attempts `run_sync` every time `memory_store` is called with Ollama unavailable, adding a full `OLLAMA_TIMEOUT` (~10s) before the actual embed attempt — total ~20s per call, violating SC-002.

`memory_store` initialises the LanceDB table directly via `init_table()`, so the table is always ready for insertion regardless of `_ensure_init`. The missing piece is the file-index sync (ADR-011 guarantee), which `memory_store` delegates to the first `memory_recall` call instead.

## Accepted Tradeoff

The store-before-recall sequence is non-typical. `memory-convention.md` specifies recall-before / store-after for all skills. The only user-visible failure mode requires:
1. Cold process (no prior `memory_recall` in this session)
2. `memory_store` called before any `memory_recall`
3. Subsequent `memory_recall` triggers a full `run_sync` (version migration or empty-corpus detection)
4. Synthetic chunk wiped by full rebuild

Under normal skill invocation order, this sequence does not occur. The risk is documented here and in the `memory_store` docstring (server.py). A warning in the docstring references this LOG so future implementers understand the constraint before adding an `_ensure_init` call back.

## Resolution

Accepted. No code change. Mitigation: docstring in `memory_store` cites LOG-038 and LOG-052. The skill-layer convention (recall-before / store-after) is the control that prevents the race. If a skill is discovered that calls `memory_store` before `memory_recall`, that skill should be fixed to reorder, not `memory_store` to re-add `_ensure_init`.

**Resolved Date**: 2026-04-18
**Resolved By**: Code review (speckit.codereview, S-1)

## Impact

- [x] `server.py` `memory_store` docstring updated to cite rationale and accepted risk
- [x] LOG-038 cross-referenced as the originating classification
