# Speckit Roadmap

**Project**: ClaudeTest / Speckit Template
**Owner**: Colin Dwan (Prologue Games)
**Purpose**: A spec-driven development template with multi-agent adversarial review, optional local vector memory, and bidirectional consistency auditing. Designed to be deployed into any project — every project should be able to use this pattern for scoping, clarifying, building, reviewing, and maintaining its repo.
**Last Updated**: 2026-04-15
**Status**: Phase 1 complete. Phase 2 active (2 of 3 items done).

---

## Component Model

Speckit is composed of three independently-deployable components. Projects opt into what they need.

| Component | What it is | Required? |
|---|---|---|
| **speckit-core** | Workflow skills, agent personas, templates, review panels, audit, retro | Yes — the baseline |
| **speckit-memory** | Local vector memory MCP server (LanceDB + Ollama) | Optional — adds semantic recall over ADRs and specs |
| **speckit-oracle** | Global decision-pattern service (external, separate repo) | Optional — adds cross-project intelligence |

`speckit-core` has zero runtime dependencies. `speckit-memory` requires Ollama (local) or a fallback. `speckit-oracle` is maintained externally — speckit defines its export surface; oracle defines its intake. The two sides are mapped via a joint interface contract (see Phase 4).

---

## Implementation Summary

| # | Feature | Status | What it built |
|---|---|---|---|
| 000 | review-benchmark | Done | Adversarial review fixture + benchmark scoring key; rigor-level calibration data |
| 001 | review-efficiency-profiler | Done | `/speckit.review-profile` command + `--compare` mode for FULL/STANDARD/LIGHTWEIGHT |
| 002 | vector-memory-mcp | Done | `speckit-memory` MCP server: `memory_recall`, `memory_store`, `memory_sync`, `memory_delete` |
| 003 | memory-server-hardening | Done | Mutation guard, caller-controlled token budget, summary-only mode, source filter; ADR-019–024 |
| 004 | *(skipped — number reserved)* | — | — |
| 005 | sync-stale-cleanup | Done | Stale chunk cleanup pass in `memory_sync`; fixes scoped-sync mass-deletion (FR-001a) and per-file deleted count (FR-008); ADR-027, ADR-030 |
| 006 | ollama-fallback | Done | ToolError raises for all Ollama errors, configurable `OLLAMA_TIMEOUT`, `summary_only` bypass via table scan (`scan_chunks`), `_ensure_init` retry fix, `memory_delete` drops init call; ADR-032, ADR-033, ADR-037 |

**ADRs created**: 21 (ADR-001–013, ADR-019, ADR-021–024, ADR-027, ADR-030, ADR-032, ADR-033, ADR-037)
**LOGs open**: LOG-017 (partially addressed), LOG-020, LOG-028 (orphaned chunks, deferred), LOG-029 (de-dupe + synthetic purge, deferred), LOG-031 (005 fast-follows: FF-001 partial error, FF-002 absolute paths), LOG-038 (partial — `memory_delete` question closed; `OLLAMA_TIMEOUT` non-numeric open)
**LOGs resolved**: LOG-014, LOG-015, LOG-016, LOG-018 (partially resolved by 005), LOG-025, LOG-026, LOG-034, LOG-035, LOG-036 (post-codereview amendment)

---

## Phase 2 — Reliability
*Goal: Make the current single-deployment trustworthy for long-lived real projects.*

### ~~004 · Index Cleanup Agent~~ → Shipped as 005 (see Implementation Summary)

---

### ~~006 · Ollama Fallback (Graceful Degradation)~~ → Done (see Implementation Summary)

**What it built**: `ToolError` replaces `_api_unavailable` return-value dicts for all four tools (ADR-033). `_embed_error` helper with typed error codes (`EMBEDDING_UNAVAILABLE`, `EMBEDDING_MODEL_ERROR`, `EMBEDDING_CONFIG_ERROR`). `OLLAMA_TIMEOUT` env var with 10s default. `memory_recall` restructured: `summary_only` bypasses `_ensure_init` and `_embed_text` entirely via `scan_chunks` table scan (ADR-037). `_ensure_init` flag ordering fixed for retry-on-recovery. `memory_delete` drops `_ensure_init` call. URL validation for non-HTTP/HTTPS schemes (FR-009).

**Branch**: `006-ollama-fallback`

---

### 007 · BM25 Keyword Fallback

**Summary**: After 006, `memory_recall` in semantic mode returns a structured error when Ollama is unavailable — but returns nothing useful. The original roadmap intent for feature 006 was that recall degrades gracefully to keyword search rather than failing. BM25 over `chunk.content` and `chunk.section` would let semantic recall return reduced-quality results instead of an error when Ollama is down. Deferred from 006 per ADR-032.

**What it builds**: A BM25/keyword search path in `memory_recall`: if the Ollama embedding call fails (caught as `ToolError`), fall back to BM25 search over `chunk.content` and `chunk.section`. Returned results include a `degraded: true` flag so callers know quality is lower. Error handling infrastructure from 006 is a prerequisite — the fallback needs a clean error path to fall back *to*.

