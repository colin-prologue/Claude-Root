# Benchmark Run: plan / FULL / 2026-04-03 run 1

**Panel**: systems-architect, security-reviewer, delivery-reviewer, devils-advocate, synthesis-judge
**Contamination**: CLEAN
**Model**: claude-sonnet-4-6 (Sonnet 4.6)

---

# Review Synthesis Report
**Feature:** User Notification Preferences (fixture)
**Artifact:** `specs/000-review-benchmark/fixture/spec.md` + `fixture/plan.md`
**Gate:** plan | **Rigor:** FULL
**Date:** 2026-04-03

---

## 1. Executive Summary

This plan has a coherent structural foundation — the schema design, API shape, and phase decomposition are reasonable starting points. However, the plan cannot proceed to implementation in its current state.

**The cross-cutting finding**: the plan has an implicit threat model that was never written down. This single omission explains a cluster of independent HIGH findings across security and architecture. The rate limiter wires to the wrong endpoint, IDOR protections are absent, Redis key isolation is unspecified, and fail-open behavior is undocumented — all because no one wrote down what adversarial scenarios the plan is defending against. Until a threat model is authored, fixing individual security findings risks producing locally correct patches that are globally incoherent.

A secondary cross-cutting finding: TDD order is inverted throughout all four implementation phases. Tests are written after implementation in every phase. This is a systematic process violation, not a scattered oversight.

A third cross-cutting finding: two ADRs (ADR-012, ADR-015) are named in the plan's decision records section but have no authoring tasks and no substantive content in the artifact. Principle VII is explicit — these must exist before implementation begins.

**Gate Decision: BLOCKED.** Required actions enumerated in Section 7.

---

## 2. Critical & High Findings

### H-01 | Rate Limiter Wired to Wrong Endpoint
**Severity**: CRITICAL
**Source**: systems-architect F-02, security-reviewer #3, delivery-reviewer #3, devils-advocate #1 — unanimous consensus (4/4 agents)
**Location**: Implementation Order, Phase 4 step 10

Phase 4 step 10 wires the rate limiter to `GET /api/v1/preferences/notifications`. The Rate Limiting section states the purpose is preventing "preference-update spam (e.g., rapid toggles in a scripted loop)" — a write behavior. Rate limiting reads penalizes normal page loads while leaving the write surface entirely unprotected. The sentence in step 10 is also truncated, which delivery-reviewer flagged as an independent execution defect.

Phase B DA challenge strengthened the finding: the fix cannot be correctly scoped until the plan states *intent* — what adversarial scenario the rate limiter is defending against (write spam, enumeration, or both). The delivery-reviewer appropriately scoped threat model prose to the ADR, not the task plan.

**Required action**: (a) State the threat being defended against. (b) Re-wire rate limiter to PUT. (c) Document whether GET also requires rate limiting and why. (d) Complete the truncated sentence in step 10.

---

### H-02 | IDOR — Identity Resolution Unspecified
**Severity**: HIGH
**Source**: security-reviewer #1 (split to #1a in Phase B), devils-advocate #3
**Location**: API Design — GET and PUT endpoints

Neither endpoint specifies how the current user's identity is established. If the service layer resolves `userId` from a client-supplied parameter, any authenticated user can read or overwrite another user's preferences.

Phase B DA challenge caused security-reviewer to split this finding into two distinct gaps with different remediations:
- **H-02a (identity resolution)**: The authoritative source of `userId` (JWT claim, session, etc.) and where extraction occurs must be specified.
- **H-02b (ownership enforcement)**: Even with correct identity resolution, an explicit ownership check must exist — verifying that the resolved userId matches the resource owner — before any business logic executes on both GET and PUT paths.

**Required action**: Specify authoritative identity source and extraction point. Add explicit ownership enforcement check on both paths before any business logic.

---

### H-03 | TDD Order Inverted Throughout All Phases
**Severity**: HIGH
**Source**: delivery-reviewer #1 and #2, devils-advocate #6 — consensus (2/4 Phase A agents)
**Location**: Implementation Order, Phases 2 and 3

`prefs.service.ts` is written in step 4; unit tests appear in step 5. The controller/routes are implemented in steps 6–7; integration tests appear in step 8. The pattern is consistently inverted across all phases. Phase B DA amplification added a structural consequence: tests written after the implementation will be written to confirm existing code rather than to specify behavior — permanently weakening the test suite's signal value.

