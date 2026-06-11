# Phase 0 Research — `/speckit.run` Orchestrator

**Date**: 2026-04-26
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

This document consolidates the technology and architectural decisions made during plan-phase research. Every NEEDS-CLARIFICATION item from the plan template is resolved below; each decision links to the ADR that records it.

---

## R-1 — Orchestrator location: slash command vs. external runtime

**Decision**: Orchestrator is the `.claude/commands/speckit.run.md` slash command, executed by the Claude Code main session. No external process, daemon, or watcher. → **ADR-008**.

**Rationale**: Spec FR-016 mandates `/speckit.run` as the trigger and explicitly says other speckit commands remain unchanged. The simplest realization is a sibling slash command in the same `.claude/commands/` directory. Adding a runtime would re-introduce dependency footprint that 009-remove-memory-server explicitly extracted.

**Alternatives considered**: External Python runtime (rejected — reverts the dependency cleanup); shell-driven daemon (rejected — single-session V1 doesn't need persistent state outside the main session).

---

## R-2 — Stage execution context: subagent per stage

**Decision**: Every stage dispatches to a fresh subagent via the Task tool. Orchestrator runs in the main session as a thin coordinator. → **ADR-009**.

**Rationale**: Resolved in spec clarifications session 2026-04-25 (Q2). Matches the user's existing manual `/clear`-between-phases practice and prevents cross-phase reasoning pollution.

---

## R-3 — Decision-log writer protocol

**Decision**: Subagent is the canonical writer of `decisions-log.md` (per-stage record before exit). Orchestrator writes control-flow events to a regenerable sidecar at `specs/[###]/.run/control-flow.log` and may append a single coalesced summary at clean termination. Locking-free: only one writer at a time. → **ADR-013**, refined by **ADR-016**.

**Rationale**: Subagent records are irreplaceable witnesses (their reasoning context); orchestrator events are derivable from artifact state. Asymmetric durability ⇒ canonical/derivative split avoids concurrent-write protocols entirely in V1.

---

## R-4 — Sidecar wire format

**Decision**: JSONL — one JSON object per line in `.run/control-flow.log`. Required fields: `ts`, `event`, `run_id`. Event-specific fields populated as applicable. → **ADR-020**.

**Rationale**: Sidecar's primary consumer is code (orchestrator's coalesced-summary write; future V2 cross-session reconciliation). JSONL is append-friendly, parse-friendly (`jq`), truncation-tolerant (drop bad last line), and forward-compatible via additive fields.

**Alternatives considered**: Structured markdown (rejected — append protocol is more complex; truncation harder to detect); TSV (rejected — schema evolution brittle).

---

## R-5 — Failure handling

**Decision**: Three-class taxonomy — temporal, semantic, permission/exhaustion. V1 halts on all three classes and requires explicit developer re-trigger. Cross-session auto-resume on temporal failures is V2. → **ADR-011**, scoped by **ADR-015**.

**Rationale**: Resolved in spec clarifications (Q4). Trust-first posture: halt-and-let-developer-decide is preferable to silent continuation on indeterminate state.

---

## R-6 — Sandbox for code-action subagents

**Decision**: Branch-scoped sandbox. ALLOWED: write/edit/delete in `specs/[###]/` and project source tree, run tests, commit to feature branch. DISALLOWED: push, modify `main`, force ops, modify `.gitignore`/CI/hooks outside scope, create files matching secret patterns. → **ADR-012**.

**Rationale**: Resolved in spec clarifications (Q5). The `.run/` runtime directory is gitignored at template-setup time per the ADR-012 amendment, removing the tension where the orchestrator would otherwise need to modify `.gitignore` at runtime (which the sandbox forbids).

---

## R-7 — Checkpoint posture

**Decision**: V1 ships single-mode BLOCKING-everywhere. All code-action gates (`pre-implement`, `pre-codereview`, `pre-audit`) are forced BLOCKING regardless of policy; non-code gates are also BLOCKING because V1 has no OBSERVING mode. → **ADR-014**.

**Rationale**: Resolved in spec revision after Phase A review. Trust-first hierarchy in spec § Goal Hierarchy. OBSERVING and checkpoint-decision files return in V2.

---

## R-8 — V1 scope boundary

**Decision**: V1 = trust-first, friction-second. Cross-session auto-resume, OBSERVING mode, checkpoint-decision files, token-usage telemetry, partial-write recovery, decision-log archival, multi-fixture smoke tier all deferred to V2. SC-008 (≥5 runs over 30 days) is the V1 ship-or-retire gate. → **ADR-015**.

**Rationale**: V1 is calibrated to evidence, not speculation. SC-008's 30-day floor ensures the runs reflect genuine feature-development cadence.

