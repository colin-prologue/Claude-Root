# Benchmark Run: plan / STANDARD / 2026-04-03 run 1

**Panel**: systems-architect, security-reviewer, devils-advocate, synthesis-judge
**Contamination**: CLEAN
**Model**: claude-sonnet-4-6 (Sonnet 4.6)

---

# Review Synthesis Report
**Feature:** User Notification Preferences (fixture)
**Artifact:** `specs/000-review-benchmark/fixture/spec.md` + `fixture/plan.md`
**Gate:** plan | **Rigor:** STANDARD
**Date:** 2026-04-03

---

## 1. Executive Summary

The plan-gate review surfaced two CRITICAL security vulnerabilities, multiple HIGH findings spanning security, architecture, and process integrity, and a confirmed false positive (FALSE-2) that was correctly resolved in Phase B. The plan is not ready to proceed to tasks in its current form.

The dominant failure mode is incomplete security specification: both GET and PUT endpoints lack ownership enforcement against the session token, the rate limiter is attached to the wrong verb, and the unsubscribe token flow is entirely undesigned. A secondary failure is process: the implementation sequence violates TDD as written. The data model has unresolved decisions requiring ADR coverage before implementation begins.

**Gate Decision: BLOCKED — Conditional Revision Required.** Revision must address all CRITICAL and HIGH findings before plan proceeds to tasks.

---

## 2. Critical & High Findings

### C-1 | IDOR — Ownership Enforcement Absent on GET and PUT
**Severity**: CRITICAL (security-reviewer) / HIGH (devils-advocate — dissent preserved)
**Source**: security-reviewer #1 and #2, devils-advocate #3
**Location**: API Design — GET and PUT endpoints

The plan specifies auth middleware is present but does not require that `user_id` be resolved from the authenticated session token. On GET, any authenticated user could read another user's preferences by supplying an arbitrary `user_id`. On PUT, this allows arbitrary preference mutation with higher consequence.

*Dissent preserved*: security-reviewer holds CRITICAL on both paths — middleware existence without explicit ownership binding is not equivalent to a secure design. DA downgraded to HIGH in Phase B citing auth.middleware.ts. Security-reviewer's position is the operationally safer default. Plan author must make an explicit decision on severity acceptance.

**Required action**: Add an explicit ownership-enforcement requirement: `user_id` on all preference endpoints MUST be resolved from the authenticated session token, never accepted as a caller-supplied parameter.

---

### H-1 | Rate Limiter Wired to GET — PUT Unprotected
**Severity**: HIGH
**Source**: systems-architect #1, security-reviewer #3, devils-advocate #4 — unanimous
**Location**: Implementation Order, Phase 4 step 10

Step 10 explicitly wires the rate limiter to `GET /api/v1/preferences/notifications`. The plan's stated threat is "preference-update spam (e.g., rapid toggles in a scripted loop)" — a write operation. The PUT endpoint is the write surface and ships entirely unprotected.

**Required action**: Rewire rate limiter to PUT. Document threat intent explicitly. Evaluate whether GET also requires rate limiting (enumeration defense) and specify separately if so.

---

### H-2 | PUT Partial-Update Semantics Undefined
**Severity**: HIGH (escalated in Phase B)
**Source**: systems-architect #8, security-reviewer #8 (Phase B), devils-advocate #10
**Location**: API Design — PUT endpoint

The plan does not specify whether PUT performs full replacement or partial merge. An unspecified merge behavior could silently re-enable notification channels a user previously disabled — a functional correctness failure with privacy implications. `ON CONFLICT DO UPDATE` appears in the risk table but not in implementation steps.

**Required action**: Define PUT semantics explicitly (full replacement vs. partial merge). Reconcile with upsert behavior in implementation steps.

---

### H-3 | TDD Sequence Violated Throughout
**Severity**: HIGH (CRITICAL per DA — preserved)
**Source**: devils-advocate #1 and #2, systems-architect #6
**Location**: Implementation Order, Phases 2 and 3

Service implementation (step 4) precedes unit tests (step 5). Controller/routes (steps 6–7) precede integration tests (step 8). Tests are written after the code they cover at every layer. Principle III (TDD) is NON-NEGOTIABLE per the project constitution.

**Required action**: Reorder implementation steps so unit tests are written before the service layer and integration tests before the controller.

---