**MoSCoW**: Must (completes the original 006 promise — tool works offline)
**Effort**: S–M
**Key assumption**: BM25 over the LanceDB table is achievable without a separate search index. LanceDB has FTS support; alternatively, simple scored substring match over content is sufficient for fallback quality.
**Depends on**: 006 (ToolError infrastructure — done)
**Reference**: LOG-017/GAP-1, ADR-032
**Branch**: `007-bm25-fallback`

---

## Phase 3 — Composability
*Goal: Make speckit deployable into any project, with upgrade support for in-flight projects.*

### 008 · Component Model + Graceful Degradation in Skills

**Summary**: Before building the init CLI, the component boundaries need to be formally defined and the skill layer needs to handle missing components gracefully. Currently, skills implicitly assume `speckit-memory` is always configured. A project using only `speckit-core` would break any skill that calls `memory_recall`.

**What it builds**:
- An ADR defining the three-component model, component boundaries, and owned file sets
- A `.speckit.json` manifest format (installed components + versions) — the basis for upgrade detection
- Conditional MCP calls in skills: call `memory_recall` when `speckit-memory` is configured; skip gracefully when not
- Convention: oracle tools (when present) are called alongside memory tools in plan/review skills

**Note (from 006 retro)**: `_ensure_init` was the source of three separate bugs in 006 (LOG-035 flag ordering, LOG-038 retry latency, S-02 double-timeout in write tools). Before building additional init paths in Phase 3, consider a simplification pass on `_ensure_init` — it is now conditionally skipped by multiple tools and its behavior on failure has become non-obvious.

**MoSCoW**: Must (prerequisite for 009)
**Effort**: S
**Key assumption**: Skills can check for MCP availability at call time; the Claude Code harness doesn't fail on missing MCP tool references, it just returns an error the skill can handle.
**Depends on**: Nothing
**Note**: This is primarily a design + ADR task with small code changes. Do not over-engineer.

---

### 009 · speckit-init + Upgrade CLI

**Summary**: There is currently no mechanism to start a new project with speckit or to bring an in-flight project up to a newer version. This is the single largest gap between "personal tooling" and "reusable template." The init system must handle three scenarios: fresh project, upgrade of a current-version project, and catch-up of an in-flight project on an older version.

**What it builds**:
- `speckit init` — prompts for component selection, copies owned files, wires `.mcp.json`, creates `.speckit.json` manifest, bootstraps empty constitution
- `speckit upgrade` — reads `.speckit.json`, diffs installed vs. current component files, applies:
  - **System files** (agent defs, templates, scripts): overwrite
  - **Config files** (`.mcp.json`, `CLAUDE.md` structure): three-way merge with diff prompt
  - **Project files** (constitution, all `specs/`, all `.specify/memory/`): never touch
- `speckit status` — shows installed components, versions, drift from current

**MoSCoW**: Must
**Effort**: L
**Key assumptions**:
- Component file ownership is tracked in `.speckit.json` (built in 008)
- "In-flight project on older version" means `.speckit.json` is absent or has an older version — upgrade detects this and offers a migration path
- The CLI is a standalone script (Python or shell), not a published package — packaging for distribution is Phase 5+
**Depends on**: 008 (component model + manifest format)

---

## Phase 4 — Cross-Project Intelligence
*Goal: Define what speckit offers to external systems; defer joint interface contract until oracle repo is shareable.*

### 010 · Speckit Decision Export Surface

**Summary**: Speckit accumulates structured decision artifacts (ADRs, LOGs, retro learnings, synthetic memory chunks). An external system like oracle could consume these to build cross-project intelligence — but only if speckit exposes them in a consistent, queryable form. This feature defines speckit's *offer* — independent of how oracle or any other consumer ingests it.

**What it builds**:
- A documented export schema: what fields, what format, what granularity each artifact type exposes
- A `memory_export` tool on `speckit-memory` (or a query convention) that returns ADRs/LOGs/synthetic chunks in the export schema, filterable by type/date/feature/tags
- A retro artifact: `/speckit.retro` writes a structured learnings summary (exportable format) as a synthetic chunk — this is the natural per-project sync point for any consumer
- An ADR capturing the export surface design decisions

**MoSCoW**: Should
**Effort**: M
**Key assumption**: The export surface is speckit's side of a two-sided contract. The joint interface mapping to oracle is a separate feature, blocked on the oracle repo being shareable.
**Depends on**: 003 (memory server must be stable before adding a 5th tool)
**Explicitly deferred**: Oracle intake mapping, oracle MCP wiring, joint interface ADR — all blocked on oracle repo access.

---

### 011 · Session Handoff Skill

**Summary**: For async, multi-project workflows, there's no durable "where we left off" record between sessions. The hindsight plugin captures conversation history but not structured project-state summaries. A `/speckit.handoff` skill writes a synthetic chunk summarizing the current session's key decisions, open questions, and next steps — queryable in the next session via `memory_recall`.

