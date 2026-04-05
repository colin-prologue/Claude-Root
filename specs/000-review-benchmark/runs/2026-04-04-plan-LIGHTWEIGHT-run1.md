# Benchmark Run: plan / LIGHTWEIGHT / 2026-04-04 run 1

**Panel**: devils-advocate, synthesis-judge
**Contamination**: CLEAN
**Model**: claude-sonnet-4-6

---

## Review Synthesis Report — plan gate / LIGHTWEIGHT / 2026-04-04

### Overall Recommendation: REWORK REQUIRED

Two critical defects and two high-severity gaps were identified. The rate limiter misconfiguration (P-1) and idempotency contract breach (P-2) must be resolved before task breakdown begins. The unsubscribe token gap (P-3) represents a spec-plan scope gap — a named acceptance criterion with no implementation path. After rework, a STANDARD re-review is recommended given the unsubscribe flow's security surface.

---

### Coverage Note

LIGHTWEIGHT review — devils-advocate only. Systems-architect, security-reviewer, delivery-reviewer, and operational-reviewer did not run.

| Missing Reviewer | Areas Not Examined |
|---|---|
| systems-architect | Schema design, index strategy, extensibility claims, ADR coverage, Redis dependency documentation |
| security-reviewer | Unsubscribe token forgery, IDOR on PUT endpoint, token entropy/expiry, auth enforcement |
| delivery-reviewer | Task dependency ordering, test coverage, migration safety, rollback plan |
| operational-reviewer | Cache invalidation failure modes, observability, phantom update impact on audit logs |

The CRITICAL-2 phantom update finding touches schema semantics a systems-architect would normally examine in depth. The unsubscribe token gap touches threat vectors a security-reviewer would probe. Both areas are under-examined.

Synthesis judge strongly recommends a STANDARD or FULL re-review after rework.

---

### Priority Findings (must resolve before plan phase)

| ID | Severity | Finding | Source | Resolution Required |
|----|----------|---------|--------|---------------------|
| P-1 | CRITICAL | Rate limiter wired to GET in Phase 4 step 10. Stated purpose is preventing "rapid toggle spam" (write operations). PUT endpoint left unprotected — write loop is trivially exploitable. | Phase A | Re-wire rate limiter to PUT. Remove or justify GET-side limiting separately. |
| P-2 | CRITICAL | Idempotency contract breach: spec requires re-saving same value to be a no-op. Plan's ON CONFLICT DO UPDATE always writes and advances updated_at — phantom updates corrupt change-detection consumers (cache invalidation, audit logs). | Phase A | Add guard condition: only execute UPDATE if at least one column value differs. Or use read-then-conditional-write. |
| P-3 | HIGH | Unsubscribe token gap: spec US2 AC requires per-event-type unsubscribe link. Plan contains zero mention of token issuance, validation, storage, or endpoint. P2 acceptance criterion has no implementation path. | Phase A | Add plan section covering token issuance, schema, validation endpoint, ownership, and expiry. |
| P-4 | HIGH | Nullable boolean inconsistency: GET response contract shows explicit true/false with no nulls. Service resolves DB NULLs before returning, discarding "user explicitly set vs. platform default" distinction. API contract inconsistent with column semantics. | Phase A | Decide: expose three-state in contract, or materialize defaults at write time. Document the decision. |

---

### Standard Findings (should resolve before implementation)

| ID | Severity | Finding | Source | Resolution Required |
|----|----------|---------|--------|---------------------|
| S-1 | MEDIUM | 429 Too Many Requests absent from error handling table. Frontend has no contract for rate-limit-exceeded responses. | Phase A | Add 429 to error table with retry-after semantics |

---

### Low-Signal / Low-Priority Findings

None surfaced. Single-reviewer panel produced only actionable findings.

---

### Overlap Clusters

