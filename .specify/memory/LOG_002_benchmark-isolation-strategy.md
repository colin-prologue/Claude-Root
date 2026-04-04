# LOG-002: Benchmark-Key Isolation Strategy

**Date**: 2026-04-03
**Type**: QUESTION
**Status**: Resolved
**Raised In**: specs/000-review-benchmark/spec.md — spec gate review (CF-1)
**Related ADRs**: None

---

## Description

How should benchmark-key.md be isolated from Phase A review agents, given that agents have
filesystem tool access (Read, Grep, Glob, Bash) and can discover files the command does not
explicitly pass to them?

## Context

Surfaced during the spec gate adversarial review. Both the product-strategist (PS-1) and
devils-advocate (DA-A3/FM-5) independently flagged that asserting "isolation is enforced by
command structure" is insufficient when agents can read any file in the working directory.
The original spec said "MUST NOT be referenced in Phase A agent prompts" — true but not
sufficient.

## Discussion

### Pass 1 — Initial Analysis

The command controls what it tells agents to read (the prompt's artifact list), but not what
agents are capable of reading. A Glob for `*key*` or `*benchmark*` would trivially surface
the file. Two proposed mitigations: (a) move the file outside the repo working directory,
(b) add a canary issue in the key that doesn't exist in the artifacts, so any agent raising
it reveals contamination.

### Pass 2 — Critical Review

The canary approach was rejected: it makes the key less trustworthy as a ground truth scoring
instrument. A deliberately false entry in the answer sheet undermines the benchmark's
integrity for anyone reading it to understand what "a good review" looks like.

The external-storage approach is valid but was also challenged: contamination is detectable
without relocation. If an agent reads the key, it will likely use exact key IDs (PROD-1,
SEC-1, etc.) in its findings — a clear fingerprint. Detection + response is more robust than
prevention alone.

### Pass 3 — Resolution Path

The resolution is a two-layer approach:
1. **Prevention**: command does not pass benchmark-key.md to Phase A agents (as originally specified).
2. **Detection**: scoring pass checks whether any Phase A finding contains an exact key ID verbatim. If so, run is flagged as contaminated, result invalidated, maintainer prompted to re-run.

This is simpler than external storage, preserves the key in version control, and provides
actionable feedback when contamination occurs.

## Resolution

Resolved by adding contamination detection and response to FR-003 in the spec. The scoring
pass runs a contamination check before scoring; a contaminated run is invalidated rather than
scored.

**Resolved By**: inline spec update — FR-003 amended
**Resolved Date**: 2026-04-03

## Impact

- [x] Spec updated: `specs/000-review-benchmark/spec.md` — FR-003 (added contamination check), Edge Cases (updated isolation edge case)
- [ ] Plan updated: N/A (pre-planning)
- [ ] ADR created/updated: None
- [ ] Tasks revised: N/A
