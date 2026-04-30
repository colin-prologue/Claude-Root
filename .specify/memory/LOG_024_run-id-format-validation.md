# LOG-024: `run_id` Format Validation — Contract Loose, Script Permissive

**Date**: 2026-04-30
**Type**: OPEN-QUESTION
**Status**: Open
**Raised In**: PR2a eyeball review of `run-validate-entry.sh` against `specs/010-autonomous-workflow/contracts/decision-log-entry.md` §Validation contract
**Related ADRs**: ADR-013 (subagent-direct audit-trail writes), FR-006 (decision-log schema)

---

## Description

The validation contract (Rule 2) requires the `run_id` field to be "present and well-formed," but neither the contract nor the validator script enforces a format. The contract's example shows `run-2026-04-26T20:00:00Z-a1b2c3` (literal `run-`, ISO-8601 timestamp, six hex chars), but Validation §2 in `decision-log-entry.md` does not enumerate this format and the helper at line 105 only checks presence.

Bats fixtures cope by using the placeholder `run-x`, which would silently pass even though it does not match the example shape.

## Context

`run_id` is the cross-reference key between `decisions-log.md` and `.run/control-flow.log` (ADR-022 verdict-receipt protocol uses it as part of the receipt format `<verdict>\t<run_id>\t<input_hash>\t<ts>`). A malformed `run_id` would not be detected at write time and could silently break:

1. Resume scans (`run-completeness.sh` and `run-decide-next.sh` filter by `run_id`).
2. Receipt validation in `run-emit-event.sh` (cross-run `run_id` mismatch is supposed to refuse the routing event).
3. Sidecar/canonical correlation invariants (`run-serialize.sh` step-6 completeness check).

The current state is mutually consistent — contract says "well-formed", script accepts any non-empty value — but the consistency is by absence, not by agreement.

## Discussion

Three resolution paths:

1. **Tighten the contract** — define `run_id` format as `^run-<ISO-8601-UTC>-[a-f0-9]{6}$` (matches existing run-id minting in `run-common.sh`) and update the validator + bats fixtures to match.
2. **Tighten the script only** — keep contract loose, add format check to `run-validate-entry.sh`. Risks contract drift if the format is changed later in only one place.
3. **Document and defer** — accept that downstream helpers (lock, completeness, emit-event) will reject malformed `run_id` at their boundaries via cross-reference failure, and treat `run_id` format as a write-time invariant of `_run_id_of_lock` / `_hash_input` rather than a schema concern.

Path 1 is the durable answer (single source of truth, format-as-contract). Path 3 is the V1-pragmatic answer (no current code path emits a malformed `run_id`, so the gap is theoretical).

## Resolution

**Open.** V1 ships with the gap because no current writer emits a malformed `run_id` (the only minter is `_run_id_of_lock` in `run-common.sh`, which produces the canonical format). The risk surfaces only if a third-party tool or manual edit injects an entry — out of scope for V1's deterministic-orchestrator-core threat model.

This LOG should be re-evaluated when **any one** of the following conditions is met:

1. A future feature introduces a second `run_id` minter (e.g., a recovery tool that fabricates ids), making cross-source format drift possible.
2. Smoke-tier or integration tests fail in a way that traces back to a malformed `run_id` slipping through validation.
3. ADR-022 receipt format is extended to other identifiers, raising the question of whether identifier formats belong in the contract or in helper conventions.

**Resolved By**: TBD — candidates are (a) contract amendment + script tightening (Path 1), (b) closure-by-evidence if no malformed-id incident occurs through V2.
**Resolved Date**: N/A

## Impact

- [x] Spec referenced: `specs/010-autonomous-workflow/contracts/decision-log-entry.md` §Validation contract Rule 2
- [ ] Plan updated: N/A (validation gap, not a planning concern)
- [ ] Tasks updated: N/A
- [ ] ADR created: deferred — see Resolution
- [ ] Constitution amended: N/A