Single reviewer only. Internal Phase A coherence note: P-2 (idempotency breach) and P-4 (nullable boolean) both stem from the same root tension — implicit data semantic choices (upsert always writes; NULLs resolved to booleans) without explicit decisions. These should be addressed together in a single data layer revision pass.

---

### Preserved Dissent

**P-4 (nullable boolean)**: Exposing a three-state preference in the API is a legitimate design choice — some clients may want to distinguish user-set from platform-default. DA framed this as an inconsistency, but it could be an undocumented feature. A systems-architect reviewer (not in LIGHTWEIGHT panel) should rule on whether nullable semantics are intentional before the team is asked to change them.

---

### Unresolved Items

1. Is GET-side rate limiting intentional (e.g., scraping prevention) or a mistake? — Requires plan author.
2. Should upsert use guard predicate or read-then-conditional-write? — Requires systems architect review.
3. Where does unsubscribe token issuance live — notifications service, auth service, or preferences service? — Scope undefined.
4. Is the three-state nullable boolean intentional product behavior or a schema artifact? — Requires product + plan author.

---

### Synthesis Notes

Two critical defects would have caused production bugs (rate limiter misconfiguration) and data integrity issues (phantom updates). Both are plan-level errors that code review alone would not catch.

The unsubscribe token gap is a scope completeness failure: a named acceptance criterion in the spec has no corresponding plan section. The nullable boolean finding (P-4) may be too strong as framed — whether the inconsistency is a bug or undocumented design intent requires a product and architecture decision that LIGHTWEIGHT coverage cannot resolve.

Coverage gaps in this run are material. STANDARD re-review after rework is the minimum acceptable next step.

---

## Panel Efficiency Report

**Mode**: Benchmark
**Panel**: devils-advocate, synthesis-judge
**Gate**: plan
**Rigor**: LIGHTWEIGHT
**Run**: 2026-04-04 run 1
**Contamination**: CLEAN

### Unique Contribution by Agent

| Agent | Unique Findings | Shared Findings | Unique Rate |
|-------|----------------|-----------------|-------------|
| devils-advocate | 5 | 0 | 100% (single-agent; not a diversity signal) |

### Overlap Clusters

Single reviewer — no cross-agent overlap computable. Internal convergence noted: P-2 (idempotency) and P-4 (nullable boolean) are thematically linked as implicit data semantic decisions.

### False Positive Rate *(benchmark mode only)*

No false positives raised. DA did not flag the nullable column pattern as lacking ADR — findings were focused on runtime semantics, not documentation gaps.

### Miss Rate *(benchmark mode only)*

| Planted Issue | Severity | Expected Agent | Caught By | Result |
|---|---|---|---|---|
| ARCH-1 | HIGH | systems-architect | — | Missed (systems-architect not in LIGHTWEIGHT panel) |
| ARCH-2 | MEDIUM | systems-architect | — | Missed (systems-architect not in LIGHTWEIGHT panel) |
| SEC-2 | CRITICAL | security-reviewer | devils-advocate | Caught |
| FALSE-2 | — | (none) | (none triggered) | Pass |

*(4 of 12 total planted issues applicable at plan gate)*

**SEC-2 scoring note**: DA's CRITICAL finding explicitly states "Rate limiting is wired to GET... If PUT is not rate-limited, the stated protection goal is unmet." Direct match to the planted issue's core concern. DA caught SEC-2 even without the security-reviewer in the panel.

**ARCH-1/ARCH-2 miss note**: Expected misses — systems-architect was not in the LIGHTWEIGHT panel. ARCH-1 (nullable column scalability) and ARCH-2 (Redis undocumented dependency) are systems-architect territory. DA's nullable boolean finding addressed API semantics, not schema scalability.

### Limitations

Scoring requires semantic judgment — "describes the core problem area" is not a binary criterion. Absolute detection rates have an unknown error margin. Only **deltas between runs scored by the same Claude model version using the same FR-006 rule text** are reliably interpretable. If model versions differ across runs being compared, deltas may reflect scorer variance rather than panel quality differences.
