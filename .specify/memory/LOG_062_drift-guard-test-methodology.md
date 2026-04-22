# LOG-062: Drift-Guard Test Methodology — Codify Expected-Set Pattern

**Date**: 2026-04-22
**Type**: QUESTION
**Status**: Open
**Raised In**: /speckit.codereview on branch `skill-plugin-optimization` (synthesis S-3, 2026-04-22)
**Related ADRs**: ADR-055 (shared filter predicate)

---

## Description

ADR-055's drift-guard test (`memory-server/tests/unit/test_filter_predicate.py`)
originally asserted `python_ids == sql_ids` — set equality between two derived
paths. The code review surfaced a blind spot: a regression that breaks *both*
paths identically (e.g., both silently drop a filter field, both return all
rows) satisfies the agreement check. The fix was to add an explicit
`expected_ids` per spec and assert `python_ids == expected_ids == sql_ids`.

The open question: is this the pattern for all future cross-path invariants?
If another feature adds a second pair of code paths that must agree (e.g., a
client-side + server-side validator, a CLI flag parser + config-file parser),
the test should use the expected-set pattern by default rather than rediscover
the blind spot.

## Context

The agreement-only test passed the original ADR-055 review; the gap was only
caught under adversarial cross-examination during /speckit.codereview. That
suggests the pattern is non-obvious enough to be worth codifying as a
convention rather than relying on per-feature critique.

## Discussion

### Pass 1 — Initial Analysis

Options:
1. Add a short note to `.claude/rules/conventions.md` under a "drift-guard
   tests" heading: "When testing that two code paths agree on a contract,
   assert each against an explicit expected set rather than only against each
   other."
2. Create a test helper (e.g., `assert_drift_guard(path_a, path_b, expected)`)
   that enforces the three-way assertion.
3. Leave as precedent — ADR-055's test is the canonical example; future authors
   can follow it by reference.

### Pass 2 — Critical Review

Option 1 is the cheapest durable artifact. Option 2 is premature without a
second drift-guard test to motivate it. Option 3 relies on every future author
noticing the precedent, which is exactly what failed the first time.

## Resolution

Deferred. Will upgrade to Option 1 the next time a cross-path invariant is
added (second instance → codify). For now the ADR-055 test is the sole
example; the hardened `expected_ids` pattern is visible there.

**Resolved By**: deferred
**Resolved Date**: N/A

## Impact

- [ ] Code updated: N/A
- [ ] Spec updated: N/A
- [ ] ADR created/updated: none required
- [ ] Convention updated: deferred — `.claude/rules/conventions.md`