**What it builds**:
- `/speckit.handoff` skill: prompts for or synthesizes session summary, calls `memory_store` with structured metadata (`type: "handoff"`, `feature`, `date`, `tags: ["handoff", "session"]`)
- Convention for what a handoff chunk contains: decisions made, LOGs opened, next recommended task
- Optional: auto-trigger via a hook at session end (separate settings config)

**MoSCoW**: Should
**Effort**: S
**Key assumption**: `memory_store` already supports synthetic chunks with arbitrary metadata — the skill is primarily a convention wrapper around existing infrastructure.
**Depends on**: 003 (already done)
**Reference**: LOG-017/LEARN-3

---

## Phase 5 — Skills Integration
*Goal: Close the loop between the memory/oracle layer and the skill layer.*

### 012 · Memory-Aware + Oracle-Aware Skill Upgrades

**Summary**: The `memory-convention.md` documents a recall-before/store-after pattern for skills, but the actual skill implementations may not consistently follow it. This feature audits and upgrades all speckit skills to: (1) call `memory_recall` before plan/review/task generation, (2) store summaries after, and (3) call oracle tools when configured. The oracle call convention is established here once the joint interface contract (post-010) is defined.

**What it builds**:
- Audit of all `.claude/commands/` skills against the recall-before/store-after convention
- Upgrades to non-compliant skills
- Oracle call wiring in plan, review, and audit skills (conditional on oracle being configured)
- Integration test: end-to-end flow from `speckit.plan` → `memory_recall` → plan output → `memory_store`

**MoSCoW**: Should
**Effort**: M
**Key assumption**: The oracle interface contract is defined before this feature is implemented (depends on 010 + joint interface work).
**Depends on**: 008 (graceful degradation), 010 (export surface), oracle interface contract

---

## Raw Idea Pool
*Not yet sized or scheduled. Candidates for Phase 6+.*

| Idea | Origin | Notes |
|---|---|---|
| min_score auto-calibration | LOG-017/GAP-2 | Run calibration queries against real indexed corpus; default 0.5 is unvalidated |
| Two-pass retrieval wiring | 003 summary_only mode | `summary_only` is built — wire it into skills as first pass before fetching full content |
| Cross-repo / global memory | LOG-017/LEARN-5 | Low priority until speckit is deployed across multiple repos |
| CI spec compliance check | Future | Run audit on PR to catch doc-code drift before merge |
| speckit package distribution | Future | Publish as installable package (npm/pip/homebrew); upgrade via package manager |
| Constitution diff/migration tool | Future | When upgrading, show a structured diff of principle changes between constitution versions |
| DB/manifest partial-state fix | research.md Finding 5 (006) | If sync crashes after chunks written to LanceDB but before `save_manifest`, chunks exist in DB without manifest records — re-embedded on next sync, creating duplicates until `full=True` rebuild. Pre-existing issue; deferred LOG never written in 006. |
| `_ensure_init` simplification | 006 retro | Function caused three separate bugs in one feature (LOG-035, LOG-038, S-02). Now conditionally skipped by multiple tools. Simplification candidate before Phase 3 adds more init paths. |
| OLLAMA_TIMEOUT non-numeric fallback | LOG-038 / 006 spec | Spec says warn + default on non-numeric value; impl raises `ValueError` at import. Open divergence. |

---

## Open Questions

| # | Question | Raised In | Priority |
|---|---|---|---|
| Q1 | What is the right split between speckit-core file ownership and project customization for agent persona files? Users may customize agent prompts — init should not overwrite these. | Phase 3 planning | High |
| Q2 | Should `speckit upgrade` be non-interactive (dry-run by default, apply with `--apply`) or interactive (prompt per file)? | Phase 3 planning | Medium |
| Q3 | What is the oracle intake schema? (Blocked on oracle repo access — do not speculate.) | Phase 4 planning | High, blocked |
| Q4 | Does `/speckit.handoff` auto-trigger at session end via a hook, or is it always user-invoked? | 011 planning | Low |

---

## Revision History

| Date | Change | Author |
|---|---|---|
| 2026-04-12 | Initial roadmap — drafted post-003 completion; incorporates component model, init+upgrade requirement, and export surface framing | /speckit.retro (stripped-down) |
| 2026-04-14 | Mark 005 done; reconcile numbering (004 skipped); update ADR/LOG counts; add branch hint for 006 | /speckit.audit post-005 |
| 2026-04-15 | Mark 006 done; insert 007 BM25 Fallback (deferred from 006 per ADR-032); renumber Phase 3–5 features (008–012); update ADR/LOG counts to 21 ADRs; add `_ensure_init` simplification note to Phase 3/008; add 3 raw idea pool entries (DB partial-state, `_ensure_init`, OLLAMA_TIMEOUT); Phase 2 now 2 of 3 | /speckit.retro post-006 |
