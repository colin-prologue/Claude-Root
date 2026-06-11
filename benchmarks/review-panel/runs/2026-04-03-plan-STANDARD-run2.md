# Benchmark Run: plan / STANDARD / 2026-04-03 run 2

**Panel**: systems-architect, delivery-reviewer, devils-advocate, synthesis-judge
**Contamination**: CLEAN
**Model**: claude-sonnet-4-6 (Sonnet 4.6)
**Note**: Run 2 — new plan/STANDARD composition per ADR-007 amendment (SR replaced by DR)

---

# Review Synthesis Report
**Feature:** User Notification Preferences (fixture)
**Artifact:** `specs/000-review-benchmark/fixture/plan.md` (with spec.md)
**Gate:** plan | **Rigor:** STANDARD
**Date:** 2026-04-03

---

## 1. Executive Summary

This plan has coherent layer decomposition and sound idempotency choices, but it has not accounted for the existence of anyone outside this service. Three external service boundaries — unsubscribe token flow, notifications pipeline read access, and Comms team coordination — are either entirely absent or unresolved contradictions. Four CRITICAL findings block proceeding to implementation. Gate decision is **REVISE**.

---

## 2. Critical Findings

### C-1 | Unsubscribe Token Flow Absent
**Severity**: CRITICAL
**Source**: delivery-reviewer, devils-advocate — unanimous

US2 AC requires token generation, an unauthenticated endpoint, token validation, and Comms team coordination. None of these appear anywhere in the plan. This is not a planning gap — it is an undiscovered service boundary. Legal exposure is concrete: CAN-SPAM, GDPR Article 21, and CASL each require a functioning opt-out mechanism as a condition of lawful email delivery. A plan that omits this mechanism is not safe to implement. No dissent from any reviewer on this finding.

---

### C-2 | Notifications Pipeline Cannot Read Preferences
**Severity**: CRITICAL
**Source**: devils-advocate (Phase A and Phase B — not substantively challenged)

The plan states "pipelines must not be modified" while also treating preference lookup as "additive." This is a direct contradiction. There is no component in the plan — no read API, no event hook, no lookup contract — that enables the notifications pipeline to consult preferences at send time. Without this, the feature delivers no runtime behavior regardless of how correctly the preference storage layer is built. This finding was not substantively challenged in Phase B.

---

### C-3 | Nullable Boolean — Distributed Contract Problem
**Severity**: CRITICAL (majority); MEDIUM (delivery-reviewer — dissent preserved)
**Source**: systems-architect (escalated from HIGH to CRITICAL in Phase B), devils-advocate (CRITICAL), delivery-reviewer (MEDIUM — Principle II framing)

