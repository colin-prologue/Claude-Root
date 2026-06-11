# Benchmark Run: plan / STANDARD / 2026-04-04 run 1

**Panel**: systems-architect, security-reviewer, devils-advocate, synthesis-judge
**Contamination**: CLEAN
**Model**: claude-sonnet-4-6

> ⚠️ **Composition note**: This run used `SA + SR + DA` — the panel composition that was deprecated on 2026-04-03 when ADR-007 was amended to replace security-reviewer with delivery-reviewer at plan/STANDARD. The production `/speckit.review` command uses `SA + DR + DA` as of commit `79ba36b`. This run reflects historical behavior of the deprecated panel, not current production behavior. See `2026-04-03-plan-STANDARD-run2.md` for the current validated composition.

---

## Review Synthesis Report — plan gate / STANDARD / 2026-04-04

### Overall Recommendation: REWORK REQUIRED

The plan cannot proceed to tasks. Two independently confirmed CRITICAL defects exist: a nullable boolean tri-state contract that irreversibly corrupts data through normal client behavior, and a rate limiter misconfiguration that protects the wrong endpoint. The DA's structural reframe — that the plan is a schema document without behavioral specification — was partially adopted by both SA and SR. Four required sections (failure modes, state transition model, vocabulary governance ADR, scope declaration for consumption path) are absent. These cannot be patched in tasks; they must be resolved in the plan.

CONDITIONAL APPROVE was rejected. The nullable boolean finding describes a state machine defect in which a legal client operation destroys information irreversibly. Until the plan chooses a resolution, any tasks written against the current data model are written against a broken contract.

---

### Priority Findings (must resolve before implementation)

| ID | Severity | Finding | Source | Resolution Required |
|----|----------|---------|--------|---------------------|
| P-1 | CRITICAL | Nullable boolean tri-state collapses irreversibly on GET-then-PUT cycle. NULL (platform default) becomes false on any round-trip. Normal client behavior destroys information. | DA (escalated in B), SA accepted | Choose one resolution: (a) ENUM('opted_in','opted_out','platform_default'), (b) absent-row-as-default, or (c) strict NULL-never-surfaced contract. Decision requires its own ADR. |
| P-2 | CRITICAL (severity disputed — see Preserved Dissent) | Rate limiter wired to GET not PUT. Write endpoint unprotected. | All three agents | Correct wiring to PUT; add middleware matrix (endpoint × middleware × expected behavior) so error class cannot recur |
| P-3 | HIGH | Notifications service consumption path neither in scope nor out of scope. Ambiguity is the defect — pipeline must call new API but no design exists. | DA, SA | Plan must declare: consumption path in scope or out of scope. If out, document integration contract gap with named owner |
| P-4 | HIGH | Cache invalidation strategy absent. Spec requires "changes take effect within one session refresh" but no invalidation mechanism exists for notifications service preference lookup. | DA | Specify invalidation strategy or narrow spec requirement with documented exception |
| P-5 | HIGH (severity disputed) | PUT request body has no maximum cardinality constraint. Unbounded array is write-amplification vector; also creates unbounded row-per-user scenario. | SR (B), DA (B) | Specify max array size at API layer; enforce in data model |
| P-6 | HIGH | No specification of how user_id binds from session token. IDOR risk if binding is absent or caller-supplied. | SR | Define session-to-user-id binding contract explicitly — this is a security-critical design decision, not an implementation detail |
| P-7 | HIGH | Unsubscribe token security design entirely absent: generation, storage, expiry, one-time vs. persistent model, and endpoint all unspecified. | SR | Specify full token lifecycle; persistence model (one-time vs. persistent) must be resolved before implementation |

---

### Standard Findings (should resolve before implementation)