### H-4 | Unsubscribe Token Flow Entirely Absent
**Severity**: HIGH
**Source**: systems-architect #5, security-reviewer #4
**Location**: plan.md (absent)

No token format, entropy requirement, expiry, single-use enforcement, or user+event_type binding is specified anywhere in the plan. An undesigned unsubscribe token is a functional gap and a security gap — guessable or reusable tokens allow third-party unsubscription.

**Required action**: Add unsubscribe token design: generation (cryptographically secure random), storage, expiry TTL, single-use enforcement, binding to (user_id, event_type).

---

### H-5 | Nullable Column Pattern — Principle II Violation
**Severity**: HIGH
**Source**: systems-architect #2, devils-advocate #5
**Location**: Data Model

Note: ADR-015 IS referenced in both the Risk Assessment row and the Data Model section — this was confirmed in Phase B (see FALSE-2 note). The Principle II concern is independent: nullable columns for future unspecified channels constitute speculative abstraction against a non-existent requirement.

**Required action**: Justify the nullable column pattern against Principle II explicitly in the plan, or replace with a non-nullable boolean model. If retained, the Principle II exception must be substantively documented in ADR-015.

---

### H-6 | Redis Fail-Open Decision Undocumented
**Severity**: HIGH
**Source**: systems-architect #4, devils-advocate #8, security-reviewer #6
**Location**: Risk Assessment + Rate Limiting section

The fail-open behavior under Redis failure is described as a "mitigation." It is not — it is risk acceptance of unbounded write throughput when Redis is unavailable. An attacker-induced Redis failure bypasses rate limiting entirely.

**Required action**: Write Redis ADR covering the rate-limiter-flexible library choice, shared instance topology, key namespace strategy. Relabel fail-open as risk acceptance, not mitigation. Document the threat model for Redis failure injection.

---

### H-7 | Surrogate Key vs. Natural PK — Decision Undocumented
**Severity**: HIGH
**Source**: systems-architect #3
**Location**: Data Model

The choice between SERIAL surrogate key and the natural composite primary key `(user_id, event_type)` — already enforced by the UNIQUE constraint — is an undocumented architectural decision with implications for upsert behavior and index coverage.

**Required action**: Write ADR covering PK strategy for the preferences table.

---

### H-8 | event_type Allowlist Validation Unspecified
**Severity**: HIGH
**Source**: security-reviewer #5, systems-architect #7 (different angle)
**Location**: API Design + Data Model

The plan specifies a 400 response for invalid `event_type` but does not define the validation mechanism. Format-only validation allows arbitrary event type strings. No CHECK constraint or FK reference to an event registry exists in the data model.

**Required action**: Specify allowlist validation at the API layer against the notifications service registry. Add CHECK constraint at the DB layer as defense in depth.

---

## 3. Medium Findings

**M-1 | Fail-Open Redis Attacker Surface** — security-reviewer #6. Attacker-induced Redis failure opens the write path to unbounded requests. Subsumed by H-6 ADR action but logged as an open question until threat model is explicit.

**M-2 | GDPR Audit Trail (OQ-1) Not Addressed** — devils-advocate #11. OQ-1 from spec flags GDPR audit requirement. Plan does not address it. Deferral must be made explicit with a LOG entry.

**M-3 | event_type CHECK Constraint Absent** — systems-architect #7. Even with API-layer allowlist validation, a CHECK constraint provides defense in depth at the data layer.

**M-4 | Upsert ON CONFLICT Absent from Implementation Steps** — devils-advocate #12. ON CONFLICT DO UPDATE is mentioned in the risk table but not wired into the data layer implementation steps. Developer may implement naive INSERT.

**M-5 | Partial PUT Semantics — Privacy Risk** — security-reviewer #8 (Phase B). If unspecified fields are reset to defaults, a partial PUT could silently re-enable notification channels a user deliberately disabled. Severity conditional on default permissiveness.

---

## 4. Low / Minority Findings

**L-1** No created_at column — systems-architect #9. Absence limits audit capability; adding now is zero-cost.

**L-2** Express undocumented if net-new — systems-architect #10. If Express is a pre-existing dependency, this finding is dismissed.

**L-3** Device-scope vs. user-scope preference resolution undocumented — devils-advocate #13. Data model stores at user_id level; device-level scoping not evaluated.

**L-4** 500 response body content unspecified — security-reviewer #8 (original). 5xx responses risk leaking internal error detail. Responses should return generic messages; internal detail logged server-side only.

