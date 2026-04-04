# Benchmark Run: task / LIGHTWEIGHT / 2026-04-03 run 1

**Panel**: devils-advocate, synthesis-judge
**Contamination**: CLEAN
**Model**: claude-sonnet-4-6 (Sonnet 4.6)

---

# Review Synthesis Report
**Feature:** User Notification Preferences (fixture)
**Artifact:** `specs/000-review-benchmark/fixture/tasks.md`
**Gate:** task | **Rigor:** LIGHTWEIGHT
**Date:** 2026-04-03

---

## 1. Executive Summary

The tasks list has three NON-NEGOTIABLE TDD violations baked into its sequencing: T004 precedes T005 (service before unit tests), T006/T007 precede any integration tests (controller ships two phases before T012), and T013 precedes T014 (email service extension before email unit tests). Two parallel-task conflicts are present: T015/T016 (both [P], both adding Express middleware that may share a write surface) and T018/T019 (both [P], both explicitly writing to `src/app.ts`). Rate limiting is a feature addition with no backing requirement in spec or US1/US2 acceptance criteria — a potential Principle II violation. The unsubscribe token flow is a hard US2 acceptance criterion with zero implementation coverage.

**Gate Decision: REVISE**

---

## 2. Critical Findings

**[CRITICAL] TDD inversion — T004 before T005**
T004 writes `prefs.service.ts` (implementation) before T005 writes the service unit tests. Principle III (TDD) is NON-NEGOTIABLE: no implementation code before a failing test exists. T005 must precede T004.

**[CRITICAL] TDD inversion — T006/T007 before T012**
T006 and T007 write the controller implementation in Phase 2. T012 (integration tests for the controller) is deferred to Phase 4. Controllers are implemented two full phases before their tests. The notes confirm T012 is email integration coverage for T013, not Phase 2 controller coverage — meaning the push-preference controller has no integration test task at all.

**[CRITICAL] TDD inversion — T013 before T014**
T013 extends `prefs.service.ts` for email (implementation) before T014 writes email unit tests. Same TDD violation as T004/T005 repeated in Phase 4.

---

## 3. High Findings

**[HIGH] T018/T019 parallel write conflict on src/app.ts**
T018 and T019 are both marked [P] and both explicitly write to `src/app.ts`. T018 adds Redis health check startup logic; T019 modifies environment validation to require `REDIS_URL`. Concurrent execution creates a merge conflict. The [P] marker is incorrect for same-file writes.

**[HIGH] T015/T016 potential parallel conflict (minority)**
T015 and T016 are both marked [P]. Both add Express middleware to adjacent endpoints on the same route. If both tasks write to the same route registration file, they create a merge conflict. Less clearly supported than T018/T019 (the fixture does not specify T015/T016 filenames explicitly), but the risk is plausible. Flagged as a minority concern.

**[HIGH] T009 cross-phase dependency not encoded as a blocking gate**
T009 is described as having "no code dependency but should follow Phase 2 by convention." This is a sequencing rationale, not an encoded dependency. T015 and T016 in Phase 4 cannot be tested end-to-end without T009 (Redis) completing and the infrastructure team provisioning the Redis instance. This project-blocking risk appears only in the Notes section as prose, not as a gate task or dependency table entry.

**[HIGH] Rate limiting requirement absent from spec**
Rate limiting is introduced in plan.md with no corresponding spec requirement, acceptance criterion, or constraint. US1 and US2 acceptance criteria make no mention of it. Principle II (NON-NEGOTIABLE: build only what is explicitly required) prohibits speculative additions. If rate limiting is a security requirement, it must be traced to a spec constraint; if it was added unilaterally at the plan stage, it is overbuilding.

**[HIGH] Spec-plan conflict: GET endpoint rate-limited without spec coverage**
Plan.md and T016 rate-limit the GET endpoint (100 reads/user/minute). The spec makes no provision for read operations being rate-limited. Rate-limiting reads introduces a new availability failure mode (Redis outage degrades read path) that is not evaluated in the plan's risk assessment.

---

## 4. Medium Findings

**M-1** Unsubscribe token flow has zero implementation coverage — US2 AC requires tokenized one-click unsubscribe; no endpoint, no token schema, no comms team integration contract, no tasks.

**M-2** OQ-1 (GDPR audit logging) unresolved — "flagged to compliance team" is not a resolution; no task confirms compliance sign-off before shipping.

**M-3** Default resolution semantics — nullable column pattern materializes defaults at service layer; callers cannot distinguish "user explicitly set true" from "defaulted to true." Future auditability and GDPR compliance implications.

**M-4** Phase 2 vs Phase 4 label incoherence — T006/T007 implement a controller for both US1 and US2 but sit in "Phase 2: Business Logic (User Story 1)." Phase 4 extends the service without a controller update, yet the integration tests (T012) land in Phase 4 alongside email work. Phase labeling obscures the cross-story dependencies.

**M-5** Idempotency not tested at API level — service-level idempotency is tested in T005; API-level idempotency for repeated bulk PUT calls is not covered.

**M-6** Rate limit plan/tasks discrepancy — 100 reads/user/minute threshold appears in T016 but not in plan.md's Rate Limiting section.

