# Benchmark Run: plan / FULL / 2026-04-04 run 1

**Panel**: systems-architect, security-reviewer, delivery-reviewer, operational-reviewer, devils-advocate, synthesis-judge
**Contamination**: CLEAN
**Model**: claude-sonnet-4-6

---

## Review Synthesis Report — plan gate / FULL / 2026-04-04

### Overall Recommendation: REWORK REQUIRED

The plan contains two independently blocking gaps that cannot be resolved by conditions alone: the unsubscribe token is a complete sub-feature (spanning 4 architectural layers) entirely absent from the plan, and the Redis ADR omission is a governance violation per project convention. The DA's meta-reframe proved correct — the plan scope boundary was drawn incorrectly. A conditional approval would defer structural scope decisions into implementation, which is what the plan gate is designed to prevent. The plan can resubmit for conditional approval once scope is corrected and the two blocking gaps are addressed.

---

### Approval Conditions (upon resubmission)

1. **Scope boundary decision**: Declare whether unsubscribe token and notifications-service integration contract are in or out of scope. If out, document as explicit exclusions with follow-on spec references. If in, they must be planned.
2. **Redis ADR**: Write ADR covering storage decision, Redis introduction, namespace isolation, TLS/credentials, and cross-reference to session-service sharing.
3. **Rate limiter corrected**: Move rate limiter to PUT endpoint. Document threat model rationale for placement and 30/minute threshold.
4. **Nullable boolean resolved**: Adopt ENUM (OPTED_IN/OPTED_OUT/PLATFORM_DEFAULT) or document three-state convention with explicit API behavior for reset-to-default.
5. **GDPR/right-to-erasure**: Specify ON DELETE CASCADE or equivalent retention policy before schema finalization.
6. **p95 measurability**: Define measurement path for the p95 latency target stated in the spec.

---

### Priority Findings (must resolve before implementation)

| ID | Severity | Finding | Source | Resolution Required |
|----|----------|---------|--------|---------------------|
| PF-01 | BLOCKING | Unsubscribe token lifecycle (generation, storage, validation, expiry, endpoint) entirely absent. Spec US2 AC4 cannot be implemented from this plan. | SR, SA, DA, DR | Scope declaration required: either design the token subsystem or explicitly defer with a follow-on spec reference |
| PF-02 | BLOCKING | Redis introduced without ADR — governance violation per project convention. Shared with session service; namespace isolation, TLS, and credentials unspecified. | SA, DR, SR, OR, DA | Write Redis ADR before implementation begins |
| PF-03 | CRITICAL | Rate limiter wired to GET not PUT. Stated rationale ("preference-update spam") contradicts implementation. No threat model for placement or threshold derivation. | All five agents | Correct wiring to PUT; document threat model rationale |
| PF-04 | CRITICAL | Three-state logic (opted-in/opted-out/platform-default) packed into nullable boolean with no API reset mechanism (one-way ratchet). ENUM is strictly superior. | SA, DA | Decide between nullable boolean + app enforcement vs. ENUM; if nullable kept, document in ADR; add reset mechanism to API |
| PF-05 | HIGH | No ON DELETE CASCADE on FK to users table. Preference records orphaned on account deletion — GDPR Article 17 violation. No data classification, lawful basis, or retention policy in plan. | SR, SA | Specify cascade delete or documented retention/anonymization policy before schema finalization |
| PF-06 | HIGH | "Preference lookup is additive / pipelines must not be modified" constraint irreconcilable with pipelines that must call the new API. Synchronous vs. asynchronous lookup decision not made. Synchronous coupling means preference-service degradation stops all notifications. | DA, SA, DR | Explicit architecture decision: synchronous + circuit breaker, or async with cache + invalidation strategy |
| PF-07 | HIGH | Spec states p95 latency target with no measurement path in plan. Target is unfalsifiable as written — cannot validate at any gate. | OR, DR | Define instrumentation approach (APM, request logging, synthetic probes) and alerting threshold |

---

### Standard Findings (should resolve before implementation)

