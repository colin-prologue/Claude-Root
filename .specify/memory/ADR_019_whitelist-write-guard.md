# ADR-019: Whitelist Write Guard for `memory_store`

**Date**: 2026-04-09
**Status**: Accepted
**Decision Made In**: specs/003-memory-server-hardening/spec.md — specification review
**Related Logs**: LOG-018 (index cleanup deferred), LOG-020 (filter_source_file gap)

---

## Context

Feature 003 adds mutation protection to the memory server to prevent agent tool calls from corrupting index representations of real source files (ADRs, LOGs, specs). The question was how to implement the write guard in `memory_store`: check whether the provided `source_file` path exists on the local filesystem (existence check), or reject all values except `"synthetic"` (whitelist).

The memory-convention.md already mandates that all agent-generated content use `source_file: "synthetic"`. No documented caller uses any other value in `memory_store`.

## Decision

We will use a whitelist approach: `memory_store` rejects any `source_file` value other than `"synthetic"`. Only `"synthetic"` is accepted; all other values are rejected regardless of whether they exist on disk.

## Alternatives Considered

### Option A: Whitelist (`source_file="synthetic"` only) *(chosen)*

Reject any `source_file` that is not exactly `"synthetic"`.

**Pros**: Simple. Unbypassable — no path normalization edge cases. Enforces the convention already stated in memory-convention.md. No ambiguous middle category.
**Cons**: Less flexible — blocks any future use case where `memory_store` might accept a non-"synthetic" non-filesystem path. That use case is currently undocumented and unneeded.

### Option B: Filesystem existence check

Reject writes where the provided `source_file` path exists on the local filesystem; allow non-existent paths.

**Pros**: More flexible — allows arbitrary non-filesystem source_file values.
**Cons**: Bypassable with path variants (`..`, relative paths, symlinks). Creates an ambiguous "non-existent path" category that becomes a collision vector after the next `memory_sync` run. Requires path normalization to be reliable, which was explicitly scoped out.

## Rationale

No legitimate caller uses a non-"synthetic" source_file value in `memory_store`. Allowing non-existent paths serves a hypothetical future use case (Principle II violation) while actively creating a bypass vector: a skill that passes a slightly wrong path (e.g., a future path that doesn't exist yet) would succeed the guard but create a chunk that collides with a real file after the next sync. The whitelist eliminates this class of problem with simpler code.

## Consequences

**Positive**: Guard is trivially testable and correct. No path normalization required. Convention-enforcement and implementation are aligned.
**Negative / Trade-offs**: If a future use case requires non-synthetic non-filesystem source_file values in `memory_store`, this ADR must be revisited.
**Risks**: Low. The only risk is blocking a future use case that is currently undocumented.
**Follow-on decisions required**: None.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-09 | Initial record | spec review panel |
