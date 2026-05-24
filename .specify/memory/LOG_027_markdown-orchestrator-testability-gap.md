---
name: LOG-027 Markdown-orchestrator testability gap
description: DA preserved dissent — speckit.run.md prose is structurally untestable; all code-review CRITICALs slipped through 184 unit tests because they live in markdown, not bash
type: challenge
cross-references:
  - specs/010-autonomous-workflow/spec.md (FR-019, FR-026)
  - .claude/commands/speckit.run.md
  - .specify/memory/ADR_019_deterministic-orchestrator-core.md
---

# LOG-027: Markdown-orchestrator testability gap

**Date**: 2026-05-22
**Status**: Open (V1 accepted risk)
**Raised by**: devils-advocate, /speckit.codereview post-implement review

## Observation

All four CRITICALs found during code review (C-1: undefined `$NEXT_STAGE`; C-2: wrong schema field names in dispatch block; C-3: `run-validate-entry.sh` never wired; C-4: hardcoded feature path) lived in `speckit.run.md` prose — not in any bash helper. 184 unit tests covered the helpers thoroughly and missed every one of them.

The root cause: markdown pseudocode is not executable. The bats unit-test harness validates bash scripts; it cannot validate the orchestrator's instruction prose. Protocol violations in the orchestrator glue are only detectable by human review or smoke tests that exercise end-to-end dispatch.

ADR-019 intentionally separates deterministic routing (helpers, testable) from dispatch (markdown, interpreted by Claude). This was a deliberate tradeoff: it avoids an orchestrator runtime dependency but accepts that the glue layer is structurally unverifiable.

## Risk

Drift between the slash command's instructions and the helper contracts will recur whenever helpers are updated without a corresponding re-read and update of `speckit.run.md`. The danger is highest when a helper's public interface changes (argument order, exit codes, output format) — the markdown will silently become wrong.

## Mitigations in place

- Smoke harness (tests/smoke/) exercises end-to-end dispatch and can catch orchestrator-level wiring errors
- Code review gate (`/speckit.codereview`) is the designated catch point for prose-layer issues
- Helper contracts in `helper-contracts.md` are the single source of truth; `speckit.run.md` must defer to them

## Mitigations deferred to V2

- A structured orchestrator format (e.g. YAML or typed DSL) that can be linted and validated against helper contracts
- A contract-conformance check that statically verifies `speckit.run.md` references against the installed helper interface