| ID | Severity | Finding | Source | Resolution Required |
|----|----------|---------|--------|---------------------|
| SF-01 | HIGH | No statement that user_id is always derived from session token. If accepted from request body, IDOR attack is possible. | SR | Explicit plan statement: user_id sourced from req.user only, never client-supplied |
| SF-02 | HIGH | event_type has no allowlist source specified. Preferences array has no maximum length — single PUT can attempt thousands of upserts, bypassing per-item rate limiting. | SR, SA | Specify allowlist strategy (hardcoded enum vs. registry query); cap array length to number of known event types |
| SF-03 | HIGH | No ADR covering decision to store preferences in shared PostgreSQL vs. delegating to notifications-service-owned store. Service-boundary decision with no documentation. | SA | Write ADR for storage placement decision |
| SF-04 | HIGH | No server-side error logging specified. PREFERENCE_SAVE_FAILED produces no observable signal. DB connection timeout, query timeout, and behavior on DB down unspecified. | OR, SA, DR | Specify logging library, log levels, and DB connection pool timeout in plan |
| SF-05 | HIGH | Shared Redis with session service means preference-service rate-limit spike can starve session lookups. No namespace or connection quota isolation documented. | OR, DA, SR | Document namespace isolation (e.g., key prefix), connection pool limits, or confirm separate logical DB |
| SF-06 | HIGH | No rollback posture documented for Phase 1 migration. No down-migration file and no runbook entry. A rollback runbook (not a destructive DROP TABLE) is the correct fix. | DR, OR | Document rollback posture: revert application binary, leave table in place, compensating migration if needed |
| SF-07 | HIGH | TDD task ordering compliance unverified. If implementation tasks precede test tasks in the phase sequence, the plan violates the project constitution's test-first requirement. | DA, DR, OR | Audit task ordering before tasks.md is authored; test tasks must have lower IDs than their corresponding implementation tasks |
| SF-08 | MEDIUM | PUT response contract undefined — unclear whether response returns only submitted event types or full preference set. | SA | Specify in API Design section |
| SF-09 | MEDIUM | No created_at column on preference rows — required for GDPR audit trail (OQ-1). | SA | Add created_at to migration DDL |
| SF-10 | MEDIUM | How the notifications service performs preference lookup at dispatch time is entirely unaddressed. Coupling model (sync/async) and failure behavior undefined. | SA, DR, DA | Document lookup integration contract (see PF-06) |
| SF-11 | MEDIUM | PUT partial-batch idempotency undefined — behavior when some event_types succeed and others fail is unspecified. | SA | Define partial-failure behavior in API Design |
| SF-12 | MEDIUM | Plan does not confirm parameterized queries throughout repository layer. event_type not validated against header injection. | SR | Explicit statement in plan; confirm in code review |
| SF-13 | MEDIUM | Redis fail-open is correct policy but not documented as a conscious security tradeoff. | SR, DA | Name and document the accepted risk in ADR or risk table |
| SF-14 | MEDIUM | "Add a nullable column for future channels" extensibility claim ignores API, TypeScript types, service logic, and pipeline updates — claim is misleading. | SA, DA | Correct or remove the extensibility claim; note actual migration scope |

---

### Low-Signal / Low-Priority Findings

| ID | Severity | Finding | Disposition |
|----|----------|---------|-------------|
| LF-01 | LOW | SERIAL vs BIGSERIAL primary key | One-line note in ADR; zero migration cost to change now |
| LF-02 | LOW | No soft-delete/tombstone — cannot distinguish "preference deleted" from "no row" | Flag for future audit logging if OQ-1 is resolved |
| LF-03 | LOW | Missing Cache-Control: private on GET response | Add header to controller |
| LF-04 | LOW | 429 Too Many Requests absent from error handling table | Add entry to error table |
| LF-05 | LOW | ADR-012 versioning mechanism not described; no deprecation protocol for v1 or inter-service consumers | Confirm ADR-012 scope covers inter-service consumers |
| LF-06 | LOW | Health/readiness probe not mentioned as needing update for Redis dependency | Verify existing health check covers Redis |
| LF-07 | LOW | No env var manifest for rate limiter configuration | Add REDIS_URL, rate limit params to env var docs |
| LF-08 | LOW | Implicit UNIQUE constraint index — if constraint revised, index disappears silently | Add explicit CREATE INDEX |

---

### Overlap Clusters

