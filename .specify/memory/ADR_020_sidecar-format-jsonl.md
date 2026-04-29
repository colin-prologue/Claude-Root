# ADR-020: Sidecar Format — JSONL for `.run/control-flow.log`

**Date**: 2026-04-26
**Status**: Proposed
**Decision Made In**: specs/010-autonomous-workflow/plan.md § Technical Context
**Related ADRs**: ADR-016 (canonical/derivative model — defines the sidecar's role)
**Related Logs**: None

---

## Context

ADR-016 introduced `specs/[###]/.run/control-flow.log` as a **regenerable derivative cache** for orchestrator-authored control-flow events (stage-start, stage-skip, route, abort). The canonical record is `decisions-log.md` (markdown, written by subagents). ADR-016 left the sidecar's wire format as a plan-phase decision: JSONL or structured markdown.

The sidecar's consumers and properties:
- **Writer**: `run-emit-event.sh` — appends one event per orchestrator decision.
- **Readers**: (a) the orchestrator on a coalesced-summary write at termination (per ADR-016); (b) developers inspecting a paused run; (c) future V2 cross-session-resume code that reconstructs orchestrator state.
- **Failure mode**: file may be partially written if the orchestrator process is killed mid-emit; the canonical record is unaffected. Recovery = drop a malformed last line and proceed.
- **Volume**: 5–20 events per run; total bytes <10KB. Not performance-sensitive.

The format does not need to optimize for human readability — `decisions-log.md` already serves that role. It needs to be cheap to append, cheap to parse, and tolerant of mid-line truncation.

## Decision

V1 ships **JSONL**: one JSON object per line, UTF-8, `\n`-terminated. Each line:

```json
{"ts":"2026-04-26T20:12:34Z","event":"stage-start","stage":"plan","run_id":"run-2026-04-26T20:00:00Z-a1b2c3"}
{"ts":"2026-04-26T20:12:35Z","event":"stage-skip","stage":"clarify","criterion":"no [NEEDS CLARIFICATION] markers","run_id":"..."}
{"ts":"2026-04-26T20:13:01Z","event":"route","from":"plan","to":"tasks","reason":"target-pipeline","run_id":"..."}
{"ts":"2026-04-26T20:14:12Z","event":"abort","triggered_by":"sentinel","run_id":"..."}
{"ts":"2026-04-26T20:14:13Z","event":"break-lock","prior_session":"...","prior_ts":"...","run_id":"..."}
```

Required fields per line: `ts` (ISO-8601 UTC), `event` (enumerated above), `run_id`. Event-specific fields (`stage`, `criterion`, `from`/`to`/`reason`, `triggered_by`, `prior_session`, `prior_ts`) are populated as applicable. Unknown fields are tolerated by readers (forward compatibility).

`run-emit-event.sh` writes via `printf '%s\n' "$json_line" >> "$file"` after constructing the line with `jq -cn`. Truncation recovery: if the last line of the file fails to parse, readers drop it; the canonical record remains intact.

## Alternatives Considered

### Option A: JSONL *(chosen)*

One JSON object per line.

**Pros**: Trivial append (`>> file`). Trivial parse (`jq -c '.'` per line). Truncation-tolerant (drop bad last line). Universally supported. `jq` already used elsewhere in the project. Future V2 cross-session reconciliation code parses lines independently; no full-file context needed. Schema evolution via additive fields is natural.
**Cons**: Not human-primary readable — but the sidecar isn't meant to be (canonical log is). Mid-line corruption produces an unparseable line, but a `\n`-terminated append rarely truncates mid-line on modern filesystems; and recovery is straightforward.

### Option B: Structured markdown

Each event a small markdown block (`### stage-start: plan` + key-value list).

**Pros**: Reads like the canonical log; same idiom; tools that read `decisions-log.md` work on the sidecar.
**Cons**: Append protocol is more complex (block boundaries, no clean line-oriented append). Truncation produces malformed blocks, harder to detect than a malformed JSON line. Parsing requires a markdown-section reader; the project doesn't have one. The sidecar's audience is primarily tooling, not humans, so the markdown-idiom benefit is small.

### Option C: TSV / pipe-delimited

Tab-separated columns.

**Pros**: Smallest possible parser.
**Cons**: Schema evolution is brittle (adding a column reorders existing data). Escaping rules for embedded tabs/newlines are error-prone. Not aligned with any existing tooling in the project.

## Rationale

The sidecar is a derivative cache (ADR-016) whose primary consumer is code, not humans. JSONL matches that audience: fast to append, fast to parse, schema-evolvable, truncation-tolerant. The canonical `decisions-log.md` retains its markdown format and human-primary role.

`jq` is already the project's JSON tool of choice (used in `setup-plan.sh` with a printf fallback). Reusing it keeps the dependency surface flat. The printf fallback path documented in `setup-plan.sh` carries over to `run-emit-event.sh` for environments without `jq`.

## Consequences

**Positive**: ADR-016 follow-on closes. Append-and-recover semantics are simple. Schema can evolve without breaking older readers (additive fields). Tooling reuse via `jq`.

**Negative / Trade-offs**: Developers reading the sidecar by hand see JSON, not markdown — acceptable because the canonical log is the primary surface. A second format to maintain alongside `decisions-log.md`'s markdown idiom; mitigated by the cache being short and append-only.

**Risks**:
- Sidecar corruption that goes beyond a single malformed line — mitigation: ADR-016's regeneration path (rebuild from artifact mtimes + canonical log) remains the recovery contract; sidecar can be deleted and rebuilt.
- `jq` unavailable in some shells — mitigation: printf fallback as in `setup-plan.sh`.

**Follow-on decisions required**: None for V1. V2 cross-session resume may promote the sidecar to canonical-on-disk-from-the-start (per ADR-016 § Risks); JSONL is the right format for that promotion as well.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-26 | Initial record (closes ADR-016 follow-on) | Claude (plan-phase for spec 010) |
