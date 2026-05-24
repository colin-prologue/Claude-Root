# Data Model — `/speckit.run` Orchestrator

**Date**: 2026-04-26
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

The orchestrator's "data model" is filesystem-only — there is no database. This document defines each on-disk entity, its location, format, fields, lifecycle, and the FRs that constrain it.

---

## E-1 — Pipeline Run

**Conceptual entity** (no single file represents it; the "run" is the union of artifacts below for a feature directory between lock-acquire and lock-release).

**Identity**: `run_id` — generated at lock-acquire time as `run-<ISO8601-UTC>-<6-hex>` (e.g., `run-2026-04-26T20:00:00Z-a1b2c3`). Stored in `run-lock` and stamped on every sidecar event for traceability.

**Lifecycle**:
1. `acquire` — `run-lock` created; `run_id` minted; `stage-start` event emitted to sidecar; `.run/last-verdict` and `.run/*.tmp` swept (ADR-022, LOG-012).
2. Per-stage iteration — subagent dispatch → entry append to `decisions-log.md` → record validate → (code-action only) postcheck → route decision (writes verdict receipt) → emit-event (validates receipt) → next stage or halt.
3. `release` — terminates the run. **On every termination path** (halt, abort, permission-failure, clean), orchestrator MUST append a coalesced control-flow summary to `decisions-log.md` via stage-then-rename idiom (ADR-016 amended; LOG-012). `run-lock` is removed atomically with abort-sentinel cleanup.

**Constraints**:
- Concurrent runs forbidden per feature directory (FR-028).
- Run survives within a single Claude Code session only in V1 (ADR-015). Cross-session resume is V2.

---

## E-2 — Run Lock

**Location**: `specs/[###]/.run/run-lock`
**Format**: Plain text, two lines:
```
run_id=run-2026-04-26T20:00:00Z-a1b2c3
created_at=2026-04-26T20:00:00Z
```

**Lifecycle**:
- Created by `run-lock.sh acquire` via atomic `mkdir`-based create-or-fail.
- Removed by `run-lock.sh release` (clean termination), `run-lock.sh break` (ADR-018 recovery), or atomic abort cleanup (FR-027).

**Constraints**:
- Acquisition fails (`EEXIST`) if a lock from any prior session is present (FR-028).
- Recovery from a stale lock is `--break-lock` only in V1 (ADR-018).
- Lock removal must be atomic with abort-sentinel removal when both are present (FR-027) — implemented via staging-then-rm.

---

## E-3 — Abort Sentinel

**Location**: `specs/[###]/.run/abort`
**Format**: Empty file (presence is the signal). Optional payload: developer-written reason on a single line; orchestrator preserves it in the abort log entry if present.

**Lifecycle**:
- Created by the developer (`touch specs/[###]/.run/abort`) at any time during a run.
- Detected by `run-lock.sh check-sentinel` invoked between every stage dispatch (FR-027).
- Removed atomically with the run-lock as part of the abort cleanup.

**Constraints**:
- Detection latency ≤ one stage-boundary check (SC-007).
- Abort entry written to `decisions-log.md` by the active subagent (if a subagent is mid-dispatch when abort is detected) or coalesced into the orchestrator sidecar otherwise.

---

## E-4 — Decision-Log Entry (Canonical)

**Location**: `specs/[###]/decisions-log.md` (markdown, append-only within a run)
**Format**: One entry per markdown section. Section heading carries the type and stage; key-value pairs and named sub-blocks carry the FR-006 fields. See `.specify/contracts/decision-log-entry.md` for the wire format.

**Required fields per FR-006**:
| Field | Type | Notes |
|---|---|---|
| `stage` | enum | One of: `specify`, `clarify`, `plan`, `review`, `tasks`, `analyze`, `implement`, `codereview`, `audit` |
| `entry_type` | enum | `stage-start`, `stage-end`, `stage-skip`, `escalate`, `route`, `abort`, `subagent-record` |
| `timestamp` | ISO-8601 string | UTC |
| `author` | string | `orchestrator` or `subagent:[stage]` |
| `status` | enum | `success`, `halt`, `error` |
| `rationale` | free-text markdown | Why this entry exists |

