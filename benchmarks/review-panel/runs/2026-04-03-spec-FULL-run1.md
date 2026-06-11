# Benchmark Run: spec / FULL / 2026-04-03 run 1

**Panel**: product-strategist, security-reviewer, devils-advocate, synthesis-judge
**Contamination**: CLEAN
**Model**: claude-sonnet-4-6 (Sonnet 4.6)

---

# Review Synthesis Report
**Feature:** User Notification Preferences (fixture)
**Artifact:** `specs/000-review-benchmark/fixture/spec.md`
**Gate:** spec | **Rigor:** FULL
**Date:** 2026-04-03

---

## 1. Executive Summary

The spec establishes a reasonable functional skeleton for user notification preferences but carries three critical structural gaps that block clean implementation: (1) no authorization/ownership requirement, leaving IDOR fully unaddressed; (2) no unsubscribe token security properties, making the P2 email feature incomplete as specified; and (3) an Article 21 (GDPR right to object) exposure created by the P1/P2 deferral split, where users have no in-product mechanism to manage email preferences during the deferral window.

Phase B devil's advocate intervention correctly deflated the panel's groupthink around audit logging as a GDPR launch gate — that finding has been downgraded and repositioned. The more serious Article 21 gap was surfaced only in Phase B and is treated here as a synthesis-level HIGH.

The spec is not blockable on grounds of irredeemable structural failure, but it requires targeted revisions to Authorization/IDOR requirements, token security, Article 21 posture, and three medium-tier gaps before planning begins.

**Gate Decision: REVISE**

---

## 2. Critical & High Findings

### H-1 | Authorization / IDOR — No Ownership Requirement
**Source:** [security-reviewer] HIGH — consensus (DA reframe sharpened rather than downgraded)
**Location:** User Stories (all) + Dependencies

The spec specifies "session token validation" as the security mechanism but never states that users may only read or modify their own preferences. Session token validation confirms identity; it does not enforce ownership. The gap between authentication and authorization is a textbook IDOR precondition. No acceptance criterion, constraint, or dependency row closes this.

**Required action:** Add an explicit ownership constraint: "A user may only read and modify their own notification preferences. The API must reject any request where the authenticated user's identity does not match the resource owner, returning 403."

---

### H-2 | Unsubscribe Token Security — No Security Properties Defined
**Source:** [security-reviewer] HIGH — uncontested
**Location:** User Story 2 AC + Dependencies

The spec describes one-click email unsubscribe behavior but defines no security properties for the unsubscribe token: no expiry requirement, no single-use enforcement, no binding to a specific user+event combination. A reusable, non-expiring token constitutes a persistent IDOR vector via the email channel.

**Required action:** Add a constraints row or acceptance criterion specifying: token must be single-use, must expire (define TTL), and must be cryptographically bound to a specific (user_id, event_type, channel) triple.

---

### H-3 | Article 21 Exposure — P1/P2 Deferral Gap
**Source:** [product-strategist] revised + DA Phase B synthesis — consensus
**Location:** User Story 2 (P2 deferral), OQ-1

GDPR Article 21 grants users an unconditional right to object to processing for direct marketing. The P1/P2 split defers all email preference management to a later sprint. During the deferral window, users have no in-product mechanism to exercise this right.

**Required action:** Either (a) scope email preference management into P1, or (b) document an explicit legal risk acceptance with a hard deadline for P2 delivery, with data protection stakeholder sign-off. OQ-1 must be revised accordingly.

---

### H-4 | "Within One Session Refresh" — Ambiguous and Non-Testable AC
**Source:** [product-strategist] HIGH — uncontested
**Location:** User Story 1 AC

"Within one session refresh" is ambiguous between "immediately on save" and "visible after a page reload" — different behavioral contracts with different engineering implications.

**Required action:** Replace with a precise, observable criterion specifying exact propagation SLA and failure-mode behavior.

---

### H-5 | No Admin/Operator Story — Stakeholder Coverage Gap
**Source:** [product-strategist] HIGH — uncontested
**Location:** User Stories (all)

No admin or operator story exists. The spec does not exclude admin management of preferences as an explicit non-goal, leaving scope ambiguous for implementers.

