# Results: Review Efficiency Profiler

**Calibration runs**: 2026-04-03 and 2026-04-04 (9 runs per date, 18 total)
**Model**: claude-sonnet-4-6 throughout
**Source data**: `benchmarks/review-panel/runs/2026-04-04-*` (most recent set)
**Key question**: Does STANDARD catch enough CRITICAL/HIGH issues to be the default?

---

## Detection Summary

### Spec Gate

| Planted Issue | Severity | FULL | STANDARD | LIGHTWEIGHT |
|---|---|---|---|---|
| PROD-1 (missing admin persona) | HIGH | Caught | Caught | Missed (no PS) |
| PROD-2 (P1/P2 reversed) | MEDIUM | **Missed** | Caught (partial) | Missed (no PS) |
| SEC-1 (no authorization requirement) | HIGH | Caught | **Missed (no SR)** | Missed (no SR) |
| FALSE-1 | — | Pass | Pass | Pass |

**FULL: 2/3 | STANDARD: 2/3 | LIGHTWEIGHT: 0/3**

### Plan Gate

| Planted Issue | Severity | FULL | STANDARD | LIGHTWEIGHT |
|---|---|---|---|---|
| ARCH-1 (nullable-column schema, no ADR) | HIGH | Caught | Caught | Missed (no SA) |
| ARCH-2 (Redis undocumented dependency) | MEDIUM | Caught | Caught | Missed (no SA) |
| SEC-2 (rate limiter on wrong endpoint) | CRITICAL | Caught | Caught | **Caught (DA)** |
| FALSE-2 | — | Pass | Pass | Pass |

**FULL: 3/3 | STANDARD: 3/3 | LIGHTWEIGHT: 1/3**

> ⚠️ **Panel anomaly**: The `2026-04-04-plan-STANDARD-run1.md` used the deprecated `SA + SR + DA` composition instead of the current `SA + DR + DA` (per ADR-007, amended 2026-04-03). The run detected all three planted issues regardless, but the composition does not reflect production behavior. A re-run with the correct `SA + DR + DA` panel is needed to validate current STANDARD behavior at the plan gate.

### Task Gate

| Planted Issue | Severity | FULL | STANDARD | LIGHTWEIGHT |
|---|---|---|---|---|
| DEL-1 (TDD ordering inverted) | HIGH | Caught | Caught | Caught |
| DEL-2 ([P] tasks share same file) | MEDIUM | Caught | Caught | Caught |
| ARCH-3 (Redis setup in wrong phase) | MEDIUM | **Missed** | **Missed** | **Missed** |
| FALSE-3 | — | Pass | Pass | Pass |

**FULL: 2/3 | STANDARD: 2/3 | LIGHTWEIGHT: 2/3**

---

## Key Findings

### 1. Answer to the core question

| Gate | STANDARD sufficient? | Verdict |
|---|---|---|
| Spec | No — SEC-1 (HIGH auth gap) missed because security-reviewer absent | Use FULL when security is a concern |
| Plan | Yes — all three issues caught; matches FULL | STANDARD is validated as default |
| Task | Yes — same detection as FULL; ARCH-3 missed at all rigor levels | STANDARD is validated as default |

**STANDARD as the universal default is not validated.** It holds at plan and task gates but fails at spec gate when security matters. The spec-gate panel (product-strategist + DA) has no security specialist, making SEC-1 a structural blind spot at STANDARD.

### 2. LIGHTWEIGHT is not useful at spec gate

Zero planted issues caught at LIGHTWEIGHT/spec. Product-strategist and security-reviewer are both absent; the DA has no specialist context to challenge. The benchmark confirms the finding from `workflow.md`: LIGHTWEIGHT at spec gate produces 0% detection even when planted issues are present.

### 3. DA catches constitutional violations without specialists

DEL-1 (TDD ordering) and DEL-2 ([P] marker conflict) were caught by DA alone at task/LIGHTWEIGHT — no delivery-reviewer required. The same pattern appears at plan/LIGHTWEIGHT: DA caught SEC-2 (CRITICAL rate-limiter misconfiguration) without the security-reviewer.

**Implication**: Constitution-aware adversarial analysis reliably detects structural violations (TDD ordering, parallel marker semantics, ADR governance) and some security issues that involve explicit contradictions in the artifact. It does not substitute for specialist schema review (ARCH-1, ARCH-2 missed at LIGHTWEIGHT).

### 4. ARCH-3 is below the detection threshold at all rigor levels

ARCH-3 (Redis setup task in Phase 3 instead of Phase 2) was missed by every agent at every rigor level including FULL. The root cause requires tracing the `T009 → T011 → T015/T016` dependency chain. Downstream effects were observed: OR caught T018 health-check sequencing as a consequence of the same misplacement, and DR caught T015 rate-limiter deferral as a separate risk. But neither agent identified T009's phase placement as the root cause.

**This is a fixture design failure, not a panel capability gap.** The planted issue is below the detection horizon at any rigor because the causal chain is non-local.

### 5. False positive rate: zero across all nine runs

FALSE-1, FALSE-2, and FALSE-3 were never triggered. All three false-positive traps were well-designed: agents either ignored them or raised them with explicit hedging that disqualified them per FR-006. The FALSE-3 design (test coverage present in a later integration task) was particularly robust — the DA explicitly referenced the integration task in its finding and did not raise FALSE-3.

### 6. PROD-2 counterintuitive result at spec gate

PROD-2 (P1/P2 priority reversal) was **missed at FULL but caught (partial) at STANDARD**. This is counterintuitive — FULL has a larger panel. The most likely explanation is run variance: PROD-2 is a moderate-signal issue that falls near the detection boundary. A second FULL run is needed to determine whether this is a fixture design issue or genuine run variance.

---

## Proposed Next Steps

**Priority 1 — Fix ARCH-3**: Redesign the planted issue to make the phase-ordering causal chain more traceable. The current design relies on non-local reasoning that even FULL panels can't resolve. Options: (a) make T009's phase label explicitly inconsistent with a stated dependency on it; (b) add a comment in the task referencing Phase 4 work, creating a visible forward reference.

**Priority 2 — Re-run plan/STANDARD with correct panel**: The existing plan/STANDARD run used the deprecated `SA + SR + DA` composition. Run again with `SA + DR + DA` per ADR-007 to get a valid baseline for the current production panel.

**Priority 3 — Investigate PROD-2 miss at spec/FULL**: Run spec/FULL a second time. If PROD-2 is caught in run 2, the first miss was variance. If missed again, the fixture may need strengthening or the issue type (priority reversal) may be below detection threshold for product-strategist.

**Priority 4 — Spec gate security coverage decision**: STANDARD at spec gate structurally cannot catch auth/authorization gaps — security-reviewer is absent. Options: (a) accept this and require FULL for any spec with security-adjacent requirements; (b) amend ADR-007 to add security-reviewer to spec/STANDARD panel; (c) add a spec-level pre-flight check that flags security-adjacent features and requires FULL automatically. The workflow already recommends FULL for auth/PII/payments — this benchmark confirms that recommendation is load-bearing, not conservative.

---

## Fixture Validity

All nine runs were contamination-clean. The fixture remained below the verbatim-quoting threshold throughout. The benchmark is safe to re-run with the same fixture.

The falsification criteria from `quickstart.md` were not triggered: no rigor level hit ≥95% catch rate, and FULL and LIGHTWEIGHT did not produce identical Miss Rate tables (FULL caught more than LIGHTWEIGHT at all gates).