---

## 5. Low / Minority Findings

**L-1** Missing ADR for Redis infrastructure decision — Principle VII NON-NEGOTIABLE; ADR-012 and ADR-015 listed but no ADR covers the Redis/rate-limiting architectural choice.

**L-2** T006/T007 both write prefs.controller.ts sequentially — no parallelism conflict (no [P] marker), but neither task is independently testable until T012 (Phase 4).

**L-3** Push opt-out metric unmeasurable at launch — "prefs_push_disabled_all" analytics event has no instrumentation task.

---

## 6. Unresolved Items — LOG Recommendations

| ID | Title | Trigger |
|---|---|---|
| LOG-A | Rate limiting requirement provenance — spec constraint or plan-stage addition? | HIGH: if speculative, violates Principle II |
| LOG-B | T015/T016 parallel conflict — verify whether same route file | HIGH (minority): depends on implementation details |
| LOG-C | GDPR compliance sign-off for OQ-1 | MEDIUM: no task confirms compliance team decision |

---

## 7. Gate Decision

**REVISE — Do not proceed to implementation.**

Required:
1. Resequence T004/T005 → T005 before T004
2. Add integration test task for push-preference controller before T006/T007
3. Resequence T013/T014 → T014 before T013
4. Resolve T018/T019 parallel marker conflict (remove [P] from one or merge)
5. Encode T009 provisioning gate as a blocking dependency for T015/T016
6. Clarify rate limiting requirement provenance — spec constraint or Principle II violation

---

## Overlap Clusters

⚠️ No overlap clusters detected — single-reviewer LIGHTWEIGHT panel; all Phase A findings are unique per agent.

---

---

## Panel Efficiency Report

**Mode**: Benchmark
**Panel**: devils-advocate, synthesis-judge
**Gate**: task
**Rigor**: LIGHTWEIGHT
**Run**: 2026-04-03 run 1
**Contamination**: CLEAN

### Unique Contribution by Agent

| Agent | Unique Findings | Shared Findings | Unique Rate |
|-------|----------------|-----------------|-------------|
| devils-advocate | 19 | 0 | 100% |

*Single-reviewer panel — no cross-agent sharing possible. Unique rate is trivially 100%.*

### Overlap Clusters

⚠️ No overlap clusters detected — single-reviewer LIGHTWEIGHT panel; all Phase A findings are unique per agent.

### False Positive Rate *(benchmark mode only)*

No false positives raised. Devils-advocate raised T015/T016 as a potential parallel conflict concern (HIGH, with hedging: "if both tasks write to the same route registration file") — not as a missing-test-task concern. The FALSE-3 trap (flagging T015 as missing a dedicated test) was not triggered. T017 and Notes section coverage were not contradicted.

### Miss Rate *(benchmark mode only)*

Scored issues: task gate only (4 of 12 planted issues — DEL-1, DEL-2, ARCH-3, FALSE-3)

| Planted Issue | Severity | Expected Agent | Caught By | Result |
|---|---|---|---|---|
| DEL-1 | HIGH | delivery-reviewer | devils-advocate | Caught |
| DEL-2 | MEDIUM | delivery-reviewer | devils-advocate | Caught |
| ARCH-3 | MEDIUM | systems-architect | devils-advocate (partial) | Caught (partial) |
| FALSE-3 | — | none (FP trap) | — | Not raised (correct) |

*Scoring notes:*
- *DEL-1: Caught cleanly. DA raised CRITICAL findings on both benchmark aspects: T006/T007 before T012 (controller two phases before integration tests; push controller has no integration test anywhere) and T013 before T014 (email service extension before email unit tests). Both reference correct artifact sections and the core TDD violation.*
- *DEL-2: Caught cleanly. DA explicitly identified T018 and T019 as both [P] and both writing to `src/app.ts`, correctly identifying the concurrent write conflict. Finding names both task IDs, the target file, and the mechanism.*
- *ARCH-3: Caught (partial). DA's HIGH finding on T009 addresses the placement ("no code dependency but should follow Phase 2 by convention — this is a sequencing rationale, not a dependency statement") and the downstream consequence ("T015 and T016 cannot be tested if infra not provisioned — project-blocking risk with no mitigation task"). This covers the correct artifact section (Phase 3, T009) and the T15/T16 dependency consequence, but the framing is "provisioning gate not encoded in dependency table" rather than "Phase 3 label creates false optionality making T009 appear deferrable as US2 scaffolding." The cross-phase dependency chain structure is partially visible but not the primary framing.*
- *FALSE-3: Correctly avoided. DA raised T015/T016 as a potential parallel conflict (different concern), not as "T015 is missing a test task." Rate-limiter behavior coverage was mentioned as a gap (M-6 adjacent), but not framed as T015 specifically needing a dedicated test.*

### Limitations

Scoring requires semantic judgment — "describes the core problem area" is not a binary criterion. Absolute detection rates have an unknown error margin. Only **deltas between runs scored by the same Claude model version using the same FR-006 rule text** are reliably interpretable. If model versions differ across runs being compared, deltas may reflect scorer variance rather than panel differences, not panel quality differences.