**Required action:** Add a non-goals exclusion for admin management of individual user preferences, or add an admin story if the use case is intended.

---

## 3. Medium Findings

### M-1 | Input Validation — No Allowlist Requirement
**Source:** [security-reviewer] MEDIUM | Location: Constraints (absent)
No requirement to validate event_type and channel values against the defined allowlist.
**Action:** Add constraint requiring 400 response for unknown event types or channel values.

### M-2 | CRITICAL_ALERT Opt-Out — User Harm Consequence
**Source:** [security-reviewer] upgraded to MEDIUM in Phase B
**Location:** Event Types table
Spec allows silencing CRITICAL_ALERT. If security-relevant, this creates a user harm vector (user believes they are protected; system sends no alert on compromise).
**Action:** Clarify whether CRITICAL_ALERT is non-configurable or configurable with documented accepted risk.

### M-3 | Rate Limiting — No Requirement on Preference-Save Endpoint
**Source:** [security-reviewer] MEDIUM | Location: Absent
No per-user rate limit requirement leaves the endpoint open to automated abuse.
**Action:** Add constraint specifying per-user write rate limit.

### M-4 | WEEKLY_DIGEST Push Default — Unexplained for New Users
**Source:** [product-strategist] MEDIUM | Location: Event Types table
Push default "enabled" for WEEKLY_DIGEST fires for brand-new users with no activity — appears unintentional.
**Action:** Confirm intent; document rationale or correct default.

### M-5 | Email Unsubscribe Metric Ambiguity
**Source:** [product-strategist] MEDIUM | Location: Success Criteria table
">80% via unsubscribe link" could signal good UX or poor settings discoverability — not a directionally unambiguous success indicator.
**Action:** Pair with complementary discoverability metric.

### M-6 | Master Toggle Deferral — Unexplained Pairing with 022-notification-history
**Source:** [product-strategist] (elevated from LOW in context)
OQ-2 bundles master toggle with notification history feature without justification.
**Action:** Add rationale to OQ-2 explaining why this belongs in 022, not here.

---

## 4. Minority / Dissent Findings (Preserved)

**D-1 | Audit Logging Deferral — Downgraded to LOW, Process Gap Retained**
Source: [security-reviewer], originally MEDIUM; DA challenge accepted. The deferral is not a security vulnerability but the absence of a formal risk acceptance record under Principle V remains a process gap. Preserved for tracking.

**D-2 | Delivery Fallback Contract — Correctly Out of Scope at Spec Gate**
Source: DA Phase B. Delivery fallback behavior belongs at plan gate. Preserved for handoff to plan reviewer.

**D-3 | Data Retention / Deletion**
Source: [security-reviewer] LOW — uncontested. No data lifecycle requirement for stored preferences. Deferred action item before GA.

**D-4 | Preference Enumeration via Defaults**
Source: [security-reviewer] LOW — uncontested. Differential responses could enumerate valid event types. Low practical impact; noted for plan-gate API design.

**D-5 | Database Dependency Not Listed**
Source: [product-strategist] LOW — uncontested. Persistence layer missing from Dependencies table.

---

## 5. Unresolved Items — LOG Recommendations

| # | Issue | Recommended LOG |
|---|---|---|
| U-1 | Article 21 exposure during P1/P2 deferral — no formal resolution | LOG: GDPR Article 21 risk; requires stakeholder sign-off and P2 hard deadline |
| U-2 | Audit logging deferral — Principle V process gap | LOG: Update OQ-1 tracking entry with formal risk acceptance record |
| U-3 | CRITICAL_ALERT opt-out policy — no authoritative decision | LOG: Decision on CRITICAL_ALERT configurability with explicit criteria |
| U-4 | Master toggle deferred to 022-notification-history — rationale undocumented | LOG: Flag for 022-notification-history pre-work |

---

## 6. ADR Recommendations

| ADR | Decision Area |
|---|---|
| ADR-A | Unsubscribe token design — single-use vs. time-bounded vs. signed JWT; user+event binding; revocation |
| ADR-B | Preference resource ownership enforcement — middleware vs. query-layer; IDOR mitigation pattern |
| ADR-C | Non-configurable notification types — criteria for MANDATORY classification; governance process |

