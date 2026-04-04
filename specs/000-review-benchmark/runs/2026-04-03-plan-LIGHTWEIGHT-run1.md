# Benchmark Run: plan / LIGHTWEIGHT / 2026-04-03 run 1

**Panel**: devils-advocate, synthesis-judge
**Contamination**: CLEAN
**Model**: claude-sonnet-4-6 (Sonnet 4.6)

---

# Review Synthesis Report
**Feature:** User Notification Preferences (fixture)
**Artifact:** `specs/000-review-benchmark/fixture/spec.md` + `fixture/plan.md`
**Gate:** plan | **Rigor:** LIGHTWEIGHT
**Date:** 2026-04-03

---

## 1. Executive Summary

The plan contains structural defects serious enough to produce a defective implementation if carried forward unchanged. Four HIGH findings share a common root: the plan lacks boundary validation for the primary write path, inverts TDD ordering, misapplies rate limiting to the wrong HTTP verb, and introduces a nullable-boolean three-state pattern that violates Principle II (NON-NEGOTIABLE). One CRITICAL finding — unreferenced ADR files treated as "Accepted" — undermines traceability entirely.

**Gate Decision: REVISE AND RESUBMIT**

---

## 2. Critical & High Findings

### [CRITICAL] ADR References Not Verified as Existing Files
ADR-012 and ADR-015 are listed in the plan as "Accepted." A table entry is not an ADR file. ADR-015 covers the nullable-column pattern — Principle VII NON-NEGOTIABLE requires a traceable decision record. Both files must exist on disk before this plan proceeds.

### [HIGH] TDD Ordering Inverted
Service logic (step 4) written before unit tests (step 5). Controller (step 6) before integration tests (step 8). Repository layer (`prefs.repository.ts`) has no tests in any phase. Reorder: tests before each implementation step; add repository-layer tests explicitly.

### [HIGH] Rate Limiter Wired to GET, Not PUT
Step 10 applies the rate limiter to the GET endpoint. The plan's stated threat is write spam on PUT. GET is idempotent. This is a misplaced control — move rate limiter to PUT.

### [HIGH] PUT Request Body Schema Absent
No field names, type constraints, maximum array size, or valid `event_type` enumeration specified for the primary write path. Principle V requires boundary validation. Without a schema, validation logic cannot be written, tested, or reviewed.

### [HIGH] Nullable Boolean Columns Violate Principle II (NON-NEGOTIABLE)
NULL = "use platform default" creates a three-state boolean (true/false/null) to support a hypothetical third notification channel that does not currently exist. This is speculative abstraction. Columns must be non-nullable with explicit boolean defaults.

---

## 3. Medium Findings

**[MEDIUM] No Audit Attribution Despite Live GDPR Question** — `updated_at` exists but `updated_by` does not. OQ-1 flags GDPR as an open question. Retrofitting attribution requires a destructive migration. Resolve OQ-1 or add `updated_by` now.

**[MEDIUM] Fail-Open Redis Not Examined as Failure Mode** — Redis unavailability bypasses rate limiting entirely. Presented as mitigation; is actually unbounded write acceptance. The fail-open vs. fail-closed decision must be stated and justified.

**[MEDIUM] Versioning Strategy Not Visible in Plan** — spec constraint "must be versioned" deferred entirely to an external ADR. The versioning approach must be stated in the plan body, with the ADR as a supporting reference.

**[MEDIUM] Repository Layer Untested** — `prefs.repository.ts` upsert and ON CONFLICT logic has no test coverage. Add repository-layer tests as an explicit step.

---

## 4. Low Findings

**[LOW] Partial-Update Merge Semantics Unstated** — PUT accepts a partial field set. Without stated merge semantics, the idempotency requirement cannot be verified.

**[LOW] Unsubscribe Token Handling Absent** — spec dependency on email pipeline for token validation; plan has no token design, endpoint, or security consideration. Deferral should be explicit.

---

## 5. Unresolved Items — LOG Recommendations

| ID | Title | Trigger |
|---|---|---|
| LOG-NEW-1 | GDPR attribution decision — `updated_by` inclusion or formal risk acceptance | OQ-1 still open at plan gate |
| LOG-NEW-2 | Fail-open Redis — acceptable behavior for rate limiter unavailability | Unexamined failure path |
| LOG-NEW-3 | Unsubscribe token design deferred | Spec dependency with no plan coverage |

---

## 6. ADR Recommendations

| ID | Title | Trigger |
|---|---|---|
| ADR-012 | Must exist — create or locate | Referenced as "Accepted"; not verified |
| ADR-015 | Must exist and reflect non-nullable decision | Principle VII NON-NEGOTIABLE; Principle II violated by current design |

