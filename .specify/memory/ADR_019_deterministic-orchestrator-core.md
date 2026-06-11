# ADR-019: Bash-Helper-Driven Deterministic Orchestrator Core

**Date**: 2026-04-26
**Status**: Accepted
**Decision Made In**: specs/010-autonomous-workflow/plan.md § Project Structure
**Related ADRs**: ADR-013 (subagent writes decision-log directly), ADR-016 (canonical/derivative model), ADR-017 (hybrid TDD strategy)
**Related Logs**: None

---

## Context

ADR-017 split the orchestrator's surface into a deterministic part (TDD-strict, Tier 1) and a non-deterministic LLM-call part (Tier 2 smoke). It did not specify where the boundary lives in code. Without an explicit boundary, the routing logic — "does the latest decision-log entry indicate halt?", "is the next stage in the target subset?", "did the spec already exist when invoked?" — floats inside the LLM-driven slash-command markdown. Tier 1 then has no testable surface beyond utility helpers, and the hybrid strategy collapses to "test some helpers, hope the LLM follows the prompt."

The spec's FR-021 through FR-028 (the control-flow FRs added in revision) are all expressible as deterministic functions over on-disk state. So is FR-006 schema validation, FR-026 completeness, FR-020 sandbox allowlist enforcement, and FR-005's locking-free write protocol (per ADR-016).

If those functions live in the LLM prompt, they cannot be unit-tested. If they live in bash helpers that the slash command is required to invoke, they can.

## Decision

The orchestrator's deterministic surface is implemented as **discrete bash helper scripts in `.specify/scripts/bash/run-*.sh`**. The slash-command markdown (`/speckit.run`) is reduced to:

1. Parse `$ARGUMENTS` (target pipeline + checkpoint policy).
2. Invoke `run-lock.sh acquire` (sweeps `.run/*.tmp` per LOG-012).
3. For each stage in target:
   a. Invoke `run-completeness.sh <stage>` — if complete, write `stage-skip` entry to `decisions-log.md` and emit the sidecar event via `run-route.sh`, then continue.
   b. Otherwise: invoke `run-lock.sh check-sentinel` (FR-027) — abort immediately if the sentinel file is present. Then dispatch a fresh subagent (Task tool) with the stage's standard speckit prompt + an FR-006-conforming instruction to write its per-stage record to `decisions-log.md`.
   c. After dispatch returns, record the per-stage diff (`git diff <pre-dispatch-head>..HEAD`) to `.run/stage-diff-<stage>.{files,patch}` for independent auditing.
   d. Invoke `run-validate-entry.sh` on the appended entry; halt as semantic failure (FR-019) if invalid.
   e. **For code-action stages only** (`implement`, `codereview`, `audit`): invoke `run-check-sandbox.sh` (FR-020), then `run-postcheck.sh` (ADR-023). Failures suppress the route and surface findings inline in the BLOCKING-checkpoint payload.
   f. Invoke `run-route.sh` — its single-line stdout (`continue|halt:<reason>|abort|skip:<stage>`) is the only routing input the LLM acts on. The helper writes the corresponding sidecar event atomically.
4. At every BLOCKING checkpoint (ADR-014), present the developer-facing summary (artifact path + status + next stage + any postcheck findings) and wait for `proceed`/`abort`.
5. On termination (halt, abort, permission-failure, clean), append the coalesced summary to `decisions-log.md` via stage-then-rename (ADR-016 MUST-coalesce), then invoke `run-lock.sh release` (or `run-lock.sh break` for ADR-018 recovery).

The LLM's only non-deterministic responsibilities are: dispatching subagents (the Tier 2 boundary), formatting the BLOCKING-checkpoint summary for the developer, and rendering the final completion report. Every routing choice is the output of a helper.

## Alternatives Considered

### Option A: LLM-resident routing logic

The slash-command markdown describes the routing rules in prose; the LLM follows them when reading `decisions-log.md`.

**Pros**: Smallest implementation surface — no helpers to write. Routing rules read like documentation, not code.
**Cons**: Routing logic is untestable below the smoke tier. ADR-017's Tier 1 has nothing meaningful to assert. Prompt drift can silently change routing behavior; only Tier 2 catches it, expensively. Constitution Principle III is honored in form, not substance.

### Option B: Bash helpers as the deterministic core *(chosen)*

Routing rules live in `.specify/scripts/bash/run-*.sh`; LLM invokes them and obeys their output.