| Finding Topic | Agents | Overlap Type | Verdict |
|---|---|---|---|
| Rate limiter on GET not PUT | SA, SR, DR, OR, DA | Same framing | Redundant — PF-03 absorbs all; DA's enumeration-defense caveat preserved as dissent |
| Unsubscribe token absent | SA, SR, DA, DR | Same framing | Redundant — PF-01 absorbs all; DA's scope-boundary meta-reframe preserved separately |
| Redis ADR missing (governance) | SA, DR | Same framing | Redundant — PF-02 absorbs both |
| Redis fail-open / isolation / operational risk | SA, SR, OR, DA | Different angle | Keep all — SR: security tradeoff; OR: session-service starvation; DA: compounded shared-failure-domain risk |
| GDPR / right to erasure | SR, SA | Same framing | Redundant — PF-05 absorbs both |
| Nullable boolean / reset mechanism | SA, DA | Different angle | Keep both — SA: API gap (no reset endpoint); DA: data modeling decision (ENUM); both required for resolution |
| p95 unfalsifiable | OR, DR | Same framing | Redundant — PF-07 absorbs both |
| Notifications coupling | SA, DR, DA | Different angle | Keep all — SA: missing endpoint; DR: delivery risk; DA: irreconcilable constraint |
| Rollback posture | DR, OR | Partial match | Keep both — DR: migration phase; OR: runbook; DA reframe (runbook not down-migration) is synthesis |
| TDD ordering compliance | DR, OR, DA | Same framing | Redundant — SF-07 absorbs all |
| Missing ADRs (PostgreSQL storage + Redis) | SA, DR | Partial match | Keep both as distinct ADRs (SF-03 and PF-02) |
| Observability / error logging | OR, DR | Partial match | Keep both — OR: operational alerting; SA: server-side log absence; combined into SF-04 |
| Input validation (event_type + array length) | SR, SA | Different angle | Keep both — SA: allowlist source ambiguity; SR: array-length attack vector; combined into SF-02 |

---

### Preserved Dissent

- **DA meta-reframe (partial acceptance)**: DA argued the plan is "complete for an incomplete scope" rather than a flawed plan. Synthesis accepts this as the underlying cause of PF-01 and PF-06, driving REWORK REQUIRED. However, PF-03 (rate limiter error) and PF-04 (nullable boolean) are genuine internal plan defects independent of scope — not scope accidents.
- **DA on rate limiter severity**: DA issued Phase B partial dissent suggesting the GET rate limiter might be intentional enumeration defense. Synthesis does not accept this — the plan's stated rationale is unambiguously "prevent preference-update spam," making the GET placement a direct contradiction. Severity remains CRITICAL.
- **DA on C-5 (migration rollback)**: DA challenged DR/OR's rollback finding, arguing down-migration would be destructive. The synthesis accepts the fix reframe (rollback runbook not down-migration file) but not the dismissal — the gap (no rollback posture at all) stands as SF-06.
- **OR on p95 as blocking**: OR escalated in Phase B. Synthesis promotes to PF-07 with a caveat: if the measurement path requires only an infra-level decision, this can drop from hard-blocker to a condition for conditional approval on resubmission.

---

### Unresolved Items

1. **Synchronous vs. asynchronous notifications lookup** — Explicit architecture decision required; may warrant a new ADR. Resolves at: plan revision.
2. **Unsubscribe token in-scope or out-of-scope** — Explicit scope declaration required before resubmission. Resolves at: plan revision.
3. **ENUM vs. nullable boolean** — If rows exist in staging, a data migration plan is required alongside schema change. Resolves at: plan revision.
4. **Redis deployment topology** — Standalone vs. cluster, shared vs. isolated. Resolves at: Redis ADR.
5. **p95 measurement path** — Depends on platform infra; requires infra team input. Resolves at: plan revision.

---

### Synthesis Notes

Phase A panel coverage was strong — all five agents independently identified the rate limiter inversion, and four independently identified the unsubscribe token gap. This convergence gives the synthesis high confidence in PF-03 and PF-01.

The highest-value Phase B contribution came from the DA's meta-reframe (scope boundary wrong), ENUM reframe on nullable boolean, and Redis as a governance violation rather than a documentation note. These drove the verdict from conditional approval to REWORK REQUIRED.

Plan strengths to preserve in revision: error handling table structure, phased implementation order, upsert-on-conflict idempotency, and ADR-015 rationale. Revision should extend these, not restructure.

Resubmission path: addressing PF-01 through PF-03 (scope declaration, Redis ADR, rate limiter correction) plus PF-04 (data model) should unlock conditional approval in the next cycle.

---

## Panel Efficiency Report

