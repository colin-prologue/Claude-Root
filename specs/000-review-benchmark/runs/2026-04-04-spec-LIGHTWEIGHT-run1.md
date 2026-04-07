# Benchmark Run: spec / LIGHTWEIGHT / 2026-04-04 run 1

**Panel**: devils-advocate, synthesis-judge
**Contamination**: CLEAN
**Model**: claude-sonnet-4-6

---

## Review Synthesis Report — spec gate / LIGHTWEIGHT / 2026-04-04

### Overall Recommendation: REWORK REQUIRED

---

### Coverage Note

LIGHTWEIGHT review — devil's advocate only. Product-strategist and security-reviewer did not run. Compliance findings (DA-01, DA-02) and security/authorization findings (B-01, DA-05) are under-examined without specialist coverage. Several findings marked "Phase B self-surfaced" carry lower confidence.

Synthesis judge strongly recommends a STANDARD or FULL re-review after rework.

---

### Priority Findings (must resolve before plan phase)

| ID | Severity | Finding | Source | Resolution Required |
|----|----------|---------|--------|---------------------|
| DA-02 | HIGH | Opt-out push defaults without documented GDPR consent basis or lawful basis alternative. Cannot be deferred silently. | Phase A | Document lawful basis in spec; or change default to opt-in |
| DA-03 | HIGH | CRITICAL_ALERT user-toggleable with no override warning, no fallback, no delivery guarantee. Label implies guarantee that spec does not provide. | Phase A | Either define delivery guarantee and remove toggle, or rename the type |
| B-01 | HIGH | No ownership enforcement on preference write endpoint — IDOR vulnerability; any authenticated user could overwrite another's preferences. | Phase B self-surfaced | Add AC requiring preference writes scoped to authenticated user's own record |

---

### Standard Findings (should resolve before implementation)

| ID | Severity | Finding | Source | Resolution Required |
|----|----------|---------|--------|---------------------|
| DA-01 | MEDIUM | Single-event unsubscribe may not satisfy CAN-SPAM / GDPR one-click unsubscribe requirements | Phase A (softened from HIGH) | Confirm regulatory requirements; add AC if one-click unsubscribe required |
| DA-05 | MEDIUM | Unsubscribe token expiry, single-use, and replay protection unspecified | Phase A | Add token security requirements to US2 ACs |
| DA-06 | MEDIUM | Preference lookup sync vs. cached behavior undefined; failure mode (fail open/closed) unspecified | Phase A | Document lookup contract and failure behavior in spec or open questions |
| DA-04 | MEDIUM | "One session refresh" is not a measurable SLA | Phase A | Replace with time-bound SLA |
| B-02 | MEDIUM | Sad-path ACs absent: save failure, delivery lookup failure, partial channel failure | Phase B self-surfaced | Add sad-path ACs for each failure mode |
| B-03 | MEDIUM | No read path for support/admin persona; no ad-hoc access documented | Phase B self-surfaced | Add support persona story or explicitly document as out of scope |
| B-04 | MEDIUM | Compliance boundary ownership unspecified — feature vs. platform | Phase B reframe | Add one-sentence scope statement clarifying compliance ownership |

---

### Low-Signal / Low-Priority Findings

| ID | Severity | Finding | Disposition |
|----|----------|---------|-------------|
| DA-07 | LOW-MEDIUM | Unknown future event types not handled | Open question for extensibility |
| DA-08 | LOW | Push/email default asymmetry unexplained | UX polish, not blocker |
| DA-09 | LOW | Persistence metric is QA regression only, not production monitoring | Implement at build phase |
| DA-10 | LOW | "Preference lookup hook" may be net-new infrastructure | Confirm at plan phase |
| B-05 | LOW-MEDIUM | Data retention on account deletion unspecified | Escalate if no platform-level handler |
| B-06 | LOW-MEDIUM | No positive outcome metric; success criteria are guardrail-only | Refine at spec revision |

---

### Overlap Clusters

Single reviewer only. The table below reflects internal Phase A / Phase B convergence:

| Cluster | IDs | Signal |
|---------|-----|--------|
| Compliance / consent | DA-01, DA-02, B-04 | Root gap: no regulatory regime or compliance boundary documented |
| Authorization / security | DA-05, B-01 | Two findings on auth/authorization gaps — likely underweighted without security-reviewer |
| Measurability / observability | DA-04, DA-09, B-06 | Weak success criteria throughout |
| Failure handling | DA-06, B-02 | Feature behavior under degraded conditions entirely unspecified |

---

### Preserved Dissent

- **DA-01 softening**: DA self-softened from HIGH to MEDIUM. Synthesis preserves both readings — for a regulatory item with material penalty exposure, the distinction may be academic.
- **Compliance boundary reframe**: Unresolved. If platform owns compliance boundary, DA-01/DA-02 may close without spec changes. If feature owns it, both remain HIGH.

---

### Unresolved Items

1. **GDPR lawful basis for push defaults** — Requires legal/compliance or product decision before plan phase.
2. **CRITICAL_ALERT semantics** — Binary product decision: delivery guarantee or not?
3. **Compliance boundary ownership** — Blocks full resolution of DA-01, DA-02, B-04.
4. **Security reviewer gap** — B-01 and DA-05 were self-surfaced; carry lower confidence without specialist validation.

---

### Synthesis Notes

Three highest-priority issues are structurally distinct: one compliance gap (DA-02), one semantic ambiguity that drives the technical design (DA-03), one authorization flaw (B-01). None require a full rewrite. REWORK REQUIRED reflects unresolved compliance boundary ownership and the IDOR gap — not a judgment that the spec is fundamentally unsound.

Coverage limitation: this synthesis represents approximately 40% of the intended review surface. If the feature carries regulatory exposure, a STANDARD or FULL re-review after rework is strongly recommended.

---

## Panel Efficiency Report

**Mode**: Benchmark
**Panel**: devils-advocate, synthesis-judge
**Gate**: spec
**Rigor**: LIGHTWEIGHT
**Run**: 2026-04-04 run 1
**Contamination**: CLEAN

### Unique Contribution by Agent

| Agent | Unique Findings | Shared Findings | Unique Rate |
|-------|----------------|-----------------|-------------|
| devils-advocate | 10 | 0 | 100% (single-agent; not a diversity signal) |

### Overlap Clusters

Single reviewer — no cross-agent overlap computable. Internal convergence clusters noted in synthesis (compliance/consent, auth/security, measurability, failure handling).

### False Positive Rate *(benchmark mode only)*

No false positives raised.

### Miss Rate *(benchmark mode only)*

| Planted Issue | Severity | Expected Agent | Caught By | Result |
|---|---|---|---|---|
| PROD-1 | HIGH | product-strategist | — | Missed (product-strategist not in LIGHTWEIGHT panel) |
| PROD-2 | MEDIUM | product-strategist | — | Missed (product-strategist not in LIGHTWEIGHT panel) |
| SEC-1 | HIGH | security-reviewer | — | Missed (security-reviewer not in LIGHTWEIGHT panel; B-01 Phase B self-surface does not qualify per FR-006) |
| FALSE-1 | — | (none) | (none triggered) | Pass |

*(4 of 12 total planted issues applicable at spec gate)*

### Limitations

Scoring requires semantic judgment — "describes the core problem area" is not a binary criterion. Absolute detection rates have an unknown error margin. Only **deltas between runs scored by the same Claude model version using the same FR-006 rule text** are reliably interpretable. If model versions differ across runs being compared, deltas may reflect scorer variance rather than panel quality differences.