**Pros**: Tier 1 covers the actual control-flow surface, not just utility helpers. Each FR (FR-006, FR-009, FR-020 to FR-028) maps 1:1 to a helper with a unit-testable contract. Helpers are reusable from outside the slash command (e.g., a future stage-pair runner per LOG-005). Constitution Principle III is genuinely satisfied for the tested surface; Principle II is satisfied because each helper has a single purpose.
**Cons**: 7 small bash scripts to maintain. Bash arithmetic and string handling have well-known footguns; `set -euo pipefail` and bats coverage mitigate but don't eliminate. Context-switching cost (LLM dispatches → reads on-disk entries → invokes helper → reads output) adds startup time but is negligible vs. subagent latency.

### Option C: Python helpers with the same boundary

Same boundary as Option B, but helpers in Python.

**Pros**: Stronger language semantics; richer test ergonomics.
**Cons**: Reintroduces the Python/uv dependency footprint that 009-remove-memory-server explicitly removed. The helpers' surface (read a file, parse a markdown section, return a string verdict) does not need Python's expressiveness. Bash + bats is the project's native stack.

## Rationale

ADR-017 names the deterministic surface; this ADR locates it. Without the location, ADR-017 is aspirational. The bash-helper boundary is consistent with the existing project stack (`setup-plan.sh`, `check-prerequisites.sh`, `update-agent-context.sh`, `check-adr-crossrefs.sh`) — adding `run-*.sh` is incremental, not a new dependency class.

The reusability of helpers is a load-bearing pro: LOG-005 (stage-pair runner as V1.5 fallback) wants the same routing primitives. If the orchestrator had embedded them in prose, LOG-005 would mean reimplementing them in a second prompt. With Option B, the stage-pair runner is a thinner slash command over the same helpers.

## Consequences

**Positive**: Tier 1 coverage matches ADR-017's intent. Routing logic is testable, version-controlled, and visible in diffs. Reuse path for LOG-005 is open. The slash-command markdown shrinks because routing rules become helper invocations, not prose paragraphs.

**Negative / Trade-offs**: 7 helpers to write and maintain. Bash failure modes (variable quoting, signal handling, exit-code semantics) require care; mitigated by `set -euo pipefail` everywhere and a shared `common.sh`. **Sentinel-detection fold-in (b1)**: by routing `abort` through `run-decide-next.sh` rather than a fast-path orchestrator check, the abort-detection latency now matches the rest of the routing protocol (a full helper invocation per stage rather than a one-line file-existence test). This trades fast-path responsiveness for invariant uniformity — every routing decision, including abort, flows through the verdict-receipt path so the audit substrate carries one rule, not two. Aligned with the disk-as-source-of-truth principle (workers write to disk; coordinator reads disk for routing; coordinator never trusts its own in-memory cache of sentinel state).

**Risks**:
- LLM bypasses helpers and routes from its own reading of `decisions-log.md` — mitigation: `run-validate-entry.sh` enforces the FR-006 schema on every appended entry (halt on violation); `run-route.sh` is the single atomic routing helper whose stdout the LLM must relay verbatim. Smoke runs assert correct routing on the green path.
- Helpers grow features beyond their FR mapping — mitigation: each helper's contract is documented in `specs/010-autonomous-workflow/contracts/helper-contracts.md`. New behavior requires either an FR or an ADR.
- BLOCKING-gate rubber-stamping degrades the audit-trail property — mitigation: **ADR-023 pre-route postcheck** surfaces concrete pre-checked findings inline in the BLOCKING payload for code-action stages; LOG-011 tracks the residual rubber-stamping risk and the SC-008 measurement plan.

**Follow-on decisions required**: None for V1. ADR-023 (pre-route postcheck) closes the code-action artifact-vs-claim gap. V2 may consolidate helpers if reuse patterns emerge.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-26 | Initial record | Claude (plan-phase for spec 010) |
| 2026-04-26 | Codified verdict-receipt enforcement (ADR-022) and pre-route postcheck (ADR-023) into the deterministic core; updated invocation sequence to reflect both; cross-referenced LOG-011 for residual rubber-stamping risk | Claude (synthesis-judge for spec 010 plan-gate revision) |
| 2026-04-26 | Plan-gate re-review (C-5 sentinel/route ordering): folded `.run/abort` sentinel detection into `run-decide-next.sh` as a state input ahead of other routing logic; removed the standalone "check between every dispatch" step. Abort routing is now gated by the verdict-receipt protocol like every other route, at the cost of the fast-path file-existence check. | Claude (synthesis-judge for spec 010 plan-gate re-review) |
| 2026-05-16 | LOG-026: verdict-receipt protocol (ADR-022) eliminated. `run-decide-next.sh` and `run-emit-event.sh` (routing role) replaced by single `run-route.sh`. Sentinel detection restored as pre-dispatch `run-lock.sh check-sentinel` call (fast-path, before subagent launch). Decision section updated to reflect current 6-helper invocation sequence. | Claude (consistency-auditor) |