| ID | Severity | Finding | Source | Resolution Required |
|----|----------|---------|--------|---------------------|
| S-1 | HIGH | event_type has no server-side vocabulary governance. SA's CHECK constraint recommendation withdrawn in Phase B — real gap is: who owns vocabulary, what is the addition process, does schema constraint create deployment coupling? | SA, SR, DA | Add vocabulary governance ADR. Resolve CHECK vs. registry vs. enum strategy based on release process ownership. |
| S-2 | MEDIUM | PUT response schema absent — unclear whether response returns only submitted types or full preference set | SA | Define response schema in API contract section |
| S-3 | MEDIUM | Extensibility claim ("add nullable column for third channel") is false — column-per-channel requires schema migration per addition | SA | Remove or correct; document as known constraint with migration runbook reference |
| S-4 | MEDIUM | Surrogate id column unjustified; natural key is (user_id, event_type) | SA | Justify or remove |
| S-5 | MEDIUM | Redis fail-open not documented as security and operational tradeoff | SR | State fail-open/fail-closed decision; document as accepted tradeoff |
| S-6 | MEDIUM | GDPR OQ-1 deferred without named owner, target date, or placeholder integration point | SR, DA | Assign named owner and target date; add placeholder even if implementation deferred |
| S-7 | MEDIUM | Redis is shared with session service; operational coupling unspecified | SA, DA | Specify failure mode and whether namespace isolation or separate instance required |
| S-8 | MEDIUM | Missing ADR for Redis dependency decision | SA | Create ADR before tasks finalized |
| S-9 | MEDIUM | TDD compliance unverified — if test structure is post-implementation, plan violates project constitution | DA (new in B) | Confirm test structure specifies test-first task sequencing |

---

### Low-Signal / Low-Priority Findings

| ID | Severity | Finding | Disposition |
|----|----------|---------|-------------|
| L-1 | LOW | Notifications service integration contract gap (empty result vs. explicit rows) | Resolves with P-3 scope declaration |
| L-2 | LOW | Data classification not stated for preference records | One-line note in data model |
| L-3 | LOW | Nullable column ADR folded into ADR-015 rather than its own record | Resolves if P-1 produces its own ADR |
| L-4 | LOW | "Preference persistence — 100% no reset on login" unfalsifiable at QA regression | Rewrite as falsifiable acceptance criterion in spec |

---

### Overlap Clusters

| Finding Topic | Agents | Overlap Type | Verdict |
|---|---|---|---|
| Rate limiter on wrong verb | SA, SR, DA | Same framing | Redundant — P-2 absorbs all; severity dispute preserved in dissent |
| Nullable boolean tri-state | SA, DA | Same framing (escalated in B) | CRITICAL confirmed — P-1 absorbs both |
| event_type vocabulary governance | SA (HIGH), SR (MEDIUM), DA (MEDIUM) | Different angle | Keep all — SA: schema constraint; SR: allowlist source; DA: governance model. All required for resolution |
| GDPR OQ-1 deferral | SR, DA | Partial match | MEDIUM confirmed — S-6 absorbs both; DA escalated from LOW in B |
| Redis failure mode | SA, SR, DA | Different angle | Keep all — SA: missing ADR; SR: fail-open not documented; DA: shared instance coupling |
| Unsubscribe token absent | SA (LOW), SR (HIGH) | Partial match | SR's HIGH accepted — P-7; SA noted absence; SR provided security framing |
| PUT array cardinality | SR (B), DA (B) | Full overlap in Phase B | HIGH confirmed — P-5; SA did not raise independently but did not dispute |

---

### Preserved Dissent

**SR on rate limiter severity (P-2):** SR held HIGH and rejected DA's CRITICAL escalation. Position: CRITICAL implies immediate production risk, which does not apply to an unshipped plan; middleware matrix is the correct remedy. Judge accepts CRITICAL because the plan as written would cause tasks to be implemented with the wrong verb, and the error class would survive into implementation without a structural remedy.

**SR on PUT array size (P-5):** SR held MEDIUM, rejecting DA escalation to HIGH. Position: this is an availability concern, not a confidentiality/integrity concern. Judge accepts HIGH because write-amplification is a structural data model concern beyond availability. SR's classification preserved: not a confidentiality finding.

**DA on structural reframe:** DA characterized the plan as "a schema document masquerading as a technical plan" requiring a full second-pass behavioral specification. SR partially adopted but argued for targeted additions only. Judge finds the partial adoption sufficient: four specific sections (state transition model, failure modes, vocabulary governance ADR, consumption path scope declaration) constitute the substance of the reframe without requiring a full document rewrite.

---

### Unresolved Items

