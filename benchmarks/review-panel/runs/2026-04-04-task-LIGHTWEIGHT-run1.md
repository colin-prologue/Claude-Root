# Benchmark Run: task / LIGHTWEIGHT / 2026-04-04 run 1

**Panel**: devils-advocate, synthesis-judge
**Contamination**: CLEAN
**Model**: claude-sonnet-4-6

---

## Review Synthesis Report — task gate / LIGHTWEIGHT / 2026-04-04

### Overall Recommendation: REVISE REQUIRED

Three hard constitutional violations (Principle III TDD ordering), one [P] marker structural defect, and one Principle VII violation (missing ADR for Redis) require correction before the task list is executable. US2's primary acceptance criterion (unsubscribe link) has no assigned task, meaning US2 cannot reach Done as currently written.

---

### Coverage Note

LIGHTWEIGHT review — devils-advocate only. Systems-architect, delivery-reviewer, and operational-reviewer did not run.

| Missing Reviewer | Areas Not Examined |
|---|---|
| systems-architect | Module boundaries, Redis phase ordering depth, migration safety, surrogate key justification, dependency chain tracing |
| delivery-reviewer | Explicit test coverage completeness, T001 DBA review process, PR boundaries, repository layer test gap |
| operational-reviewer | Fail-open behavior documentation, Redis health check sequencing, rollback posture, REDIS_URL documentation |

Coverage gaps are material. A STANDARD or FULL re-review after revision is recommended.

---

### Priority Findings (must resolve before implementation)

| ID | Severity | Finding | Source | Action Required |
|----|----------|---------|--------|-----------------|
| PF-1 | CRITICAL | TDD violation: T004 (service impl) precedes T005 (service tests) — test task ID is higher than implementation task ID it covers | Phase A | Reorder: T005 must have a lower task ID than T004; restructure Phase 2 to write test task first |
| PF-2 | CRITICAL | TDD violation: T006/T007 (controller handlers, Phase 2) precede T012 (controller integration tests, Phase 4) — three phases separate implementation from tests | Phase A | Controller integration test must precede controller implementation; Phase 2 cannot complete without a controller test gate |
| PF-3 | CRITICAL | TDD violation: T013 (email service extension) precedes T014 (email tests) — third systematic Principle III violation | Phase A | T014 must have a lower task ID than T013 |
| PF-4 | HIGH | T018 [P] and T019 [P] both write to src/app.ts — sharing a file while marked parallel is an explicit structural defect per the [P] definition | Phase A | Remove [P] from one or both; add explicit sequential dependency |
| PF-5 | HIGH | Redis ADR missing — rate-limiter-flexible library selection, Redis dependency introduction, and fail-open policy are all architectural decisions with no ADR per Principle VII | Phase A | Write ADR before implementation; must cover all three decisions |

---

### Standard Findings (should resolve before implementation)

| ID | Severity | Finding | Source | Action Required |
|----|----------|---------|--------|-----------------|
| S-1 | MEDIUM | US2 AC4 (unsubscribe link) has no implementation task — acceptance criterion has no corresponding tasked work | Phase A | Add tasks for token generation, link injection, and endpoint validation; US2 cannot reach Done without this |
| S-2 | MEDIUM | Notifications service preference-lookup hook is a declared spec dependency with no task defining, stubbing, or validating the integration contract | Phase B | Add integration contract definition task or explicitly declare out-of-scope with named owner |
| S-3 | MEDIUM | Rate limiting (T009, T015) labeled "User Story 2 support" but protects the P1 PUT endpoint — plan does not state whether rate limiting is required for P1 launch or deferred | Phase A | Plan must explicitly declare: rate limiting is optional for P1 (with accepted risk) or required (then Phase 3 must precede P1 launch) |
| S-4 | MEDIUM | Analytics events (prefs_push_disabled_all, email delivery analytics) are the measurement mechanism for success criteria but no task implements or assigns them | Phase A | Add analytics task or explicitly assign to another service |
| S-5 | MEDIUM | Email default resolution (CRITICAL_ALERT-only) is not listed as an integration test scenario in T012 — unit test may pass while API serialization is wrong | Phase B | Add integration test scenario for email default state to T012 |

---

### Low-Signal / Low-Priority Findings

| ID | Severity | Finding | Disposition |
|----|----------|---------|-------------|
| L-1 | MEDIUM | GET rate limiting (T016, 100 reads/user/minute) not justified in plan or risk assessment — appears to be undocumented scope expansion | Requires plan amendment or explicit product decision |
| L-2 | MEDIUM | Idempotency (re-save same value) unit-tested at service level (T005) but not integration-tested — spec constraint should be verified end-to-end | Low risk; flag for T012 expansion |
| L-3 | LOW | user_notification_preferences table has no created_at column — relevant if OQ-1 (GDPR audit trail) is revisited | Note in migration DDL |
| L-4 | LOW | plan.md Phase 4 step 10 is truncated ("Wire rate limiter to... GET") — ambiguous about intent; should be corrected | Correct before handoff |

---

### Overlap Clusters

Single reviewer — no cross-agent overlap computable. Internal Phase A/Phase B convergence:

| Cluster | IDs | Signal |
|---|---|---|
| TDD violations (systematic) | PF-1, PF-2, PF-3 | Phase B confirmed as a systemic pattern, not isolated oversights — implementation-first authoring throughout |
| US2 completeness gaps | S-1, S-2 | Two distinct gaps (unsubscribe link, notifications hook) both cause US2 to fail its own acceptance criteria silently |
| P1/P2 boundary definition | S-3 | Rate limiting ambiguity compounds P1 independence requirement |