---

## R-9 — TDD strategy for non-deterministic dispatcher

**Decision**: Two-tier hybrid. Tier 1 (unit, pre-commit, TDD-strict) tests the deterministic surface against canned fixtures. Tier 2 (smoke, pre-merge, real subagents, cost-capped) verifies the subagent-orchestrator contract end-to-end. → **ADR-017** (closes LOG-006).

**Rationale**: Honors Principle III's intent without pretending non-deterministic LLM calls are testable like pure functions. Exemption is precisely scoped to the LLM-call boundary; the smoke tier is the compensating control.

---

## R-10 — Stale-lock recovery

**Decision**: V1 ships `--break-lock` only. No TTL, no PID-aliveness probe. Developer is the recovery mechanism; lock contents (path, session id, creation timestamp) are surfaced when a stale lock is encountered. → **ADR-018** (closes LOG-009).

**Rationale**: Single-session V1 lifecycle ⇒ stale lock is always the developer's own crashed session. TTL introduces concurrent-steal risk; PID-aliveness is unreliable in Claude-Code-managed sessions. `--break-lock` matches V1's BLOCKING-everywhere safety posture.

---

## R-11 — Deterministic surface boundary

**Decision**: All control-flow logic (lock acquisition, completeness predicates, target validation, route decisions, sidecar emission, schema validation, sandbox audit) lives in bash helpers under `.specify/scripts/bash/run-*.sh`. The slash-command markdown invokes helpers and obeys their output; routing prose does not float in the LLM prompt. → **ADR-019**.

**Rationale**: ADR-017 names the deterministic surface; ADR-019 locates it. Without an explicit boundary, Tier 1 has nothing to test beyond utilities. Bash + bats is the project's native stack (see `setup-plan.sh`, `check-prerequisites.sh`, etc.).

**Alternatives considered**: LLM-resident routing (rejected — untestable below smoke tier); Python helpers (rejected — reverts the 009-remove-memory-server dependency cleanup).

---

## R-12 — Smoke-tier fixtures and budget

**Decision**: One fixture in V1 (`feature-min-path.txt` — synthetic ~250-word description; target `specify→plan`; expected ADR creation in plan stage). Per-run cap 50K tokens; per-merge cap 100K tokens. → **ADR-021** (closes ADR-017 follow-on).

**Rationale**: Smoke tier verifies contract, not behavioral exhaustion. Tier 1 covers routing variations; one happy-path fixture is sufficient. Caps are explicit visible spending limits, not tight optimizations.

---

## R-13 — Test framework

**Decision**: bats-core for both tiers. No Python, no JS test runner. Tests live in `tests/unit/` and `tests/smoke/`.

**Rationale**: bats is dependency-free, designed for testing shell scripts, and aligns with the Bash deterministic core (ADR-019). The project currently has no `tests/` directory; adding bats does not introduce a runtime dependency outside the test harness itself.

**Installation note**: `bats-core` is a brew/apt package. The Tier 1 suite uses only bats core features (no `bats-assert` / `bats-support`) to keep the dependency surface flat; convenience matchers can be re-added later if test ergonomics warrant.

---

## R-14 — Atomic file operations

**Decision**: Lock acquisition uses `mkdir` (atomic on POSIX filesystems). Lock + sentinel cleanup uses staged renames into a temp directory, then a single `rm -rf` of the temp directory; if interrupted between rename and rm, the next run sees no lock and no sentinel.

**Rationale**: FR-027 requires atomic removal of `run-lock` and `abort` sentinel together. Direct `rm` of two files is non-atomic. Staging via a temp directory inside `.run/` (e.g., `.run/.cleanup-NNNN/`) gives single-syscall atomicity for the visible state transition. `mkdir` for lock acquisition is the standard POSIX atomic-create idiom (will fail with `EEXIST` if another process holds the lock).

**Alternatives considered**: `flock` (rejected — not portable to default macOS); lock files via `set -C` + redirect (rejected — race-condition-prone).

---

## Open questions remaining (deferred or empirical)

| Item | Status | Disposition |
|---|---|---|
| LOG-004 — per-stage context overhead | Deferred to V2 | Per ADR-015 |
| LOG-005 — stage-pair runner V1.5 | Open | Reuses ADR-019 helpers; no plan-phase blocker |
| LOG-007 — codereview model-class diversity | Open (empirical) | Measurement substrate is the ADR-021 fixture |
| LOG-008 — decision-log unbounded growth | Deferred to V2 | Per ADR-015 |
| Severity-taxonomy retrofit | Out of scope | Separate spec required (amends `/speckit.review`) |

All NEEDS-CLARIFICATION items from the plan template are resolved. Phase 0 complete.