**Required action**: Invert all phases to test-first. Unit tests for service layer must precede `prefs.service.ts`. Integration tests must precede controller and route implementation.

---

### H-04 | ADR-012 and ADR-015 Referenced But Not Authored
**Severity**: HIGH (escalated from MEDIUM by delivery-reviewer in Phase B)
**Source**: delivery-reviewer #9, devils-advocate #2 and #5
**Location**: Decision Records table

ADR-012 (API versioning) and ADR-015 (nullable boolean pattern) are listed as "Accepted" but their files are not present in the artifact and no creation tasks exist in the implementation order. Principle VII (Decision Transparency) is NON-NEGOTIABLE. ADR-015 is particularly consequential: the NULL = platform default pattern affects default resolution logic, cache behavior, and GDPR query compliance. The bar for ADR substance is: decision, alternatives considered, consequences.

**Required action**: Author both ADRs before implementation begins. Add explicit creation tasks to the implementation order.

---

### H-05 | No Authentication/Authorization Mechanism Described
**Severity**: HIGH
**Source**: security-reviewer #4, devils-advocate #3
**Location**: API Design section

How session tokens are transmitted (Authorization header? cookie?) and validated (middleware? direct auth service call?) is entirely absent from the API Design section. This is a prerequisite for ownership enforcement (H-02) and must be specified before `prefs.controller.ts` is written.

**Required action**: Specify auth mechanism in the API Design section: token transmission method, validation approach, and middleware reference.

---