---

### Preserved Dissent

**On S-3 severity (rate limiting and P1)**: Self-challenge in Phase B downgraded this from HIGH to MEDIUM on the basis that fail-open behavior makes rate limiting optional infrastructure. Preserved dissenting position: a write endpoint without rate limiting on a publicly accessible service is an abuse vector even with auth tokens — a compromised or scripted account can generate noise at volume. The fail-open argument protects availability but does not address abuse. This should be a documented product decision, not left implicit.

---

### Unresolved Items

1. Is rate limiting required before P1 launch or explicitly optional? — Requires plan author.
2. Who owns analytics event instrumentation? — Requires product/platform team.
3. What is the integration contract between the notifications service and the preferences service at delivery time? — Requires cross-team design.
4. Is the GET endpoint rate limit (T016) intentional product scope or incidental inclusion? — Requires plan author.

---

### Synthesis Notes

The TDD violations are the blocking issue. All three (PF-1, PF-2, PF-3) share the same root cause: the task list was authored in implementation order, with tests conceived as post-implementation validation. Renumbering task IDs alone will not fix the underlying sequencing — the task descriptions also need reordering so tests are genuinely written first. This is a systemic author mental-model issue, not three isolated errors.

The [P] marker convention (PF-4) appears to be applied to logical parallelism ("these could be written independently") rather than strict file-independence ("these touch different files"). The convention should be audited for all [P]-marked tasks, not just T018/T019.

US2 structural completeness: the unsubscribe link (S-1) and the notifications service integration (S-2) are both either acceptance criteria or declared spec dependencies with no tasked work. Both are silent failure modes — the feature ships passing all tasks but fails its own spec.

---

## Panel Efficiency Report

**Mode**: Benchmark
**Panel**: devils-advocate, synthesis-judge
**Gate**: task
**Rigor**: LIGHTWEIGHT
**Run**: 2026-04-04 run 1
**Contamination**: CLEAN

### Unique Contribution by Agent

| Agent | Unique Findings | Shared Findings | Unique Rate |
|-------|----------------|-----------------|-------------|
| devils-advocate | 13 | 0 | 100% (single-agent; not a diversity signal) |

### Overlap Clusters

Single reviewer — no cross-agent overlap computable. Internal convergence clusters noted in synthesis (TDD violations as systemic, US2 completeness gaps, P1/P2 boundary ambiguity).

### False Positive Rate *(benchmark mode only)*

No false positives raised. DA did not flag T015 as missing a test task. DA's rate-limiter findings focused on scope rationale (T016 GET rate limit without justification) and behavioral test coverage (no test for 429 responses), neither of which constitutes the FALSE-3 trap.

### Miss Rate *(benchmark mode only)*

| Planted Issue | Severity | Expected Agent | Caught By | Result |
|---|---|---|---|---|
| DEL-1 | HIGH | delivery-reviewer | devils-advocate | Caught |
| DEL-2 | MEDIUM | delivery-reviewer | devils-advocate | Caught |
| ARCH-3 | MEDIUM | systems-architect | — | Missed (systems-architect not in LIGHTWEIGHT panel) |
| FALSE-3 | — | (none) | (none triggered) | Pass |

*(4 of 12 total planted issues applicable at task gate)*

**DEL-1 scoring note**: DA Phase A named T006/T007/T012 (PF-2) and T013/T014 (PF-3) as CRITICAL Principle III violations with explicit task ID analysis. Direct match on artifact section and core problem area. DA also caught T004/T005 (PF-1) — the TDD violation not specifically named in DEL-1 but part of the same pattern.

**DEL-2 scoring note**: DA Phase A named T018/T019 as a [P]-marker structural defect (PF-4) citing the same-file conflict explicitly. Direct match.

**ARCH-3 miss note**: Expected miss — systems-architect not in LIGHTWEIGHT panel. DA found the downstream effect of Redis sequencing issues (SF-3: rate limiting deferred to Phase 4, PUT endpoint unprotected during P1) which is a consequence of T009's phase placement, but did not trace the T009→T011→T015/T016 dependency chain or name T009's Phase 3 placement as the architectural root cause. The same pattern observed in FULL (OR caught T018 health check timing but not T009 root cause) recurs here — the downstream effect is visible; the root cause requires architectural tracing.

**DEL-1/DEL-2 by DA without delivery-reviewer**: Both delivery-focused planted issues were caught by DA alone, consistent with pattern from plan/LIGHTWEIGHT where DA caught SEC-2 without security-reviewer. Constitution-aware adversarial analysis detects structural violations (TDD ordering, parallel marker semantics) that don't require specialist delivery expertise to find.

### Limitations

Scoring requires semantic judgment — "describes the core problem area" is not a binary criterion. Absolute detection rates have an unknown error margin. Only **deltas between runs scored by the same Claude model version using the same FR-006 rule text** are reliably interpretable. If model versions differ across runs being compared, deltas may reflect scorer variance rather than panel quality differences.

LIGHTWEIGHT panel coverage gaps are significant at the task gate. Delivery-reviewer's absence means T003 (repository layer) test gap, T001 rollback posture, PR boundary strategy, and T006/T007 sequencing within Phase 2 were not examined. Operational-reviewer absence means fail-open behavior, health check sequencing, and REDIS_URL documentation were not examined.
