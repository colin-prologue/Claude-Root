# Contract — Sidecar Event (JSONL)

**File**: `specs/[###]/.run/control-flow.log`
**Format**: JSONL — one JSON object per line, UTF-8, `\n`-terminated.
**Writer**: orchestrator only. Non-routing events (`stage-start`, `break-lock`, `budget-exhausted`) via `run-emit-event.sh`; routing events (`route`, `stage-skip`, `abort`) via `run-route.sh`.
**Source of truth**: ADR-020.

---

## Required fields

Every line MUST include:

| Field | Type | Constraint |
|---|---|---|
| `ts` | string | ISO-8601 UTC with `Z` suffix |
| `event` | string | One of: `stage-start`, `stage-skip`, `route`, `abort`, `break-lock`, `budget-exhausted` |
| `run_id` | string | Matches the `run_id` in the active `run-lock` |

## Event-specific fields

### `stage-start`
```json
{"ts":"2026-04-26T20:12:34Z","event":"stage-start","stage":"plan","run_id":"run-..."}
```
- `stage` — canonical pipeline stage name (required).

### `stage-skip`
```json
{"ts":"...","event":"stage-skip","stage":"clarify","criterion":"no [NEEDS CLARIFICATION] markers in spec.md","run_id":"..."}
```
- `stage` — required.
- `criterion` — free-text reason the predicate evaluated to "skip" (required).

### `route`
```json
{"ts":"...","event":"route","from":"plan","to":"tasks","reason":"target-pipeline","run_id":"..."}
```
- `from`, `to` — canonical stage names (required).
- `reason` — one of: `target-pipeline` (next in target subset), `halt-cleared` (developer issued `proceed`), `clarify-resolved`, free-text otherwise (required).

### `abort`
```json
{"ts":"...","event":"abort","triggered_by":"sentinel","run_id":"..."}
{"ts":"...","event":"abort","triggered_by":"subagent","payload":"context-exhausted","run_id":"..."}
```
- `triggered_by` — `sentinel` (developer-set abort file) or `subagent` (subagent halted with abort directive) (required).
- `payload` — optional free-text (e.g., contents of the abort sentinel file).

### `break-lock`
```json
{"ts":"...","event":"break-lock","prior_session":"run-2026-04-26T19:45:00Z-9e8f7d","prior_ts":"2026-04-26T19:45:00Z","run_id":"run-..."}
```
- `prior_session`, `prior_ts` — contents of the lock file being broken (required).
- `run_id` — the new session's id.

### `budget-exhausted`
```json
{"ts":"...","event":"budget-exhausted","tier":"run","tokens":51234,"run_id":"..."}
```
- `tier` — `run` (per-run cap exceeded) or `merge` (per-merge cap exceeded) (required).
- `tokens` — total tokens consumed at the moment of detection (required).

## Forward compatibility

Readers MUST tolerate unknown fields. Writers MUST NOT remove or rename existing fields without a new ADR.

## Truncation recovery

If the last line of the file fails JSON parsing, readers drop it silently and treat the file as ending at the last well-formed line. The canonical `decisions-log.md` is unaffected by sidecar truncation.

## `run-emit-event.sh` contract

Invocation:
```
run-emit-event.sh <feature-dir> <event-name> <key=value>...
```

Behavior:
- Constructs the JSON line via `jq -cn` (printf fallback if `jq` unavailable, matching `setup-plan.sh`).
- Stamps `ts` to current UTC time and `run_id` from `run-lock`.
- Appends with `printf '%s\n' >> "$file"`.

Exit codes:
- `0` — line written.
- `1` — write failed (filesystem error).
- `2` — usage error (no run-lock present, unknown event, missing required field for the event type).