1. **Consumption path scope** — Requires plan author decision before resubmission.
2. **Tri-state resolution model** — Three options remain; plan author must choose one; choice drives schema, API contract, and client behavior.
3. **TDD compliance** — Requires constitution check; flagged for plan author.
4. **GDPR OQ-1 owner** — Deferral acceptable; deferral without a named owner is not.

---

### Synthesis Notes

**STANDARD panel coverage gaps**: Delivery-reviewer absent — TDD compliance finding (S-9) was surfaced by DA only in Phase B. Operational-reviewer absent — Redis operational coupling raised by DA and SA without specialist SRE depth.

**What STANDARD covered well**: All three agents independently converged on both CRITICAL defects. The DA's Phase B structural reframe was validated by SA (fully) and SR (partially). The vocabulary governance finding produced a better outcome (governance ADR) than any single agent's original framing (SA's withdrawn CHECK constraint). Phase B anti-convergence protocol functioned as intended.

---

## Panel Efficiency Report

**Mode**: Benchmark
**Panel**: systems-architect, security-reviewer, devils-advocate, synthesis-judge
**Gate**: plan
**Rigor**: STANDARD
**Run**: 2026-04-04 run 1
**Contamination**: CLEAN

### Unique Contribution by Agent

| Agent | Unique Findings | Shared Findings | Unique Rate |
|-------|----------------|-----------------|-------------|
| systems-architect | 4 | 5 | 44% |
| security-reviewer | 4 | 4 | 50% |
| devils-advocate | 5 | 5 | 50% |

### Overlap Clusters

| Finding Topic | Agents | Overlap Type | Verdict |
|---|---|---|---|
| Rate limiter on GET not PUT | SA, SR, DA | Same framing | Redundant — P-2 absorbs all |
| Nullable boolean tri-state | SA, DA | Same framing | Redundant — P-1 absorbs both |
| event_type governance | SA, SR, DA | Different angle | Keep all |
| GDPR OQ-1 deferral | SR, DA | Partial match | Keep both |
| Redis failure mode | SA, SR, DA | Different angle | Keep all |
| Unsubscribe token absent | SA, SR | Partial match | Keep both |

### False Positive Rate *(benchmark mode only)*

No false positives raised. SA explicitly cited ADR-015 when discussing the nullable column pattern ("the plan acknowledges this risk and cites ADR-015"), demonstrating correct awareness of the existing documentation. DA's LOW finding about ADR-015 scope includes explicit hedging ("rather than having its own record") and acknowledges ADR-015 exists — does not qualify as a false positive per FR-006.

### Miss Rate *(benchmark mode only)*

| Planted Issue | Severity | Expected Agent | Caught By | Result |
|---|---|---|---|---|
| ARCH-1 | HIGH | systems-architect | systems-architect | Caught |
| ARCH-2 | MEDIUM | systems-architect | systems-architect | Caught |
| SEC-2 | CRITICAL | security-reviewer | security-reviewer | Caught |
| FALSE-2 | — | (none) | (none triggered) | Pass |

*(4 of 12 total planted issues applicable at plan gate)*

**ARCH-1 scoring note**: SA explicitly stated "extensibility claim is false — column-per-channel doesn't scale, each addition requires schema migration." Direct match to the planted issue's core concern.

**ARCH-2 scoring note**: SA flagged "Missing ADR for Redis dependency decision." Stack table omission not called out explicitly but the core problem area (undocumented Redis dependency requiring ADR) is fully addressed.

**SEC-2 scoring note**: SR-1 (HIGH) explicitly states: "Rate limiting applied to GET... The write endpoint PUT is the correct target... The stated rationale confirms the intent is to throttle writes, making this a direct contradiction." Direct match.

### Limitations

Scoring requires semantic judgment — "describes the core problem area" is not a binary criterion. Absolute detection rates have an unknown error margin. Only **deltas between runs scored by the same Claude model version using the same FR-006 rule text** are reliably interpretable. If model versions differ across runs being compared, deltas may reflect scorer variance rather than panel quality differences.

STANDARD panel notably lacks delivery-reviewer and operational-reviewer coverage. TDD compliance finding (S-9) was surfaced only by DA in Phase B — a delivery-reviewer would likely have caught this in Phase A.