---

## 7. Gate Decision

**REVISE** — Minimum revisions before proceeding to `/speckit.plan`:
1. Add ownership/authorization constraint (H-1)
2. Add unsubscribe token security properties (H-2)
3. Resolve or formally document Article 21 deferral posture (H-3)
4. Replace "within one session refresh" with a testable criterion (H-4)
5. Add non-goals exclusion for admin scope (H-5)

---

## Overlap Clusters

| Finding Topic | Agents | Overlap Type | Verdict |
|---|---|---|---|
| GDPR / compliance exposure (Article 21 + audit logging) | product-strategist (finding 5), security-reviewer (finding 4) | Different angle — PS: user rights gap during deferral; SR: audit trail absence; DA separated them | Keep both |
| Unsubscribe behavior | product-strategist (finding 4: metric ambiguity), security-reviewer (finding 2: token security) | Partial match — same feature area (email unsubscribe), completely different layers (UX vs. security) | Keep both |

---

---

## Panel Efficiency Report

**Mode**: Benchmark
**Panel**: product-strategist, security-reviewer, devils-advocate, synthesis-judge
**Gate**: spec
**Rigor**: FULL
**Run**: 2026-04-03 run 1
**Contamination**: CLEAN

### Unique Contribution by Agent

| Agent | Unique Findings | Shared Findings | Unique Rate |
|-------|----------------|-----------------|-------------|
| product-strategist | 5 | 2 | 71% |
| security-reviewer | 6 | 2 | 75% |

*Shared topics: GDPR/compliance (both agents, different angles) and unsubscribe behavior (both agents, different layers). Overlap Clusters table above. devil's advocate contributed Phase B challenges and surfaced the Article 21 gap — not scored as Phase A unique findings.*

### Overlap Clusters

Issues raised by 2+ agents:

| Finding Topic | Agents | Overlap Type | Verdict |
|---|---|---|---|
| GDPR / compliance exposure | product-strategist, security-reviewer | Different angle | Keep both |
| Unsubscribe behavior | product-strategist, security-reviewer | Partial match | Keep both |

### False Positive Rate *(benchmark mode only)*

No false positives raised. Neither agent flagged the FALSE-1 trap (OQ-2 master toggle) as a definitive HIGH or MEDIUM concern. product-strategist raised it as LOW with explicit acknowledgment of OQ-2's content.

### Miss Rate *(benchmark mode only)*

Scored issues: spec gate only (4 of 12 planted issues — PROD-1, PROD-2, SEC-1, FALSE-1)

| Planted Issue | Severity | Expected Agent | Caught By | Result |
|---|---|---|---|---|
| PROD-1 | HIGH | product-strategist | product-strategist | Caught |
| PROD-2 | MEDIUM | product-strategist | product-strategist | Caught (partial) |
| SEC-1 | HIGH | security-reviewer | security-reviewer | Caught |
| FALSE-1 | — | none (FP trap) | — | Not raised (correct) |

*Scoring notes:*
- *PROD-1: Caught cleanly — product-strategist referenced the missing admin persona gap with multi-sentence reasoning and cross-referenced CRITICAL_ALERT context.*
- *PROD-2: Caught (partial) — product-strategist questioned the P2 assignment but framed it as a compliance risk (GDPR/CAN-SPAM), not the core issue: email is the foundational channel reaching 100% of users while push is mobile-only. The business reach argument appeared only in Phase B via the devil's advocate.*
- *SEC-1: Caught cleanly — security-reviewer precisely distinguished session authentication from ownership authorization, identified the IDOR precondition, and called out the gap between the dependency listing and an actual access control requirement.*
- *FALSE-1: Not raised as definitive concern. product-strategist mentioned OQ-2 at LOW severity with hedging ("deserves justification"), which does not qualify as a false positive.*

### Limitations

Scoring requires semantic judgment — "describes the core problem area" is not a binary criterion. Absolute detection rates have an unknown error margin. Only **deltas between runs scored by the same Claude model version using the same FR-006 rule text** are reliably interpretable. If model versions differ across runs being compared, deltas may reflect scorer variance rather than panel differences, not panel quality differences.