---

## 5. Unresolved Items — LOG Recommendations

| # | Topic | Priority |
|---|---|---|
| LOG-A | IDOR severity dissent — security-reviewer CRITICAL vs DA HIGH; plan author must resolve explicitly | High |
| LOG-B | Fail-open Redis — threat model for attacker-induced failure; accept or mitigate | High |
| LOG-C | GDPR audit trail (OQ-1) deferral | Medium |
| LOG-D | Unsubscribe token threat model — once designed, log separately from ADR | Medium |
| LOG-E | Device-scope vs. user-scope preference resolution | Low |

---

## 6. ADR Recommendations

| ADR | Decision | Blocking? |
|---|---|---|
| ADR-NEW-1 | Redis rate limiting — technology choice, fail-open behavior, key namespace | Yes |
| ADR-NEW-2 | Unsubscribe token design — format, entropy, expiry, binding | Yes |
| ADR-NEW-3 | PUT semantics — full replacement vs. partial merge | Yes |
| ADR-NEW-4 | PK strategy — surrogate vs. natural composite | Yes |
| ADR-NEW-5 | event_type validation strategy — CHECK, FK, or enum | Yes |
| ADR-015 (update) | Nullable column — Principle II exception must be substantive, not a citation placeholder | Conditional |

---

## 7. Gate Decision

**BLOCKED — Conditional Revision Required**

| # | Required Action | Finding |
|---|---|---|
| R-1 | Specify ownership enforcement — user_id from session token on GET and PUT | C-1 |
| R-2 | Rewire rate limiter to PUT; document threat intent | H-1 |
| R-3 | Define PUT semantics (replacement vs. merge); reconcile upsert in implementation steps | H-2 |
| R-4 | Reorder implementation steps to enforce TDD | H-3 |
| R-5 | Add unsubscribe token design | H-4 |
| R-6 | Substantively justify nullable column pattern against Principle II | H-5 |
| R-7 | Write Redis ADR; relabel fail-open as risk acceptance | H-6 |
| R-8 | Write PK strategy ADR | H-7 |
| R-9 | Specify event_type allowlist validation | H-8 |
| R-10 | Address or explicitly defer OQ-1 GDPR audit trail | M-2 |

---

## Overlap Clusters

| Finding Topic | Agents | Overlap Type | Verdict |
|---|---|---|---|
| IDOR on GET and PUT | security-reviewer, devils-advocate | Same framing; severity dissent | Keep both — CRITICAL (SR) / HIGH (DA) dissent preserved |
| Rate limiter on wrong verb | systems-architect, security-reviewer, devils-advocate | Same framing | Redundant — merged into H-1 |
| PUT semantics undefined | systems-architect, security-reviewer (Phase B), devils-advocate | Convergent across phases | Keep both angles — correctness (SA) and privacy (SR) |
| TDD sequence violation | devils-advocate, systems-architect | Same framing | Redundant — merged into H-3 |
| Nullable column Principle II | systems-architect, devils-advocate | Same framing | Redundant — merged into H-5 |
| Nullable column ADR absent | security-reviewer (withdrawn), devils-advocate (noted ADR-015) | FALSE POSITIVE — see below | Withdrawn — ADR-015 confirmed in Risk Assessment |
| Redis ADR / fail-open | systems-architect, security-reviewer, devils-advocate | Different angles (ADR gap vs. security posture) | Keep both — merged into H-6 |
| Unsubscribe token | systems-architect, security-reviewer | Same framing | Redundant — merged into H-4 |
| event_type validation | security-reviewer (allowlist), systems-architect (CHECK constraint) | Different angle | Keep both — application and DB layer defenses are independent |

---

## FALSE-2 Note

During Phase B, it was confirmed that ADR-015 is explicitly referenced in both the Risk Assessment row ("ADR-015 documents the rationale; code comments reference it") and the Data Model section ("This avoids backfill migrations when default values change (ADR-015)"). Security-reviewer's Finding 7 ("not documented as an ADR despite Principle VII") was raised as a definitive MEDIUM concern without acknowledging ADR-015 — this qualifies as a false positive per scoring rules. The security-reviewer correctly withdrew it in Phase B after DA raised the reference. The Principle II concern (speculative abstraction) is independent and survives.

---

---

## Panel Efficiency Report