**Additional fields when `entry_type=subagent-record`**:
| Field | Type | Notes |
|---|---|---|
| `artifacts_written` | list of paths | Relative to repo root |
| `decisions_made` | list of structured items | Each has `decision`, `rationale`, `alternatives` |
| `halt_directive` | boolean + reason | Set true to require BLOCKING checkpoint |

**Writers**:
- Subagent appends its per-stage record (`entry_type=subagent-record`) before exit. (ADR-013)
- Orchestrator appends control-flow entries (`stage-start`, `stage-skip`, `route`, `abort`, `escalate`) as a single coalesced summary **at every termination path** — clean, halt, abort, permission-failure (ADR-016 MUST-coalesce, amended 2026-04-26). The append uses the stage-then-rename idiom (write temp file, `mv -f` over canonical) for atomic-on-same-filesystem semantics; partial-write protection per LOG-012.
- A `verdict-mismatch` entry MAY be written by `run-emit-event.sh` if the LLM attempts to emit a route event without a fresh verdict receipt (ADR-022). The entry follows the same FR-006 schema as a semantic-failure halt.
- During a run, the canonical log has a **single writer at a time** — no locking required.

**Validation**: `run-validate-entry.sh` enforces the FR-006 schema on every appended entry. A malformed entry triggers a semantic-failure halt per FR-019.

---

## E-5 — Control-Flow Sidecar Event

**Location**: `specs/[###]/.run/control-flow.log` (JSONL — ADR-020)
**Format**: One JSON object per line, UTF-8, `\n`-terminated. See `contracts/sidecar-event.md` for the schema.

**Required fields**:
| Field | Type | Notes |
|---|---|---|
| `ts` | ISO-8601 string | UTC |
| `event` | enum | `stage-start`, `stage-skip`, `route`, `abort`, `break-lock`, `budget-exhausted` |
| `run_id` | string | Matches `run-lock` |

**Event-specific fields**:
| Event | Required | Optional |
|---|---|---|
| `stage-start` | `stage` | — |
| `stage-skip` | `stage`, `criterion` | — |
| `route` | `from`, `to`, `reason` | — |
| `abort` | `triggered_by` (`sentinel` or `subagent`) | `payload` (sentinel content) |
| `break-lock` | `prior_session`, `prior_ts` | — |
| `budget-exhausted` | `tier` (`run` or `merge`), `tokens` | — |

**Writers**: Orchestrator only, via `run-emit-event.sh`.

**Lifecycle**: Append-only during a run. At clean termination, orchestrator MAY coalesce events into a single canonical-log summary entry; the sidecar persists either way until the next run begins. Regenerable from artifact mtimes + canonical log (ADR-016) if corrupted.

---

## E-6 — Pipeline Stage Definition

**Conceptual entity** — the canonical pipeline ordering, encoded in `run-target.sh`.

**Canonical sequence** (FR-009 — selection only, no reordering):
```
specify → clarify → plan → tasks → analyze → implement → codereview → audit
```

`review` is interleaved per the existing speckit workflow (after spec, after plan, after tasks, pre-implementation) and is treated as a meta-stage by the orchestrator: it does not appear in the linear sequence above but is a permitted target component (`specify→review→plan` is valid; reordering is not).

**Review-contiguity grammar** (added 2026-04-26 post-plan-review per systems-architect F-08): `review` is a permitted *interstage token* in a target string when both adjacent tokens are non-code-action canonical stages. Formally:
- `review` MAY appear between two consecutive canonical stages from `{specify, clarify, plan, tasks, analyze}` (e.g., `specify→review→plan`, `plan→review→tasks`).
- At most one `review` token is permitted per inter-stage gap.
- `review` MAY NOT appear adjacent to a code-action stage (`implement`, `codereview`, `audit`); pre-implementation review is invoked through the BLOCKING-checkpoint mechanism (ADR-014), not as an inline target token.
- `review` MAY NOT appear at the start or end of a target string (a target like `review→plan` or `plan→review` is invalid).

`run-target.sh validate` enforces this grammar; ambiguous or malformed targets exit non-zero with a usage diagnostic.

