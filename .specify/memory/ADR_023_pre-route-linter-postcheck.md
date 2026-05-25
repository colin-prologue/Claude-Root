# ADR-023: Pre-Route Linter Postcheck on Subagent Artifacts

**Date**: 2026-04-26
**Status**: Accepted
**Decision Made In**: specs/010-autonomous-workflow/plan.md § Project Structure (post-plan-review revision)
**Related ADRs**: ADR-019 (deterministic core boundary), ADR-013 (subagent direct-write), ADR-014 (BLOCKING-by-default at code-action gates)
**Related Logs**: LOG-010 (non-code-stage claimed-vs-actual artifact validation deferred), LOG-011 (BLOCKING-gate rubber-stamping risk)

---

## Context

ADR-013 places the subagent in charge of writing its per-stage record to `decisions-log.md`. The orchestrator reads what the subagent wrote and routes accordingly. ADR-019 makes the route deterministic via `run-decide-next.sh`. Neither ADR audits the **artifacts the subagent claims to have produced**.

The plan-gate review surfaced the gap (delivery-reviewer F-09, devil's advocate Phase B): a code-action subagent (`implement`, `codereview`, `audit`) can claim success in its decision-log entry while the actual repository state — staged files, ADR cross-refs, prerequisite checks — is in a state that a developer should never proceed from. BLOCKING-everywhere (ADR-014) puts the developer in front of every code gate, which is the right choice for *catching* the problem, but it is not a substitute for *surfacing* it. A developer presented with "✓ implement complete" who is rushing to merge will rubber-stamp; the audit substrate then carries an unverified claim.

The reframe (devil's advocate, Phase B): **the orchestrator's job at a code-action gate is to give the developer something pre-checked to react to, not just a pre-formatted decision.** The deterministic core can run cheap, existing linters on the post-dispatch artifact set and surface their findings as part of the BLOCKING checkpoint payload. If a check fails, the route stays at `halt:postcheck-failed`; the developer sees the specific failures, not a generic "review required."

Scope boundary (locked at plan-gate): V1 applies the postcheck to **code-action stages only** (`implement`, `codereview`, `audit`). Non-code stages (`specify`, `plan`, `tasks`) ship without artifact-vs-claim cross-checking; LOG-010 captures the deferred work.

## Decision

V1 ships a `run-postcheck.sh` helper invoked **after** every code-action subagent dispatch and **before** `run-decide-next.sh`:

1. **Inputs**: `<feature-dir> <stage>`. Reads the just-written subagent record, the post-dispatch git index, and the affected files.
2. **Checks** (all already in the project):
   - `check-adr-crossrefs.sh` — every ADR/LOG referenced in the subagent record exists; every newly-created ADR/LOG has at least one inbound reference (Principle VII).
   - `check-prerequisites.sh --feature-dir <feature-dir>` **[PRECURSOR: PR0 — adds this flag; script exits 1 on `--feature-dir` today]** — feature-dir invariants hold (spec.md, plan.md, tasks.md exist as required by stage; constitution.md present). The `--feature-dir` flag is added by PR0 (Re-Review #2 RC-2 / Re-Review #3 S-1) before `run-postcheck.sh` can be implemented; without it the helper would silently validate the branch-derived feature path under `--resume --feature-dir=...`.
   - For `implement` only: the diff under `specs/[###]/` does not contain claims of test files that don't exist (grep `tasks.md` for "test_*" entries vs `git ls-files`).
3. **Output**: empty on clean; one finding per line on failure (`<check>: <detail>`).
4. **Exit code**: 0 on clean → `run-decide-next.sh` runs normally. Non-zero → orchestrator emits `halt:postcheck-failed` with the findings appended to the BLOCKING-checkpoint payload; the developer sees specific failures inline.

The postcheck is **not** a replacement for `run-check-sandbox.sh` (FR-020 path-allowlist enforcement). Sandbox checks "did the subagent touch a file it shouldn't have." Postcheck asks "do the artifacts the subagent claims to have produced satisfy the cross-references and prerequisites the project requires." Both run; both are independent gates.

## Alternatives Considered

### Option A: Pre-route linter postcheck on code-action stages *(chosen)*

`run-postcheck.sh` runs after every code-action dispatch; failures suppress the route and surface in the BLOCKING payload.

**Pros**: Reuses existing project linters (`check-adr-crossrefs.sh`, `check-prerequisites.sh`) — no new validation logic. Findings reach the developer at the moment of decision, not in a follow-up audit. Addresses the rubber-stamping risk (LOG-011) in-band by giving the developer something concrete to react to. Scope is bounded to where the risk is highest (code-action stages produce the audit-contaminating outputs).
**Cons**: Adds one helper dispatch (~200ms) per code-action stage; negligible vs. subagent latency. The postcheck's findings can be wrong (linter false positives); the developer can override by `proceed`-ing with the failures visible. False-positive overrides become themselves audit signal.

### Option B: No artifact-vs-claim check; rely on `/speckit.codereview` and `/speckit.audit` after the run

Trust the BLOCKING checkpoint and the post-implement audit pipeline to catch claim/artifact mismatches.

**Pros**: Zero V1 implementation cost; alignment with "audit catches drift" already in the workflow.
**Cons**: The codereview and audit stages run **inside** the same `/speckit.run` invocation. If the orchestrator routes from `implement` to `codereview` based on a contaminated implement-record, codereview operates on a flawed premise. The contamination propagates within the run, not across runs. Post-run audit is the wrong granularity.

### Option C: Apply postcheck to all stages, not just code-action

Run the linter set after every stage, including `specify`, `plan`, `tasks`.

**Pros**: Consistency; no scope boundary to remember.
**Cons**: The non-code stages produce markdown artifacts whose claim/actual relationship is harder to validate cheaply. `check-adr-crossrefs.sh` already covers their cross-refs; `check-prerequisites.sh` already covers file existence; there is no current cheap check that reads `spec.md` and audits whether its FRs match later artifacts. Building one is V2 work (LOG-010). Including it in V1 expands the scope without an existing-tool reuse story.

## Rationale

The orchestrator's value over plain manual stage-by-stage invocation is **integration of cheap automated checks at the gate where they matter**. ADR-014 puts the developer in front of every code gate, which addresses the *decision* surface; the artifact surface needs its own cheap pre-pass. Existing linters do the work — the helper just composes and presents.

Code-action scoping aligns with V1's risk model: code stages mutate the repository and produce the records future audits will reason from. A claimed-but-missing test in `tasks.md` is a contaminating signal; a claimed-but-vague rationale in `spec.md` is a quality issue but not a structural one. The line is intentional and documented in LOG-010 for V2 reconsideration.

The postcheck running before `run-decide-next.sh` (rather than after) is load-bearing: a halt verdict from postcheck gives the developer the failures inline; a halt after route would force the developer to read both the route summary and the postcheck output as separate surfaces.

## Consequences

**Positive**: BLOCKING checkpoints carry concrete pre-checked findings, not just "review the diff." Audit-substrate contamination from code-action stages is reduced to "developer overrode an explicit warning" — observable in the canonical log, not silent. Reuse of existing linters keeps the helper surface small.

**Negative / Trade-offs**: One additional helper invocation per code-action stage. The slash-command markdown's invocation order is now: dispatch → record validate → postcheck (code-action only) → decide-next → emit-event. Documented in `helper-contracts.md`; covered by Tier 1.

**Risks**:
- False-positive linter findings produce checkpoint friction — mitigation: developers can `proceed` past warnings; the override is captured in the canonical log (FR-006 `entry_type=route` with `reason=postcheck-override`); a pattern of overrides on the same check is an LOG signal to retune the linter.
- Linter set grows beyond two checks and the postcheck becomes its own complexity surface — mitigation: each linter included is independently reviewed; new entries require an ADR amendment to this record.
- The postcheck runs only on code-action stages, leaving non-code stage contamination unchecked — accepted in V1 (LOG-010); reconsider after dogfooding evidence under SC-008.

**Follow-on decisions required**: None for V1. V2 considers extension to non-code stages per LOG-010.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-26 | Initial record (post-plan-review revision; closes F-09 BLOCKING-rubber-stamping blocker for code-action stages) | Claude (synthesis-judge for spec 010 plan-gate) |