**Mode**: Benchmark
**Panel**: systems-architect, security-reviewer, delivery-reviewer, operational-reviewer, devils-advocate, synthesis-judge
**Gate**: plan
**Rigor**: FULL
**Run**: 2026-04-04 run 1
**Contamination**: CLEAN

### Unique Contribution by Agent

| Agent | Unique Findings | Shared Findings | Unique Rate |
|-------|----------------|-----------------|-------------|
| systems-architect | 10 | 4 | 71% |
| security-reviewer | 5 | 6 | 45% |
| delivery-reviewer | 6 | 5 | 55% |
| operational-reviewer | 4 | 4 | 50% |
| devils-advocate | 7 | 6 | 54% |

*Note: Due to context compaction at session start, systems-architect, security-reviewer, delivery-reviewer, and operational-reviewer each produced two independent Phase A outputs (from a prior session whose tasks completed at this session's start, and a fresh re-run). Phase B/C used the first-arrived outputs as the consensus basis. Scoring uses the fresh agents as the canonical Phase A set. Unique rates above reflect the fresh agent outputs.*

### Overlap Clusters

Issues raised by 2+ agents:

| Finding Topic | Agents | Overlap Type | Verdict |
|---|---|---|---|
| Rate limiter on GET not PUT | SA, SR, DR, OR, DA | Same framing | Redundant — PF-03 absorbs all |
| Unsubscribe token absent | SA, SR, DA, DR | Same framing | Redundant — PF-01 absorbs all |
| Redis ADR missing | SA, DR | Same framing | Redundant — PF-02 absorbs both |
| Redis operational risk (multi-angle) | SA, SR, OR, DA | Different angle | Keep all |
| GDPR / data retention | SR, SA | Same framing | Redundant — PF-05 absorbs both |
| Nullable boolean / reset | SA, DA | Different angle | Keep both |
| p95 unfalsifiable | OR, DR | Same framing | Redundant — PF-07 absorbs both |
| Notifications coupling | SA, DR, DA | Different angle | Keep all |
| Rollback posture | DR, OR | Partial match | Keep both |
| TDD compliance | DR, OR, DA | Same framing | Redundant — SF-07 absorbs all |
| Input validation | SR, SA | Different angle | Keep both |
| Observability / logging | OR, DR, SA | Partial match | Keep all |

### False Positive Rate *(benchmark mode only)*

No false positives raised. The operational-reviewer explicitly deflected FALSE-2 by noting the nullable column pattern was "operationally sound" and citing ADR-015 as existing documentation — correct behavior per FR-006.

### Miss Rate *(benchmark mode only)*

| Planted Issue | Severity | Expected Agent | Caught By | Result |
|---|---|---|---|---|
| ARCH-1 | HIGH | systems-architect | systems-architect | Caught |
| ARCH-2 | MEDIUM | systems-architect | systems-architect | Caught |
| SEC-2 | CRITICAL | security-reviewer | security-reviewer | Caught |
| FALSE-2 | — | (none) | (none triggered) | Pass |

*(4 of 12 total planted issues applicable at plan gate)*

**ARCH-1 scoring note**: The fresh SA run explicitly addressed "extensibility claim vs. schema reality" — noting that the nullable-column-per-channel pattern is not trivially extensible and requires schema migration per channel. Core problem area matched.

**ARCH-2 scoring note**: SA identified Redis as an undocumented runtime dependency with no ADR (multiple findings). The Stack table omission was not called out explicitly, but the core problem area (undocumented Redis dependency) was fully addressed.

**SEC-2 scoring note**: SR explicitly rated rate limiter on GET as CRITICAL, citing direct contradiction with the "preference-update spam" rationale. Direct match on artifact section and core problem area.

### Limitations

Scoring requires semantic judgment — "describes the core problem area" is not a binary criterion. Absolute detection rates have an unknown error margin. Only **deltas between runs scored by the same Claude model version using the same FR-006 rule text** are reliably interpretable. If model versions differ across runs being compared, deltas may reflect scorer variance rather than panel quality differences.

This run experienced a benchmark integrity anomaly: Phase A agents were effectively run twice (prior session outputs + fresh re-run). The duplication does not affect planted issue scoring (both runs caught all three applicable CAUGHT issues) but inflates apparent panel coverage. Future runs should verify session continuity before re-spawning Phase A agents.
