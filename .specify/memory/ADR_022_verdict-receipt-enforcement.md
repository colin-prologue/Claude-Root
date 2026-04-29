# ADR-022: Verdict-Receipt Enforcement Between `run-decide-next.sh` and `run-emit-event.sh`

**Date**: 2026-04-26
**Status**: Proposed
**Decision Made In**: specs/010-autonomous-workflow/plan.md § Project Structure (post-plan-review revision)
**Related ADRs**: ADR-019 (deterministic core boundary), ADR-016 (canonical/derivative model), ADR-020 (sidecar JSONL format)
**Related Logs**: LOG-011 (BLOCKING-gate rubber-stamping risk)

---

## Context

ADR-019 places the orchestrator's routing logic in `run-decide-next.sh` and constrains the slash-command markdown to obey its single-line stdout. ADR-019's risk section names the load-bearing failure mode: **the LLM bypasses the helper and routes from its own reading of `decisions-log.md`**. The mitigation listed there is "Tier 2 smoke runs assert that the orchestrator's recorded route matches what `run-decide-next.sh` would have output."

The plan-gate review's HIGH finding F-01 (systems-architect) sharpened the gap: that mitigation is post-hoc, smoke-tier only, and easy to accommodate by an LLM that emits a plausible-looking route event without ever invoking the helper. There is no in-band signal that prevents the bypass at the moment it would happen. The deterministic core's testability is theatre if the LLM can author route events without proof of helper invocation.

The reframe, surfaced by the devil's advocate: **V1 is the project's first orchestrator that will be used to build itself.** Every subsequent ADR, spec, and audit record produced by `/speckit.run` carries the orchestrator's choices in its lineage. A silent bypass is not a bug to be discovered later — it is contamination of the audit substrate. The mitigation must run in-band, on every dispatch, in V1.

## Decision

V1 ships a **verdict-receipt protocol** between the deterministic helpers, providing structural detection of both *forgery* (LLM authors a route event without invoking the helper) and *omission* (LLM invokes the helper but never emits the event):

1. `run-decide-next.sh` writes its single-line verdict to `specs/[###]/.run/last-verdict` (a one-line file: `<verdict>\t<run_id>\t<input_hash>\t<ts>`) **in addition to** stdout.
2. `run-emit-event.sh`, when emitting a `route`, `stage-skip`, `abort`, or `halt-*` event, **MUST** read `.run/last-verdict` and assert that the event being written matches the verdict.
3. On **mismatch** OR **missing/empty receipt**, `run-emit-event.sh` exits non-zero, refuses to write the event to the sidecar, and writes a `verdict-mismatch` semantic-failure entry to `decisions-log.md` via the same canonical path the subagent uses (per ADR-013). Missing-receipt is treated identically to mismatched-receipt: the LLM either bypassed `run-decide-next.sh` entirely or attempted a second emission after the first consumed the receipt.
4. `last-verdict` is consumed (truncated to 0 bytes) on a successful matched emission. A subsequent emission attempt without a fresh verdict fails per step 3.
5. **Omission detection (in-band)** — `run-decide-next.sh` checks `.run/last-verdict` size at start of every invocation. **If the receipt is non-empty** (a prior verdict was minted but never consumed by an emission), the helper refuses to mint a new verdict, exits non-zero, and writes a `verdict-omitted` semantic-failure entry to `decisions-log.md`. This catches the case where the LLM invoked `run-decide-next.sh` on stage N, skipped `run-emit-event.sh`, and proceeded to stage N+1's helper invocation.
6. **Pipeline completeness invariant (termination-time)** — `run-serialize.sh`, before appending the coalesced summary, asserts that (a) `.run/last-verdict` is empty (no unconsumed verdict), and (b) the sidecar `.run/control-flow.log` contains at least one routing-decision event for every stage that has a per-stage record in `decisions-log.md`. On mismatch, it writes a `pipeline-incomplete` semantic-failure entry to the canonical log before the coalesced summary, surfacing the omission in the durable audit trail.

The contract is symmetric: the LLM cannot legally emit a route without a fresh verdict on disk; the LLM cannot mint a verdict without consuming the prior one; and a run cannot terminate cleanly with un-emitted verdicts or stage records lacking sidecar events. **Bypass is structurally detected — both forgery and omission produce a canonical-log entry visible in the audit substrate**, where prior framing claimed only "structural impossibility." The detection is in-band on every dispatch, not post-hoc on smoke fixtures.

## Alternatives Considered

### Option A: Verdict-receipt enforcement *(chosen)*

Helpers cooperate via a one-shot on-disk receipt; emission helper refuses unmatched events.

**Pros**: Bypass is detected in-band, on every run, before the corrupt event lands in either the sidecar or the canonical log. The check is a 5-line bash function (read file, compare, refuse). Tier 1 unit-tests cover the protocol exhaustively (write a verdict, attempt mismatched emission, assert refusal). Smoke-tier asserts that a clean run produces zero `verdict-mismatch` entries — an invariant, not a probabilistic check. Self-modifying-tool concern is addressed in V1.
**Cons**: One additional file in `.run/`. Coupling between two helpers via a third artifact. If the receipt file is corrupted by an unrelated process, the next emit fails — but this is the desired failure mode (refuse to write rather than write speculatively).

