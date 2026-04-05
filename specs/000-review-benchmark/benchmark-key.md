# Benchmark Key: Review Panel Benchmark

**MAINTAINER-ONLY — Do NOT pass this file to any review agent.**
**Passing this file to Phase A agents invalidates the benchmark run (contamination).**

---

## Scoring Reference

This table defines all 12 planted issues across the three fixture artifacts. Use it only during
the scoring pass (step 7) of `/speckit.review-profile`, after Phase A, B, and C are complete.

| ID | Type | Severity | Artifact | Description | Expected Agent | Overlap Risk | Applicable Gate |
|---|---|---|---|---|---|---|---|
| PROD-1 | Missing persona | HIGH | spec.md | No user story covers admin management of other users' notification settings — only registered users managing their own preferences are represented | product-strategist | low | spec |
| PROD-2 | Priority reversal | MEDIUM | spec.md | Email preferences (US2, P2) are the foundational notification channel for all web users; push (US1, P1) is a mobile enhancement — the P1/P2 assignment is inverted relative to user reach and business impact | product-strategist | medium | spec |
| SEC-1 | Auth gap | HIGH | spec.md | The spec lists auth service as a dependency for session token validation but defines no requirement that the preference endpoint verify the authenticated user owns the preferences being modified — IDOR attack vector is unaddressed | security-reviewer | low | spec |
| FALSE-1 | False positive | — | spec.md | OQ-2 explicitly defers "pause all notifications" master toggle to feature 022-notification-history with a "Tentative: no" answer — agents flagging absence of a master toggle as a HIGH or MEDIUM concern without acknowledging OQ-2 are raising a false positive | none | — | spec |
| ARCH-1 | Schema decision | HIGH | plan.md | The `user_notification_preferences` table uses one nullable boolean column per channel (push_enabled, email_enabled) with no ADR — this pattern requires a schema migration for every new channel; the plan notes it allows adding "a new nullable column" for a 3rd channel without addressing scalability beyond that | systems-architect | medium | plan |
| ARCH-2 | Undocumented dependency | MEDIUM | plan.md | Redis is introduced as a runtime dependency for rate limiting in the Rate Limiting section but is absent from the Stack table and has no corresponding ADR — the plan only notes it is "already provisioned" as a shared instance | systems-architect | low | plan |
| SEC-2 | Rate limiting gap | CRITICAL | plan.md | The Rate Limiting section states the purpose is to prevent "preference-update spam" (a write operation), but Phase 4 step 9 of the Implementation Order wires the rate limiter to GET /api/v1/preferences/notifications — the PUT endpoint that actually accepts updates is never listed as a rate-limit target | security-reviewer | low | plan |
| FALSE-2 | False positive | — | plan.md | The Risk Assessment row "Nullable column pattern creates confusion for future engineers" cites ADR-015 as documenting the rationale — agents who flag the nullable column schema as lacking an ADR without noticing this explicit Risk Assessment reference are raising a false positive (ADR-015 is listed in the Decision Records table and referenced in the risk row) | none | — | plan |
| DEL-1 | TDD violation | HIGH | tasks.md | US2 implementation tasks appear before their test tasks by task ID: T013 (extend email service) precedes T014 (email-prefs unit tests) — TDD requires test tasks to have lower IDs than the implementation tasks they cover; the same pattern appears for T006/T007 (controller implementation) relative to T012 (controller integration tests) | delivery-reviewer | low | task |
| DEL-2 | Parallel conflict | MEDIUM | tasks.md | T018 [P] ("Update src/app.ts to add health check for Redis") and T019 [P] ("Update src/app.ts environment validation") are both marked as parallel but both write to the same file (src/app.ts) — concurrent writes create a merge conflict or data loss risk | delivery-reviewer | low | task |
| ARCH-3 | Phase ordering | MEDIUM | tasks.md | Redis setup (T009) is placed in Phase 3 (Infrastructure) rather than Phase 2 (Business Logic / foundational); T015 and T016 in Phase 4 depend on T009 and T011 for rate limiter middleware, creating a hidden cross-phase dependency that can only be traced by following the T009→T011→T015/T016 dependency chain | systems-architect | medium | task |
| FALSE-3 | False positive | — | tasks.md | T015 (wire rate limiter to PUT endpoint) appears to have no dedicated test task, but T017 (Run full test suite) two IDs later provides integration coverage — and the notes at the bottom of tasks.md explicitly state that T012 covers the controller integration test contract; agents who flag T015 as missing a test without reading T017 or the notes section are raising a false positive | none | — | task |

---

## Scoring Rules (FR-006)

**Caught**: A Phase A finding references the correct artifact section AND addresses the core problem area (not just an adjacent concern).

**Caught (partial)**: A Phase A finding references the correct artifact but frames the problem incorrectly or identifies only part of the issue.

**Missed**: No Phase A finding addresses the planted issue.

**False Positive (for FALSE-* entries)**: A Phase A finding raises the false-positive trap as a definitive HIGH or MEDIUM concern without explicit hedging (e.g., "may," "unclear if," "could be intentional," "possibly out of scope").

---

## Contamination Check (FR-003)

Before scoring, scan all Phase A findings for verbatim planted issue IDs: PROD-1, PROD-2, SEC-1, FALSE-1, ARCH-1, ARCH-2, SEC-2, FALSE-2, DEL-1, DEL-2, ARCH-3, FALSE-3.

Match full IDs only — "SEC" or "PROD" alone in a finding is not a contamination signal. If a full ID appears verbatim in any Phase A finding, output CONTAMINATION DETECTED and abort the scoring pass.

---

## Gate Filtering

Each run scores only the planted issues whose `applicable_gate` matches the gate run:
- `spec` gate: PROD-1, PROD-2, SEC-1, FALSE-1
- `plan` gate: ARCH-1, ARCH-2, SEC-2, FALSE-2
- `task` gate: DEL-1, DEL-2, ARCH-3, FALSE-3

Issues in other gates are excluded from the denominator — not counted as "Missed."