**Constraints**:
- Target argument MUST be a contiguous subsequence (FR-009) of the canonical sequence, with `review` permitted per the grammar above.
- Code-action stages (`implement`, `codereview`, `audit`) are always BLOCKING in V1 (ADR-014, FR-008, FR-012).

---

## E-7 — Completeness Predicate (per stage)

**Conceptual entity** — encoded in `run-completeness.sh` per FR-026.

**V1 predicates**:

| Stage | Predicate | Implementation |
|---|---|---|
| `specify` | `spec.md` mandatory sections non-empty AND zero `[NEEDS CLARIFICATION]` markers | grep mandatory section headings, grep marker absence |
| `plan` | `plan.md` mandatory sections non-empty | grep section headings |
| `tasks` | `tasks.md` has at least one task block | grep `^- \[` |
| `review` | `decisions-log.md` has `entry_type=stage-end` for `review` matching the upstream stage | parse latest matching entry |
| `clarify`, `analyze` | `decisions-log.md` has matching `entry_type=stage-end` | parse latest matching entry |
| `implement` (destructive code-action) | Always re-runs (not resumable in V1) | predicate returns `incomplete` unconditionally |
| `codereview`, `audit` (additive code-action) | Always re-runs (not resumable in V1) | predicate returns `incomplete` unconditionally; postcheck (ADR-023) cross-checks claimed artifacts |

**Code-action distinction** (added 2026-04-26 per S-7 scope decision): all three code-action stages are unconditionally re-runnable in V1, but they differ in repository impact:
- `implement` is **destructive** — it mutates source files, may overwrite developer changes, and produces commits.
- `codereview` and `audit` are **additive** — they write reports under `specs/[###]/` and may propose ADR/LOG entries; they do not mutate project source.

ADR-023's pre-route postcheck applies to all three stages (the V1 scope is the code-action category, not the destructive subset). The distinction is documented here for V2 reasoning when partial-resume of additive stages may become tractable; V1 treats all three uniformly as not-resumable.

A file that exists but fails the predicate is treated as incomplete; the stage re-runs from the beginning (FR-026).

---

## E-8 — Sandbox Audit Result

**Conceptual entity** — produced by `run-check-sandbox.sh` after every code-action subagent dispatch.

**Implementation**: Reads `git diff` between pre- and post-dispatch HEAD; checks every modified path against the FR-020 allowlist:
- ALLOWED: paths under `specs/[###]/`, project source tree (heuristic: anything not in the disallowed list).
- DISALLOWED: `main` branch direct mutations, force-push detection (reflog check), `.gitignore`, `.github/`, `.claude/settings*.json`, `.claude/hooks/`, files matching `.env*`.

**Output**: exit code 0 if clean; non-zero with a path-by-path diagnostic if a violation is detected. The orchestrator then halts as a permission failure per FR-019.

---

## State Diagram (Pipeline Run)

```
┌──────────┐  acquire   ┌────────────┐
│  IDLE    │───────────▶│  RUNNING   │
└──────────┘            └────────────┘
                          │  │  │  │
            stage cycle ──┘  │  │  └── BLOCKING checkpoint
                             │  │
                       halt──┘  └──route to next stage
                       │
                       ▼
                  ┌────────────┐
                  │  HALTED    │  (developer retrigger required)
                  └────────────┘
                       │
                  release│break-lock
                       ▼
                  ┌──────────┐
                  │  IDLE    │
                  └──────────┘
```

**Transitions**:
- `IDLE → RUNNING` — `run-lock.sh acquire` succeeds; `stage-start` event emitted.
- `RUNNING → BLOCKING` — code-action stage about to dispatch, OR non-code stage at a configured checkpoint. Developer `proceed` resumes; `abort` transitions to HALTED via cleanup.
- `RUNNING → HALTED` — semantic / permission / temporal failure; lock retained until developer acknowledges.
- `RUNNING → RUNNING` (next stage) — completeness predicate plus halt-directive both indicate continue; route event emitted.
- `RUNNING → IDLE` — pipeline completes; `run-lock.sh release`; coalesced summary appended.
- `HALTED → IDLE` — developer issues retrigger or `--break-lock` after acknowledging the halt.