### H-06 | Missing Threat Model Section
**Severity**: HIGH (emerged from Phase B — DA proposal, security-reviewer #10, systems-architect reframe)
**Location**: plan.md — absent

H-01, H-02, H-05, and the Redis decision all have a common root: the plan has implicit security thinking that was never written down. Without a stated threat model, individual security findings can be closed superficially without addressing the structural gap.

**Required action**: Author a threat model section in the plan. Minimum coverage: adversarial scenarios the system faces, which controls address which scenarios, residual risk surface. Control decision rationale belongs in ADRs; threat model prose belongs in the plan.

---

### H-07 | email_enabled Column Created in P1 Without Consuming Logic
**Severity**: HIGH (escalated from MEDIUM by delivery-reviewer in Phase B)
**Source**: delivery-reviewer #8
**Location**: Data Model + Implementation Order

`email_enabled` is a P2 concern (User Story 2) but is created in the P1 migration. If P2 slips, the column exists in production with no consuming logic, no tests confirming it is dormant, and no rollback strategy.

**Required action**: Either defer `email_enabled` column creation to P2, or add a P1 acceptance test explicitly documenting the column as intentionally dormant with a named P2 dependency.

---

### H-08 | Cache Invalidation Strategy Absent
**Severity**: HIGH
**Source**: devils-advocate #4
**Location**: spec.md US1 AC + plan.md Data Model / Implementation Order

User Story 1 requires settings to persist across devices. The plan introduces Redis (for rate limiting). If any read-path caching exists or is added, a preference write must invalidate it. The `updated_at` column is present but not used in any described read path. No cache invalidation step appears in any implementation phase.

**Required action**: Specify cache invalidation strategy on PUT. Document whether any read-path caching exists and where invalidation is triggered.

---

## 3. Medium Findings

**M-01 | Redis ADR Missing** — systems-architect F-01/F-04, security-reviewer #7 (namespace angle). DA challenged the simplicity objection as weak for multi-instance deployments (in-process rate limiting fails silently under horizontal scaling). Requirement is an ADR, not Redis removal. Author Redis ADR covering: infrastructure reuse decision, rate-limiter-flexible library selection, key namespace isolation, fail-open behavior.

**M-02 | Redis Key Namespace Isolation Unspecified** — security-reviewer #7. Rate-limit keys on a shared Redis instance may collide with session service keys. Specify key prefix strategy (e.g., `notif_prefs:rl:{user_id}`). Confirm ACL isolation. Include in Redis ADR.

**M-03 | Fail-Open Rate Limiting — No Implementation Task or ADR** — security-reviewer #8, delivery-reviewer #6. Fail-open is the correct default for a settings endpoint but is a security decision. Risk table entry is not a substitute for an ADR. Also: no implementation task or test covers the fail-open code path. Document in Redis ADR; add implementation task and test.

**M-04 | PUT Batch Atomicity Contract Undocumented** — systems-architect F-06. If a batch PUT of 5 event types fails on item 3, the spec does not define whether items 1–2 are committed or rolled back. Document in API contracts artifact.

**M-05 | event_type Validation — Format-Only, Not Allowlist** — security-reviewer #5 (application layer), systems-architect F-08 (DB layer). Two independent defenses are needed: strict allowlist at the service layer against the notifications service registry; CHECK constraint at the DB layer as defense in depth.

**M-06 | Unsubscribe Token Security Unaddressed in Plan** — security-reviewer #6. Spec US2 requires unsubscribe links. No token design in plan. Required: generation method (signed, non-guessable), user+event_type binding, single-use enforcement.

**M-07 | created_at Column Absent; GDPR Audit Risk** — systems-architect F-03. OQ-1 flags GDPR audit logging as likely required. Adding `created_at` now is zero-cost; absent makes future compliance queries impossible without migration. Either add the column or formally defer via ADR.

**M-08 | updated_at May Not Update in Upsert** — devils-advocate #7, security-reviewer #9 (different angle). DA: ON CONFLICT DO UPDATE clause does not explicitly include `updated_at`. SR: read-then-write pattern would race under concurrent PUTs. Fix: include `updated_at = NOW()` in upsert clause explicitly; confirm single-statement upsert semantics.

**M-09 | Nullable Column Channel Ceiling — No Debt Trigger** — systems-architect F-10 (Phase B), devils-advocate #6 (Phase B). The plan presents the nullable-column-per-channel pattern as open-ended extensibility. No bound is stated; no migration trigger defined. At channel 4+, the pattern requires a schema redesign under pressure. Required: either cap the channel set explicitly, or record a trigger condition in ADR-015.

**M-10 | Test Boundary for prefs.service.ts Unspecified** — delivery-reviewer #5. Three distinct behaviors (default resolution, idempotency, preference merge) with no documented test cases or boundary conditions. Required before TDD inversion.

**M-11 | Migration Rollback Strategy Absent** — delivery-reviewer #4. No down migration documented for the `user_notification_preferences` table creation. Add rollback procedure as explicit subtask in Phase 1.

---

## 4. Low / Minority Findings

**L-01** prefs.repository.ts has no test file (systems-architect F-07). The upsert ON CONFLICT behavior is a distinct integration surface.

**L-02** Superfluous SERIAL surrogate key (systems-architect F-05). Composite (user_id, event_type) is the natural PK and only access pattern. Minority — no other agent raised it.

**L-03** Rate limit integration tests absent — 429 behavior untested (delivery-reviewer #10, systems-architect F-09).

**L-04** No instrumentation tasks for success criteria (delivery-reviewer #11). Latency and persistence metrics defined in spec but no measurement tasks.

**L-05** Idempotency for bulk PUT not explicitly tested (delivery-reviewer #12).

**L-06** No contracts/ artifact (devils-advocate #10). LOW given simple API; escalates if notifications service is a separate team dependency.

**L-07** API versioning — URL versioning assumed without alternatives considered (devils-advocate #5). Subsumed by H-04 ADR-012 authoring task but preserved as a separate concern: the ADR must address why URL versioning was chosen over header-based alternatives.

**L-08** prefs.types.ts invisible dependency (delivery-reviewer #7). Dependency order not explicit; types must precede tests in TDD-inverted phases.

---

## 5. Unresolved Items — LOG Recommendations

| # | Title | Source Findings | Reason for LOG |
|---|---|---|---|
| LOG-A | Threat model absent — security controls cannot be validated | H-01, H-02, H-06 | Systemic gap; fixes to individual findings may be locally correct but globally incoherent |
| LOG-B | OQ-1 GDPR audit logging deferred without formal decision | M-07, DA #9, SA F-03 | Compliance-flagged open question with no ADR or formal deferral |
| LOG-C | Nullable column channel ceiling — no migration trigger defined | M-09 | Long-term schema debt; no decision point defined |
| LOG-D | Rate limit intent ambiguous | H-01, DA Phase B | Cannot scope fix without stated intent — enumeration vs. write spam vs. both |
| LOG-E | Unsubscribe token design absent from plan | M-06 | Security-sensitive design decision not captured in any artifact |

---

## 6. ADR Recommendations

| ADR | Decision to Capture | Priority |
|---|---|---|
| ADR-012 (author) | API versioning strategy — URL versioning chosen; alternatives and consequences | BLOCKER |
| ADR-015 (author) | Nullable boolean pattern — NULL = platform default; channel ceiling; GDPR implications; migration trigger | BLOCKER |
| ADR-NEW-1 | Redis rate limiting — infrastructure reuse, library selection, key namespace, fail-open behavior | HIGH |
| ADR-NEW-2 | Auth mechanism — token transmission, extraction point, ownership enforcement strategy | HIGH |
| ADR-NEW-3 | GDPR audit logging deferral — created_at, audit trail, formal decision on OQ-1 | MEDIUM |

---

## 7. Gate Decision

**BLOCKED**

### Tier 1 — Must complete before any implementation begins

1. Author threat model section (H-06)
2. Author ADR-012 (H-04) — API versioning
3. Author ADR-015 (H-04, M-09) — nullable boolean pattern with channel ceiling
4. Author ADR-NEW-2 (H-02, H-05) — auth mechanism
5. Specify authoritative identity source + ownership enforcement on GET and PUT (H-02a, H-02b)
6. Re-wire rate limiter to PUT; state threat intent (H-01); complete truncated step 10

### Tier 2 — Must complete before Phase 1 begins

7. Invert TDD order throughout all phases (H-03)
8. Resolve email_enabled P1/P2 boundary (H-07)
9. Add ADR creation tasks to implementation order (H-04)
10. Specify PUT batch atomicity contract (M-04)
11. Add rollback task to Phase 1 (M-11)

### Tier 3 — Address before plan is considered complete

12. Author ADR-NEW-1 (Redis rate limiting) (M-01, M-02, M-03)
13. Add event_type allowlist validation + CHECK constraint (M-05)
14. Document unsubscribe token design (M-06)
15. Add created_at or defer via ADR-NEW-3 (M-07)
16. Fix ON CONFLICT DO UPDATE to include updated_at (M-08)
17. Document test boundaries for prefs.service.ts — three behaviors (M-10)

---

## Overlap Clusters

| Finding Topic | Agents | Overlap Type | Verdict |
|---|---|---|---|
| Rate limiter wired to GET instead of PUT | systems-architect, security-reviewer, delivery-reviewer, devils-advocate | Same framing | Redundant — all four cite identical defect; merged into H-01 |
| IDOR / authorization gap | security-reviewer (#1+#2), devils-advocate (#3) | Same framing (DA split into #1a/#1b in Phase B) | Keep both — split into identity resolution and ownership enforcement with different remediations |
| TDD order inverted | delivery-reviewer (#1+#2), devils-advocate (#6) | Same framing | Redundant — merged into H-03 |
| ADR-012 and ADR-015 not authored | delivery-reviewer (#9), devils-advocate (#2+#5) | Same framing | Redundant — merged into H-04 |
| Auth mechanism absent | security-reviewer (#4), devils-advocate (#3) | Same framing | Redundant — merged into H-05 |
| Redis ADR missing vs. Redis key isolation | systems-architect (F-01/F-04), security-reviewer (#7) | Different angle | Keep both — F-01/F-04 address ADR gap; #7 addresses key namespace security within same dependency |
| event_type constraint enforcement | security-reviewer (#5 — allowlist), systems-architect (F-08 — CHECK constraint) | Different angle | Keep both — application-layer and DB-layer defenses are independent |
| Upsert updated_at / concurrent write race | devils-advocate (#7 — timestamp), security-reviewer (#9 — race condition) | Different angle | Keep both — silent timestamp failure and concurrent write race are distinct failure modes |
| Nullable column channel ceiling | devils-advocate (#6 Phase B), systems-architect (F-10 Phase B) | Same framing (DA raised, SA adopted) | Redundant — merged into M-09 |
| Implicit threat model as root cause | devils-advocate (Phase B), security-reviewer (#10 Phase B), systems-architect (F-02 reframe) | Same framing | Redundant — merged into H-06 |

---

---

## Panel Efficiency Report

**Mode**: Benchmark
**Panel**: systems-architect, security-reviewer, delivery-reviewer, devils-advocate, synthesis-judge
**Gate**: plan
**Rigor**: FULL
**Run**: 2026-04-03 run 1
**Contamination**: CLEAN

### Unique Contribution by Agent

| Agent | Unique Findings | Shared Findings | Unique Rate |
|-------|----------------|-----------------|-------------|
| systems-architect | 5 | 4 | 56% |
| security-reviewer | 6 | 3 | 67% |
| delivery-reviewer | 7 | 5 | 58% |
| devils-advocate | 6 | 4 | 60% |

*Unique = findings on topics not raised by any other Phase A agent. Shared topics: rate limiter wiring (4/4 agents), IDOR/auth gap (SR+DA), TDD violations (DR+DA), ADR completeness theme (SA+DR+DA, different targets). DA contributed Phase B challenges that surfaced the nullable column scalability ceiling (M-09) and the implicit threat model reframe (H-06) — these are not scored as Phase A unique findings but materially shaped the synthesis report.*

### Overlap Clusters

Issues raised by 2+ agents:

| Finding Topic | Agents | Overlap Type | Verdict |
|---|---|---|---|
| Rate limiter wired to wrong endpoint | all four agents | Same framing | Redundant |
| IDOR / authorization gap | security-reviewer, devils-advocate | Same framing | Keep both (split into two distinct gaps in Phase B) |
| TDD order inverted | delivery-reviewer, devils-advocate | Same framing | Redundant |
| ADR completeness | delivery-reviewer, devils-advocate | Same framing | Redundant |
| Auth mechanism absent | security-reviewer, devils-advocate | Same framing | Redundant |
| Redis ADR vs. Redis namespace | systems-architect, security-reviewer | Different angle | Keep both |
| event_type enforcement | security-reviewer, systems-architect | Different angle | Keep both |
| Upsert timestamp / race condition | devils-advocate, security-reviewer | Different angle | Keep both |

### False Positive Rate *(benchmark mode only)*

No false positives raised. No Phase A agent flagged the nullable column schema as lacking an ADR while definitively ignoring the ADR-015 reference in the Decision Records table. The devils-advocate acknowledged "ADR-015 is listed as 'Accepted'" and argued for substance rather than claiming the reference was absent — this is not the false positive pattern described in FALSE-2.

### Miss Rate *(benchmark mode only)*

Scored issues: plan gate only (4 of 12 planted issues — ARCH-1, ARCH-2, SEC-2, FALSE-2)

| Planted Issue | Severity | Expected Agent | Caught By | Result |
|---|---|---|---|---|
| ARCH-1 | HIGH | systems-architect | devils-advocate (partial) | Caught (partial) |
| ARCH-2 | MEDIUM | systems-architect | systems-architect | Caught |
| SEC-2 | CRITICAL | security-reviewer | All four agents | Caught |
| FALSE-2 | — | none (FP trap) | — | Not raised as FP (correct) |

*Scoring notes:*
- *ARCH-1: Caught (partial) — devils-advocate Phase A finding #2 raised the nullable boolean pattern as an architectural concern with significant downstream consequences (correct section, correct artifact), but framed it as ADR substance/completeness rather than identifying the channel scalability ceiling (schema migration required per new channel; plan silent on channels 4+). The channel-ceiling argument only emerged in Phase B when DA explicitly raised it as an uncovered area. Since the core problem area (schema scalability beyond 3 channels) was not stated in Phase A, this scores as partial. Expected catcher was systems-architect, who raised the superfluous surrogate key (F-05) but not the nullable column scalability issue in Phase A.*
- *ARCH-2: Caught cleanly — systems-architect F-01 identified Redis as "a new infrastructure dependency with no ADR," precisely characterizing the undocumented dependency. Referenced the Rate Limiting section (correct artifact section) and the core problem (no ADR, "already provisioned" asserted without verification). The Stack table omission was not explicitly named but is part of the same undocumented dependency pattern.*
- *SEC-2: Caught cleanly by all four Phase A agents — each independently identified that the rate limiter in Phase 4 step 10 is wired to the read endpoint (GET) while the plan's stated threat is write operations (PUT). Four-agent consensus on a CRITICAL planted issue is the strongest possible detection signal.*
- *FALSE-2: Not raised as a definitive false positive. DA finding #2 acknowledged that ADR-015 is listed in the Decision Records table ("ADR-015 is listed as 'Accepted'") and argued that listing a title without substantive content in the artifact does not satisfy Principle VII. This is a more nuanced argument than the false positive trap describes (flagging absent ADR without noticing the reference). No agent raised "nullable column has no ADR" as a definitive concern while ignoring the ADR-015 reference.*

### Limitations

Scoring requires semantic judgment — "describes the core problem area" is not a binary criterion. Absolute detection rates have an unknown error margin. Only **deltas between runs scored by the same Claude model version using the same FR-006 rule text** are reliably interpretable. If model versions differ across runs being compared, deltas may reflect scorer variance rather than panel differences, not panel quality differences.
