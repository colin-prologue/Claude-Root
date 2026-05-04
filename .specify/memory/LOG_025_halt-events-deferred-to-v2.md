# LOG-025: `halt-*` Sidecar Events Deferred to V2

**Date**: 2026-05-04
**Type**: OPEN-QUESTION (resolution-by-deferral)
**Status**: Resolved
**Raised In**: PR2b implementation of `run-emit-event.sh` (T018) — doc inconsistency surfaced between ADR-022 and `contracts/sidecar-event.md`
**Related ADRs**: ADR-022 (verdict-receipt enforcement), ADR-020 (sidecar JSONL format)

---

## Description

ADR-022 step 2 names the routing-decision set as `{route, stage-skip, abort, halt-*}` — events that require receipt validation. `contracts/sidecar-event.md` enumerates only six event types (`stage-start`, `stage-skip`, `route`, `abort`, `break-lock`, `budget-exhausted`); **no `halt-*` family is defined**. The two contracts disagree on whether halts produce sidecar events.

## Context

When `run-decide-next.sh` mints a `halt:<reason>` verdict, the orchestrator must record the halt somewhere. Two paths are available:

1. **Sidecar path** (implied by ADR-022) — emit a `halt-<reason>` JSONL line via `run-emit-event.sh`, gated by the receipt protocol like every other routing event. Requires extending `sidecar-event.md` to enumerate the halt event family and its required fields.
2. **Canonical-only path** — record the halt entirely through `decisions-log.md`: the subagent-record's `halt_directive` block carries the halt reason and failure_class, and `run-serialize.sh` coalesces the run termination into a single canonical summary. No sidecar event is emitted for the halt itself.

V1 ships with path 2. The canonical decisions-log already records halts with full context (subagent record + halt_directive + coalesced summary at termination). The sidecar's purpose is routing telemetry between dispatches; when the run terminates on a halt, there is no subsequent stage to route to and the sidecar's per-event audit value is redundant with the canonical log.

## Decision

V1 routing-decision set in `run-emit-event.sh` is `{route, stage-skip, abort}`. A `halt:*` verdict in the receipt is rejected by `run-emit-event.sh` (any event name) with a `verdict-mismatch` canonical entry — the verdict was minted but no V1 sidecar event corresponds to it, which means the orchestrator should be terminating via `run-serialize.sh halt`, not attempting to emit. This makes the misuse loud rather than silent.

The `halt-*` slot in ADR-022's enumerated set is reserved for V2 if cross-stage halt telemetry becomes useful (e.g., dashboards that count halt-by-reason without parsing markdown).

## Resolution

**Resolved by deferral.** V1 implements path 2 (canonical-only). A future feature that needs halt telemetry in the sidecar should:

1. Extend `sidecar-event.md` to enumerate `halt-<reason>` events with required fields (`stage`, `failure_class`, `reason` at minimum).
2. Update `run-emit-event.sh`'s verdict↔event mapping to accept `halt:X` ⇒ `event=halt-X`.
3. Update the slash-command markdown to invoke emit-event on the halt path before invoking serialize.
4. Update Tier 1 unit tests (`test_emit_event.bats`) to cover the new event family.
5. Update Tier 1 static-grep test for slash-command invocation order (PR3b-ii).

**Resolved Date**: 2026-05-04 (deferred-and-tracked, not literally implemented)

## Impact

- [x] Contracts referenced: `contracts/helper-contracts.md` §`run-emit-event.sh`, `contracts/sidecar-event.md`
- [x] Helper updated: `run-emit-event.sh` rejects `halt:*` verdicts with a verdict-mismatch entry naming this LOG.
- [ ] Plan updated: N/A (V1 scope does not include halt sidecar events).
- [ ] ADR created: N/A (deferral, not a new architectural choice).
- [ ] Constitution amended: N/A
