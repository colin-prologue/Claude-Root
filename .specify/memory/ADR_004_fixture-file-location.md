# ADR-004: Synthetic Fixture File Location

**Date**: 2026-04-03
**Status**: Accepted
**Decision Made In**: specs/000-review-benchmark/plan.md § Phase 0 Research
**Related Logs**: None

---

## Context

The `specs/000-review-benchmark/` directory serves dual purpose: it holds the real Spec-Kit
planning artifacts for the Review Panel Benchmark feature (spec.md, plan.md, tasks.md) AND
must also contain the synthetic "user notification preferences" benchmark artifacts that
review agents will analyze. The 001 plan assumed the synthetic artifacts would live at the
folder root, but this creates a naming collision with the real spec-kit artifacts.

## Decision

Synthetic fixture artifacts live in `specs/000-review-benchmark/fixture/` — a subdirectory
dedicated to benchmark test data. The `benchmark-key.md` scoring instrument lives at the
000 root (one level above `fixture/`) to emphasize its separation from reviewed artifacts.

## Alternatives Considered

### Option A: Root with different names (e.g., `notif-spec.md`)

Keep files at root with domain-prefixed names to distinguish them.

**Pros**: No subdirectory; flat structure.
**Cons**: Pollutes the root with oddly named files; makes the `fixture/` intent implicit;
harder to pass paths to agents cleanly.

### Option B: `fixture/` subdirectory *(chosen)*

**Pros**: Collision-free; idiomatic for test data; agent scope is explicit (command passes
`fixture/spec.md` etc.); `benchmark-key.md` placement signals the hierarchy clearly.
**Cons**: One extra directory level.

### Option C: Separate top-level location (`specs/bench-fixture/`)

**Pros**: Maximum separation.
**Cons**: Over-separates what logically belongs to the 000 feature; harder to navigate.

## Rationale

`fixture/` is the minimal change that eliminates the collision without introducing naming
ambiguity. Agents receive explicit paths, so the subdirectory is transparent to them.
Principle II (Simplicity) favors the least structural change that solves the problem.

## Consequences

**Positive**: No naming collision; clear test data boundary.
**Negative / Trade-offs**: The 001 plan references `specs/000-review-benchmark/spec.md` etc.
as the artifact paths — all references must use `specs/000-review-benchmark/fixture/spec.md`.
**Risks**: If a command accidentally passes the wrong path (real spec.md vs fixture/spec.md),
agents review the wrong artifact. Mitigated by the clear directory separation.
**Follow-on decisions required**: None.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-03 | Initial record | speckit.plan |