### Option B: Post-hoc smoke-tier reconciliation only

Keep ADR-019's original mitigation: smoke runs compare actual route events to what the helper would have decided.

**Pros**: Zero V1 implementation cost; no protocol change.
**Cons**: Bypass goes undetected on every run that isn't a smoke-fixture run — i.e., every developer use. Contamination of audit records is the modal outcome of an LLM that learns to skip the helper. The smoke fixture covers `specify→plan` (ADR-021); a bypass on `tasks` or any other stage is invisible.

### Option C: Single-process guard — slash-command markdown rewrites helper invocation as the only legal path

Strengthen the prompt: "you MUST invoke `run-decide-next.sh` and obey its output."

**Pros**: No protocol; no new file.
**Cons**: A prompt-only constraint is exactly what ADR-019 was designed not to depend on. The whole point of the deterministic core is to take routing out of the LLM's prose-following discretion. Doubling down on prose is the regression.

### Option D: Verdict signed with a per-run nonce, validated cryptographically

Same as Option A but with an HMAC over the verdict to prevent the LLM from forging the receipt file.

**Pros**: Forgery-resistant.
**Cons**: The threat model is "LLM forgets to invoke the helper," not "LLM actively forges receipts." A bash script writing an HMAC adds dependency surface (`openssl` or similar) for a threat that doesn't apply. Reconsider in V2 only if a forgery pattern appears.

## Rationale

The deterministic core is load-bearing only if it is structurally enforced. A test-only enforcement (Option B) re-introduces the LLM-as-trusted-router posture that ADR-019 explicitly rejected. The receipt protocol is the smallest in-band check that makes the bypass impossible without making the helpers themselves more complex than their FRs require.

The receipt is one-shot and run-id-scoped. A leftover receipt from a prior run is invalid (the `run_id` field won't match the current lock). A forged receipt requires the LLM to read the lock, hash the input, and write the file in the helper's exact format — which is more LLM work than just invoking the helper. The cheapest path for the LLM to satisfy the constraint is to call the helper. That is the design property we want.

The five-line check has a single failure mode (mismatch → refuse) and a single side effect (consume on match). It composes cleanly with the existing canonical-write path: a `verdict-mismatch` is just another semantic-failure entry, handled by the same halt machinery as a schema violation.

## Consequences

**Positive**: ADR-019's deterministic core is structurally enforced, not aspirationally enforced. Self-modifying-tool concern (V1 builds the orchestrator with the orchestrator) is addressed: every record in the audit substrate carries the property that the route was helper-decided. Tier 1 tests gain a meaningful invariant (verdict consumption + refusal semantics). Smoke tier gains a binary pass/fail (zero `verdict-mismatch` entries on the green path).

**Negative / Trade-offs**: Two helpers are coupled via a third artifact in `.run/`. The orchestrator's invocation order becomes load-bearing: `run-decide-next.sh` MUST run immediately before `run-emit-event.sh` for any routing event. Documented as part of the slash-command's enforced sequence; covered by Tier 1.

**Risks**:
- Receipt file lingers across runs — mitigation: `run-lock.sh acquire` wipes `.run/last-verdict` as part of lock setup; `run-lock.sh release` wipes it as part of cleanup. Receipt file is treated as runtime state, not durable artifact.
- LLM emits events for non-routing reasons (e.g., `stage-start` carries no routing decision) — mitigation: `run-emit-event.sh` only enforces the receipt for events in the routing-decision set (`route`, `stage-skip`, `abort`, `halt-*`). `stage-start` and `break-lock` are emitted without receipt requirement.
- A future helper introduces a new routing event type without updating the enforcement set — mitigation: the enforcement set is documented in `helper-contracts.md` and Tier 1 covers each enumerated event type explicitly; adding a new type without updating the test is a contract violation caught at unit-test time.
- **LLM skips both `run-decide-next.sh` AND `run-emit-event.sh` for a stage** — neither in-band check fires (no verdict to mint, no event to emit). Mitigation: termination-time pipeline-completeness invariant (Decision step 6) compares stage records in `decisions-log.md` against routing events in the sidecar; missing-event-for-stage produces a `pipeline-incomplete` canonical entry. Test-time mitigation: Tier 1 static-grep test on `.claude/commands/speckit.run.md` asserts the slash-command markdown invokes `run-decide-next.sh` and `run-emit-event.sh` for every routing point in the prescribed sequence (catches authoring drift before runtime).

**Follow-on decisions required**: None for V1. V2 may extend the receipt to cover `stage-start` if cross-session resume requires reconstructing pre-dispatch state.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-26 | Initial record (post-plan-review revision; closes F-01 helper-bypass blocker) | Claude (synthesis-judge for spec 010 plan-gate) |
| 2026-04-26 | Plan-gate re-review revision: closed C-1/C-2 omission gap with in-band check (Decision step 5) and termination-time completeness invariant (Decision step 6); reframed "structurally impossible" → "structural detection of forgery + omission"; added test-time static-grep guard against `speckit.run.md` invocation-order drift | Claude (synthesis-judge for spec 010 plan-gate re-review) |