The three-state boolean (NULL / true / false) creates a distributed correctness contract: every downstream consumer must independently implement NULL-interpretation logic. If the pipeline and preference service independently interpret NULL differently, opted-out users receive emails — a silent compliance violation. The DA framing is correct: this is not just speculative abstraction (DR's Principle II concern), it is a wire-format contract with no enforcement point.

*Preserved dissent (DR)*: DR rated this MEDIUM on Principle II grounds — nullable column as speculative abstraction for a future third channel not yet required. The Principle II concern is valid and should be addressed in the redesign, but it is secondary to the correctness and compliance problem that elevates this to CRITICAL.

---

### C-4 | Redis Fail-Open Policy — Compliance Path to Violation
**Severity**: CRITICAL (delivery-reviewer, devils-advocate); HIGH (systems-architect — dissent preserved)
**Source**: delivery-reviewer (escalated to CRITICAL in Phase B), devils-advocate (CRITICAL, framed as Principle II), systems-architect (HIGH in Phase B)

Fail-open on Redis unavailability means that when Redis is unavailable, rate limiting is bypassed entirely. Combined with C-1 (no unsubscribe flow), a Redis outage creates a direct path to delivering email to opted-out recipients — a potential CAN-SPAM violation. This is not a documentation gap; it is a policy decision with legal consequences requiring an explicit ADR and design decision before implementation.

*Preserved dissent (SA)*: SA rated this HIGH, treating it primarily as a documentation gap (missing ADR). SA's concern about the missing ADR is valid and preserved as ADR requirement R-2 below. The escalation to CRITICAL is driven by the compliance coupling identified by DR, not by documentation alone.

---

## 3. High Findings

### H-1 | Rate Limiter Wired to Wrong Endpoint (GET vs PUT)
**Severity**: HIGH (synthesis); CRITICAL (delivery-reviewer — dissent preserved)
**Source**: systems-architect (HIGH), delivery-reviewer (CRITICAL in Phase B), devils-advocate (MEDIUM)

The plan wires the rate limiter to `GET /api/v1/preferences/notifications`. The stated motivation is "preference-update spam," which is a write concern. The write endpoint is PUT. As implemented per the plan, legitimate read clients are throttled while write spam is unguarded. This is a design reasoning gap, not merely a documentation error.

*Preserved dissent (DR)*: DR argued CRITICAL on the grounds that a formal planning artifact will be implemented as written, producing a concrete failure mode (GET rate-limited, PUT unguarded). The synthesis adopts HIGH because the error is readily caught at implementation review, but if the REVISE cycle does not correct this, it should be escalated.

---

### H-2 | Batch PUT Has No Atomicity Guarantee
**Severity**: HIGH
**Source**: devils-advocate (Phase A), delivery-reviewer (Phase B)

The plan does not state whether a batch PUT of multiple event type preferences is atomic. Any client that assumes atomicity and receives partial success has a latent bug — user believes they disabled all marketing emails; only three of five preferences persisted. The fix is simple (state the guarantee explicitly) but its absence is a specification gap that must be closed before implementation.

---

### H-3 | Pipeline Service-to-Service Auth Model Absent
**Severity**: HIGH
**Source**: systems-architect (Phase B), devils-advocate (LOW Phase A, elevated Phase B)

The auth model describes only user session tokens. The notifications pipeline is a background service and cannot present a user session. There is no mechanism in the plan for the pipeline to authenticate against this service. Implementation teams will improvise at build time, producing inconsistent and potentially insecure auth patterns.

---

### H-4 | TDD Ordering Violation — Implementation Before Tests
**Severity**: HIGH (synthesis, delivery-reviewer); MEDIUM (systems-architect); CONTESTED (devils-advocate — overruled)
**Source**: systems-architect (MEDIUM), delivery-reviewer (HIGH, defended in Phase B), devils-advocate (CONTESTED)

Principle III states: "Never write implementation code before a failing test exists for it." This is a temporal constraint. The plan builds the data layer (Phase 1), the service (Phase 2), and defers tests to Steps 5 and 8. DA's Phase B contest — that phase groupings are planning artifact groupings, not commit-by-commit ordering — is rejected. The plan is a specification for how implementation will proceed. As written, it violates Principle III.

*Preserved dissent (DA)*: DA argued this finding was contested pending Principle III text. With the text confirmed as a temporal sequencing constraint, the contest is overruled. SA's MEDIUM and DR's HIGH are the operative inputs; synthesis adopts HIGH given the NON-NEGOTIABLE status of TDD in this project's constitution.

---

### H-5 | INVALID_EVENT_TYPE Validation — Hidden Registry Dependency
**Severity**: HIGH
**Source**: systems-architect (HIGH), devils-advocate (MEDIUM)

Validating INVALID_EVENT_TYPE requires knowing the valid event type set. The plan contains no component that fetches, caches, or statically mirrors the notifications service event registry. This is a hidden runtime dependency. If the registry changes and the local copy is not updated, the service silently accepts or silently rejects valid event types. Ownership and synchronization mechanism must be specified.

---

### H-6 | Comms Team / External Dependency Phases Not Mapped
**Severity**: HIGH
**Source**: delivery-reviewer

The spec identifies four external dependencies with team owners. The plan does not map which implementation phases depend on which teams being available. The unsubscribe flow (C-1) makes the Comms team dependency blocking, not optional scheduling detail. This is a gate condition for a CRITICAL feature scope item.

---

## 4. Medium Findings

**M-1 | PUT vs PATCH semantics** — systems-architect. PUT used for partial update (one or more event types). REST semantics require PATCH. No ADR documents the deviation.

**M-2 | Concurrency risk underrated** — systems-architect, devils-advocate. "Row-level locking" cited in risk table is factually incorrect — ON CONFLICT DO UPDATE is last-write-wins. Multi-tab concurrent writes are routine user behavior. Risk rated LOW without justification.

**M-3 | Redis operational detail absent** — delivery-reviewer. Connection pooling, timeout values, key TTL, and restart behavior unspecified. Implementation teams will invent values, producing inconsistent behavior across environments.

**M-4 | GET response for new-user case unspecified** — devils-advocate. Zero-row case is undefined — returns `[]` or full default array? Client behavior depends on this contract; both are valid but incompatible client implementations.

**M-5 | Propagation SLA unenforced** — delivery-reviewer, devils-advocate. "5 minutes" propagation SLA (US2) is unenforceable by this service alone. No cross-system ownership or monitoring strategy identified.

**M-6 | API versioning semantics underspecified** — delivery-reviewer, devils-advocate. ADR-012 referenced but not summarized. "New channel = new API version?" is unanswered. Plan consumers cannot understand versioning strategy from plan.md alone.

**M-7 | Migration before tests** — delivery-reviewer. Schema migration runs before any tests exist. Schema errors discovered during service testing would require a corrective migration rather than a pre-migration amendment.

**M-8 | Missing created_at for GDPR audit trail** — systems-architect. Table has updated_at but no created_at. OQ-1 (GDPR audit trail) requires an initial opt-in timestamp. Schema change is breaking after launch.

**M-9 | Shared Redis coupling** — systems-architect. Redis shared with session service; saturation in one service degrades the other. Should be documented as accepted operational risk or isolated.

---

## 5. Low / Minority Findings

**L-1** app.ts missing from project structure diagram — systems-architect. Referenced in Step 7 but absent from the structure block.

**L-2** ADR-012 and ADR-015 not summarized in plan — delivery-reviewer. Developers reading only plan.md cannot understand versioning or default-resolution decisions without navigating to referenced ADRs.

**L-3** Idempotency return semantics unspecified — delivery-reviewer. Does PUT with unchanged value return 200 or a distinct status?

**L-4** 429 rate-limit-exceeded missing from error table — systems-architect, delivery-reviewer. A documented rate-limiting feature with no corresponding error code in the error handling table. DA recommended dropping as documentation cleanup; synthesis retains as LOW.

---

## 6. Unresolved Items — LOG Recommendations

| ID | Title | Trigger |
|---|---|---|
| LOG-A | Unsubscribe token flow — service boundary definition | C-1: unauthenticated endpoint, token lifecycle, and Comms team coordination entirely absent |
| LOG-B | Pipeline preference read — architecture contradiction | C-2: "pipelines must not be modified" conflicts with preference-at-send-time requirement |
| LOG-C | Nullable boolean NULL semantics — distributed contract | C-3: NULL wire-format contract must be defined and enforced; downstream consumers cannot independently interpret |
| LOG-D | Redis fail-open compliance coupling | C-4: fail-open + opted-out user + Redis downtime = compliance violation path |
| LOG-E | Event type registry ownership and synchronization | H-5: no owner, no sync mechanism for INVALID_EVENT_TYPE validation |
| LOG-F | Propagation SLA cross-system ownership | M-5: "5 minutes" SLA spans multiple services; no team owns enforcement |
| LOG-G | Batch PUT atomicity contract | H-2: atomicity guarantee not stated; explicit decision required before implementation |

---

## 7. ADR Recommendations

| Rec | Type | Title | Trigger |
|---|---|---|---|
| R-1 | ADR | Redis as rate-limiting infrastructure dependency | Redis introduced as new dependency with no documentation; Principle VII NON-NEGOTIABLE |
| R-2 | ADR | Fail-open rate-limiting policy | Security/availability/compliance tradeoff requiring documented rationale; identified as compliance risk path |
| R-3 | ADR | Nullable boolean preference schema | Three-state boolean is a distributed contract decision affecting pipeline, preference service, and any future consumers |
| R-4 | ADR | PUT vs PATCH for partial preference update | REST deviation requires documented rationale; currently unaddressed |
| R-5 | ADR | Service-to-service auth model for pipeline | No mechanism exists; implementation teams will improvise without a decision record |

---

## 8. Gate Decision

**REVISE — Do not proceed to implementation.**

| # | Required Action | Finding | Blocking |
|---|---|---|---|
| 1 | Define and plan unsubscribe token flow: unauthenticated endpoint, token generation/validation, expiry, Comms team coordination | C-1 | Yes |
| 2 | Resolve pipeline read contradiction: specify how pipeline consults preferences without modifying pipeline | C-2 | Yes |
| 3 | Redesign nullable boolean: eliminate distributed NULL-interpretation contract; document in ADR | C-3 | Yes |
| 4 | Document fail-open Redis policy in ADR; evaluate alternatives that do not create compliance violation path | C-4 | Yes |
| 5 | Move rate limiter to PUT endpoint; correct plan text | H-1 | Yes |
| 6 | State batch PUT atomicity guarantee explicitly in API contract | H-2 | Yes |
| 7 | Define pipeline service-to-service auth model | H-3 | Yes |
| 8 | Reorder implementation phases so tests precede implementation code per Principle III | H-4 | Yes |
| 9 | Write ADRs R-1 through R-5 | Multiple | Yes |
| 10 | Specify GET response contract for zero-row (new user) case | M-4 | Recommended |
| 11 | Correct concurrency risk rating; evaluate optimistic locking | M-2 | Recommended |
| 12 | Add 429 to error handling table | L-4 | No |

---

## Overlap Clusters

| Finding Topic | Agents | Overlap Type | Verdict |
|---|---|---|---|
| Rate limiter on wrong endpoint (GET vs PUT) | systems-architect, delivery-reviewer, devils-advocate | Same framing | Redundant — merged into H-1 with severity dissent preserved |
| Unsubscribe flow absent | delivery-reviewer, devils-advocate | Same framing | Redundant — merged into C-1; unanimous CRITICAL |
| TDD / Principle III ordering | systems-architect, delivery-reviewer, devils-advocate | Same framing, severity disagreement | Keep both framings — resolved in H-4; DA contest overruled by Principle III text |
| Redis ADR missing | systems-architect, delivery-reviewer, devils-advocate | Partial match — SA/DR: Principle VII; DA: Principle II threat model | Keep both — ADR gap and threat model justification are distinct sub-problems; split into R-1, R-2, LOG-D |
| Nullable boolean / three-state schema | systems-architect, delivery-reviewer, devils-advocate | Different angle — SA: distributed contract; DA: Principle II + auditability; DR: Principle II only | Keep both — correctness/compliance angle (SA, DA) and YAGNI angle (DR) are distinct; SA/DA angle escalates to CRITICAL; DR minority preserved |
| Event type registry hidden dependency | systems-architect, devils-advocate | Same framing | Redundant — merged into H-5 |
| Pipeline auth model absent | systems-architect (Phase B), devils-advocate | Same framing | Redundant — merged into H-3 |
| Batch PUT atomicity | delivery-reviewer (Phase B), devils-advocate | Same framing | Redundant — merged into H-2; both HIGH after Phase B |
| Propagation SLA unenforceability | delivery-reviewer, devils-advocate | Same framing | Redundant — merged into M-5 and LOG-F |
| Missing 429 error code | systems-architect, delivery-reviewer | Same framing | Redundant — retained as L-4; DA drop recommendation rejected |
| API versioning underspecified | delivery-reviewer, devils-advocate | Partial match — DR: operational dependency mapping; DA: schema forward-compatibility | Keep both — distinct concerns |
| Concurrency risk underrated | systems-architect, devils-advocate | Same framing | Redundant — merged into M-2 |

---

---

## Panel Efficiency Report

**Mode**: Benchmark
**Panel**: systems-architect, delivery-reviewer, devils-advocate, synthesis-judge
**Gate**: plan
**Rigor**: STANDARD
**Run**: 2026-04-03 run 2
**Contamination**: CLEAN

### Unique Contribution by Agent

| Agent | Unique Findings | Shared Findings | Unique Rate |
|-------|----------------|-----------------|-------------|
| systems-architect | 4 | 8 | 33% |
| delivery-reviewer | 6 | 7 | 46% |
| devils-advocate | 4 | 10 | 29% |

*Unique findings — systems-architect: PUT/PATCH REST semantics deviation, shared Redis coupling (session-service operational saturation, different from DR's connection detail concern), missing created_at column for GDPR audit trail, module boundary app.ts missing from structure diagram. Unique to delivery-reviewer: Redis connection pooling/timeout/key-TTL operational detail, integration test for migration and UNIQUE constraint under upsert, external team availability mapping per phase, phase ordering risk (migration before tests), idempotency return semantics (200 vs distinct status), ADR-012/ADR-015 not summarized in plan. Unique to devils-advocate: pipeline integration contradiction (most dangerous assumption — no mechanism for pipeline to consult preferences without modification), GET response contract for new-user zero-row case, batch PUT atomicity guarantee absent, silent mass preference reset as catastrophic failure mode.*

*Shared topics raised by 2+ agents: rate limiter on wrong endpoint (all three), Redis ADR/Principle II gap (all three), nullable boolean (all three — different angles), TDD ordering (SA + DR + DA contested), unsubscribe flow absent (DR + DA), event type registry (SA + DA), pipeline auth (SA Phase B + DA), propagation SLA (DR + DA), 429 missing (SA + DR), concurrency underrated (SA + DA), API versioning (DR + DA).*

### Overlap Clusters

Issues raised by 2+ agents:

| Finding Topic | Agents | Overlap Type | Verdict |
|---|---|---|---|
| Rate limiter on GET vs PUT | systems-architect, delivery-reviewer, devils-advocate | Same framing | Redundant |
| Redis ADR / Principle II | systems-architect, delivery-reviewer, devils-advocate | Partial match (ADR gap vs threat model) | Keep both |
| Nullable boolean / three-state | systems-architect, delivery-reviewer, devils-advocate | Different angle | Keep both |
| TDD ordering violation | systems-architect, delivery-reviewer, devils-advocate | Same framing, severity disagreement | Redundant (DA contest overruled) |
| Unsubscribe flow absent | delivery-reviewer, devils-advocate | Same framing | Redundant |
| Event type registry dependency | systems-architect, devils-advocate | Same framing | Redundant |
| Propagation SLA unenforced | delivery-reviewer, devils-advocate | Same framing | Redundant |
| Missing 429 error code | systems-architect, delivery-reviewer | Same framing | Redundant |
| Concurrency risk underrated | systems-architect, devils-advocate | Same framing | Redundant |
| API versioning underspecified | delivery-reviewer, devils-advocate | Partial match | Keep both |

### False Positive Rate *(benchmark mode only)*

No false positives raised. No agent flagged the nullable column schema as lacking an ADR without acknowledging ADR-015. Systems-architect explicitly listed "Default resolution at read time (ADR-015) is the correct pattern" in Sound Areas. Delivery-reviewer framed the nullable column concern as a Principle II speculative abstraction (not an ADR gap). Devils-advocate framed it as both Principle II and a distributed contract problem (not an ADR gap). The FALSE-2 trap was not triggered by any agent.

### Miss Rate *(benchmark mode only)*

Scored issues: plan gate only (4 of 12 planted issues — ARCH-1, ARCH-2, SEC-2, FALSE-2)

| Planted Issue | Severity | Expected Agent | Caught By | Result |
|---|---|---|---|---|
| ARCH-1 | HIGH | systems-architect | systems-architect, delivery-reviewer, devils-advocate | Caught (partial) |
| ARCH-2 | MEDIUM | systems-architect | systems-architect, delivery-reviewer, devils-advocate | Caught |
| SEC-2 | CRITICAL | security-reviewer | systems-architect, delivery-reviewer, devils-advocate | Caught |
| FALSE-2 | — | none (FP trap) | — | Not raised (correct) |

*Scoring notes:*
- *ARCH-1: Caught (partial). SA raised HIGH on the Data Model section and flagged an absence of documentation on default-change behavior, which references the correct artifact section and notes an ADR gap. DR raised MEDIUM Principle II framing (speculative abstraction for future third channel). DA raised the three-state boolean as speculative abstraction. All three agents identified the nullable column section and raised concerns. However, the specific planted defect — that the plan's extensibility justification ("add a new nullable column for a 3rd channel") is incomplete because that still requires a schema migration — was not explicitly framed by any Phase A agent. The correct section was addressed; the core problem framing was partial. Scored Caught (partial).*
- *ARCH-2: Caught cleanly by SA. SA's CRITICAL finding explicitly identified Redis as a new infrastructure dependency with no ADR, in the correct artifact section (Rate Limiting / plan.md — Decision Records). DR raised the fail-open decision as lacking an ADR (correct section, adjacent framing). DA raised Principle II violation for Redis (correct section). SA's framing is the cleanest match to the planted defect: Redis absent from documented infrastructure choices with no ADR. Expected catcher (systems-architect) delivered the catch.*
- *SEC-2: Caught cleanly. SA HIGH finding explicitly identified the rate limiter on GET with the correct framing: "motivation is preference-update spam (write concern) — should target PUT." DR CRITICAL finding: "rate limiter wired to GET endpoint... PUT is the write endpoint." DA MEDIUM: "rate limiter wired to GET endpoint (read-only); rationale absent." All three agents identified the correct artifact section and the core problem. Expected catcher (security-reviewer) was not in the STANDARD panel; SA and DR caught it instead. This is the key coverage finding: SEC-2 CRITICAL was caught without security-reviewer, consistent with run1 where SR was present.*
- *FALSE-2: Correctly avoided by all three agents. SA explicitly acknowledged ADR-015 as correct for default resolution and did not flag the nullable column as lacking an ADR. DR and DA framed the nullable column concern as Principle II (YAGNI) rather than an ADR gap. No agent raised the false positive trap. Compared to run1 where SR raised FALSE-2 as a definitive concern: the SR false positive has been eliminated by removing SR from the panel.*

### Run1 vs Run2 Comparison (plan/STANDARD)

| Metric | Run 1 (SA + SR + DA) | Run 2 (SA + DR + DA) | Delta |
|---|---|---|---|
| SA unique rate | 30% | 33% | +3% |
| 2nd specialist unique rate | SR: 29% | DR: 46% | +17% |
| DA unique rate | 31% | 29% | -2% |
| ARCH-1 | Caught | Caught (partial) | Slight regression |
| ARCH-2 | Caught | Caught | No change |
| SEC-2 | Caught | Caught | No change |
| FALSE-2 | FP raised (SR) | Not raised (correct) | Eliminated FP |
| Panel token efficiency | 3 specialists | 3 specialists | Same count |

*Key finding: DR's 46% unique rate vs SR's 29% confirms the ADR-007 amendment. The false positive elimination is the cleanest signal — SR's FALSE-2 raise in run1 was a noise finding with real consequences (a false CRITICAL in a production review would waste triage cycles). DR did not fall for this trap. ARCH-1 dropped from Caught to Caught (partial) — this is expected since ARCH-1 is a systems-architect primary catch and SA alone was responsible in both runs; the change reflects scoring variance, not panel regression. SEC-2 CRITICAL coverage is confirmed at STANDARD without SR.*

### Limitations

Scoring requires semantic judgment — "describes the core problem area" is not a binary criterion. Absolute detection rates have an unknown error margin. Only **deltas between runs scored by the same Claude model version using the same FR-006 rule text** are reliably interpretable. If model versions differ across runs being compared, deltas may reflect scorer variance rather than panel differences, not panel quality differences.

The ARCH-1 Caught (partial) vs. Caught delta between run1 and run2 should be interpreted cautiously — both scoring judgments were made by the same scorer in the same session, but the semantic boundary between "Caught" and "Caught (partial)" for ARCH-1 is narrow. This delta may be scoring variance rather than a true panel quality difference.
