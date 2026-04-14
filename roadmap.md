# Speckit Roadmap

**Project**: ClaudeTest / Speckit Template
**Owner**: Colin Dwan (Prologue Games)
**Purpose**: A spec-driven development template with multi-agent adversarial review, optional local vector memory, and bidirectional consistency auditing. Designed to be deployed into any project — every project should be able to use this pattern for scoping, clarifying, building, reviewing, and maintaining its repo.
**Last Updated**: 2026-04-12
**Status**: Phase 1 complete. Phase 2 active.

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

**ADRs created**: 14 (ADR-001–013, ADR-019, ADR-021–024)
**LOGs open**: LOG-017 (partially addressed), LOG-020
**LOGs resolved**: LOG-014, LOG-015, LOG-016, LOG-018 (deferred), LOG-025, LOG-026

---

## Phase 2 — Reliability
*Goal: Make the current single-deployment trustworthy for long-lived real projects.*

### 004 · Index Cleanup Agent

**Summary**: `memory_sync` currently only adds and updates chunks — it never removes chunks for files that have been deleted or renamed. In a long-lived project (50+ ADRs, evolving spec structure), the index accumulates stale chunks that pollute recall results with content that no longer exists on disk.

**What it builds**: A cleanup pass in `memory_sync` that diffs the manifest against the current filesystem state, identifies orphaned chunks (source file no longer exists at indexed path), and deletes them. Should run as part of the normal sync cycle, not as a separate tool call.

**MoSCoW**: Must
**Effort**: S
**Key assumption**: The manifest already tracks `source_file` per chunk — cleanup is a manifest diff, not a full re-scan.
**Depends on**: None
**Blocked by**: Nothing (LOG-018 explicitly deferred this here)

---

### 005 · Ollama Fallback (Graceful Degradation)

**Summary**: `memory_recall` returns `API_UNAVAILABLE` when Ollama is unreachable. Any session without Ollama pre-started gets a broken tool — unacceptable for a real project. A BM25/keyword fallback over chunk content would let recall degrade gracefully instead of failing hard.

**What it builds**: A fallback search path in `memory_recall`: if the Ollama embedding call fails, fall back to BM25 keyword search over `chunk.content` and `chunk.section`. Returned results include a `degraded: true` flag in the response envelope so callers know the quality is lower.

**MoSCoW**: Must
**Effort**: S–M
**Key assumption**: BM25 over the LanceDB table is achievable without a separate search index (LanceDB has FTS support; alternatively, simple substring match is sufficient for fallback quality).
**Depends on**: None
**Reference**: LOG-017/GAP-1

---

## Phase 3 — Composability
*Goal: Make speckit deployable into any project, with upgrade support for in-flight projects.*

### 006 · Component Model + Graceful Degradation in Skills

**Summary**: Before building the init CLI, the component boundaries need to be formally defined and the skill layer needs to handle missing components gracefully. Currently, skills implicitly assume `speckit-memory` is always configured. A project using only `speckit-core` would break any skill that calls `memory_recall`.

**What it builds**:
- An ADR defining the three-component model, component boundaries, and owned file sets
- A `.speckit.json` manifest format (installed components + versions) — the basis for upgrade detection
- Conditional MCP calls in skills: call `memory_recall` when `speckit-memory` is configured; skip gracefully when not
- Convention: oracle tools (when present) are called alongside memory tools in plan/review skills

**MoSCoW**: Must (prerequisite for 007)
**Effort**: S
**Key assumption**: Skills can check for MCP availability at call time; the Claude Code harness doesn't fail on missing MCP tool references, it just returns an error the skill can handle.
**Depends on**: Nothing
**Note**: This is primarily a design + ADR task with small code changes. Do not over-engineer.

---

### 007 · speckit-init + Upgrade CLI

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
- Component file ownership is tracked in `.speckit.json` (built in 006)
- "In-flight project on older version" means `.speckit.json` is absent or has an older version — upgrade detects this and offers a migration path
- The CLI is a standalone script (Python or shell), not a published package — packaging for distribution is Phase 5+
**Depends on**: 006 (component model + manifest format)

---

## Phase 4 — Cross-Project Intelligence
*Goal: Define what speckit offers to external systems; defer joint interface contract until oracle repo is shareable.*

### 008 · Speckit Decision Export Surface

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

### 009 · Session Handoff Skill

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

### 010 · Memory-Aware + Oracle-Aware Skill Upgrades

**Summary**: The `memory-convention.md` documents a recall-before/store-after pattern for skills, but the actual skill implementations may not consistently follow it. This feature audits and upgrades all speckit skills to: (1) call `memory_recall` before plan/review/task generation, (2) store summaries after, and (3) call oracle tools when configured. The oracle call convention is established here once the joint interface contract (post-008) is defined.

**What it builds**:
- Audit of all `.claude/commands/` skills against the recall-before/store-after convention
- Upgrades to non-compliant skills
- Oracle call wiring in plan, review, and audit skills (conditional on oracle being configured)
- Integration test: end-to-end flow from `speckit.plan` → `memory_recall` → plan output → `memory_store`

**MoSCoW**: Should
**Effort**: M
**Key assumption**: The oracle interface contract is defined before this feature is implemented (depends on 008 + joint interface work).
**Depends on**: 006 (graceful degradation), 008 (export surface), oracle interface contract

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

---

## Open Questions

| # | Question | Raised In | Priority |
|---|---|---|---|
| Q1 | What is the right split between speckit-core file ownership and project customization for agent persona files? Users may customize agent prompts — init should not overwrite these. | Phase 3 planning | High |
| Q2 | Should `speckit upgrade` be non-interactive (dry-run by default, apply with `--apply`) or interactive (prompt per file)? | Phase 3 planning | Medium |
| Q3 | What is the oracle intake schema? (Blocked on oracle repo access — do not speculate.) | Phase 4 planning | High, blocked |
| Q4 | Does `/speckit.handoff` auto-trigger at session end via a hook, or is it always user-invoked? | 009 planning | Low |

---

## Revision History

| Date | Change | Author |
|---|---|---|
| 2026-04-12 | Initial roadmap — drafted post-003 completion; incorporates component model, init+upgrade requirement, and export surface framing | /speckit.retro (stripped-down) |