**Mode**: Benchmark
**Panel**: systems-architect, security-reviewer, devils-advocate, synthesis-judge
**Gate**: plan
**Rigor**: STANDARD
**Run**: 2026-04-03 run 1
**Contamination**: CLEAN

### Unique Contribution by Agent

| Agent | Unique Findings | Shared Findings | Unique Rate |
|-------|----------------|-----------------|-------------|
| systems-architect | 3 | 7 | 30% |
| security-reviewer | 2 | 5 | 29% |
| devils-advocate | 4 | 9 | 31% |

*Note: security-reviewer's Finding 7 (nullable column ADR) is excluded from the denominator as a confirmed false positive (FALSE-2). Unique = findings on topics not raised by any other Phase A agent. High overlap rate (70%+) reflects a three-agent panel without the delivery-reviewer role, causing multiple agents to cover adjacent territory in security and architecture. DA's unique findings: pipeline constraint not verified (#9), OQ-1 GDPR disposition (#11), upsert ON CONFLICT absent from steps (#12), device-scope undocumented (#13).*

### Overlap Clusters

Issues raised by 2+ agents:

| Finding Topic | Agents | Overlap Type | Verdict |
|---|---|---|---|
| IDOR (GET + PUT) | security-reviewer, devils-advocate | Same framing | Keep both (severity dissent) |
| Rate limiter wired to wrong endpoint | all three agents | Same framing | Redundant |
| TDD violations | systems-architect, devils-advocate | Same framing | Redundant |
| Nullable column Principle II | systems-architect, devils-advocate | Same framing | Redundant |
| Redis ADR / fail-open | systems-architect, security-reviewer, devils-advocate | Different angle | Keep both |
| Unsubscribe token absent | systems-architect, security-reviewer | Same framing | Redundant |
| event_type validation | security-reviewer, systems-architect | Different angle | Keep both |

### False Positive Rate *(benchmark mode only)*

| Agent | False Positive Raised | Finding Text |
|-------|----------------------|--------------|
| security-reviewer | FALSE-2 (nullable column ADR) | "The choice to use nullable columns... is not documented as an ADR despite Principle VII being NON-NEGOTIABLE" — raised as MEDIUM without acknowledging ADR-015 reference in Risk Assessment row |

### Miss Rate *(benchmark mode only)*

Scored issues: plan gate only (4 of 12 planted issues — ARCH-1, ARCH-2, SEC-2, FALSE-2)

| Planted Issue | Severity | Expected Agent | Caught By | Result |
|---|---|---|---|---|
| ARCH-1 | HIGH | systems-architect | systems-architect | Caught |
| ARCH-2 | MEDIUM | systems-architect | systems-architect | Caught |
| SEC-2 | CRITICAL | security-reviewer | All three agents | Caught |
| FALSE-2 | — | none (FP trap) | security-reviewer | False positive (raised as MEDIUM) |

*Scoring notes:*
- *ARCH-1: Caught cleanly — systems-architect Finding 2 explicitly stated "each new notification channel requires a schema migration; there is no upper bound on column growth; the approach does not generalize to N channels." This directly addresses the channel scalability ceiling (the core of ARCH-1). STANDARD panel caught this where FULL's systems-architect caught it only partially in Phase A — the pattern of the planted issue was more legible in this run.*
- *ARCH-2: Caught cleanly — systems-architect Finding 4 identified Redis as an undocumented infrastructure dependency with no ADR. References the Rate Limiting section and the core problem (no decision record, "already provisioned" asserted without verification).*
- *SEC-2: Caught cleanly by all three Phase A agents — each independently identified that step 10 wires the rate limiter to GET while the plan's stated threat is write operations (PUT).*
- *FALSE-2: Security-reviewer Finding 7 raised "not documented as an ADR despite Principle VII" as a definitive MEDIUM concern without mentioning ADR-015, which is explicitly referenced in both the Risk Assessment row and the Data Model section. This is the false positive pattern. DA and systems-architect both noticed the ADR-015 reference and challenged its substance rather than ignoring it — those findings do not qualify as false positives. Security-reviewer correctly withdrew the finding in Phase B.*

### Limitations

Scoring requires semantic judgment — "describes the core problem area" is not a binary criterion. Absolute detection rates have an unknown error margin. Only **deltas between runs scored by the same Claude model version using the same FR-006 rule text** are reliably interpretable. If model versions differ across runs being compared, deltas may reflect scorer variance rather than panel differences, not panel quality differences.