---

## 7. Gate Decision

**REVISE AND RESUBMIT**

Required:
1. Confirm ADR-012 and ADR-015 exist; update ADR-015 to reflect non-nullable decision
2. Change nullable boolean columns to non-nullable with explicit defaults
3. Define PUT request body schema
4. Reorder TDD steps; add repository-layer tests
5. Move rate limiter from GET to PUT

Recommended:
- Resolve or formally defer OQ-1 (GDPR / `updated_by`)
- State versioning approach in plan body
- Document Redis fail-open decision explicitly

---

⚠️ No overlap clusters detected — single-reviewer LIGHTWEIGHT panel; all Phase A findings are unique per agent.

---

---

## Panel Efficiency Report

**Mode**: Benchmark
**Panel**: devils-advocate, synthesis-judge
**Gate**: plan
**Rigor**: LIGHTWEIGHT
**Run**: 2026-04-03 run 1
**Contamination**: CLEAN

### Unique Contribution by Agent

| Agent | Unique Findings | Shared Findings | Unique Rate |
|-------|----------------|-----------------|-------------|
| devils-advocate | 11 | 0 | 100% |

*Single-reviewer panel — no cross-agent sharing possible. Unique rate is trivially 100%.*

### Overlap Clusters

⚠️ No overlap clusters detected — single-reviewer LIGHTWEIGHT panel; all Phase A findings are unique per agent.

### False Positive Rate *(benchmark mode only)*

No false positives raised. The devils-advocate noticed that ADR-015 is referenced in the plan ("ADR-015 in particular covers the nullable-column pattern") and challenged whether the file actually exists — this is not the false positive pattern (ignoring the ADR-015 reference). The nullable column finding was framed as a Principle II violation, not as an absent ADR.

### Miss Rate *(benchmark mode only)*

Scored issues: plan gate only (4 of 12 planted issues — ARCH-1, ARCH-2, SEC-2, FALSE-2)

| Planted Issue | Severity | Expected Agent | Caught By | Result |
|---|---|---|---|---|
| ARCH-1 | HIGH | systems-architect | devils-advocate (partial) | Caught (partial) |
| ARCH-2 | MEDIUM | systems-architect | — | Missed |
| SEC-2 | CRITICAL | security-reviewer | devils-advocate | Caught |
| FALSE-2 | — | none (FP trap) | — | Not raised as FP (correct) |

*Scoring notes:*
- *ARCH-1: Caught (partial) — DA raised the nullable boolean column pattern as a Principle II violation (speculative abstraction for a hypothetical third channel that doesn't exist). This is the correct artifact section (Data Model) and the correct pattern (nullable columns), but the framing is wrong: DA's concern is "don't future-proof now," and DA explicitly states that adding a column migration later is "straightforward." The core issue of ARCH-1 is that this pattern requires a schema migration for every new channel and the plan doesn't address scalability beyond 3 channels — the scalability ceiling argument. DA's Principle II framing inverts the concern (DA says migrations are easy; ARCH-1 says migrations are the problem).*
- *ARCH-2: Missed — No DA finding identified Redis as an undocumented runtime dependency absent from the Stack table with no corresponding ADR. DA's CRITICAL finding addressed ADR-012 and ADR-015 (the two listed ADRs) as potentially non-existent files. DA's MEDIUM finding addressed the fail-open Redis behavior. Neither finding framed Redis as a new dependency requiring its own ADR — the closest angle (fail-open) addressed operational behavior, not the dependency declaration gap.*
- *SEC-2: Caught cleanly — DA Finding 3 explicitly identified that step 10 wires the rate limiter to GET /api/v1/preferences/notifications while the plan's stated threat is preference-update spam (write operations via PUT). Clear connection between the plan's stated intent and the actual wiring error.*
- *FALSE-2: Not raised as definitive false positive. DA's CRITICAL finding noted "ADR-015 in particular covers the nullable-column / default-resolution-at-read-time pattern" — DA acknowledged ADR-015 exists as a referenced decision and challenged whether the file actually exists on disk. This is a more nuanced argument than the false positive trap describes (flagging absent ADR without noticing the reference). DA's nullable column finding (HIGH) framed the issue as Principle II, not as "no ADR exists."*

### Limitations

Scoring requires semantic judgment — "describes the core problem area" is not a binary criterion. Absolute detection rates have an unknown error margin. Only **deltas between runs scored by the same Claude model version using the same FR-006 rule text** are reliably interpretable. If model versions differ across runs being compared, deltas may reflect scorer variance rather than panel differences, not panel quality differences.
