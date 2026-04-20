# ADR-051: Constitution Front-Matter as Memory Opt-In Gate

**Date**: 2026-04-17
**Status**: Accepted
**Decision Made In**: specs/008-auto-sync-staleness/plan.md § Phase 0 Research
**Related Logs**: LOG-049

---

## Context

Speckit skills call `memory_recall` and `memory_store` by convention (memory-convention.md). The convention previously relied on best-effort error-skipping (added as LOG-049 immediate mitigation) to handle the case where the memory server is absent. This is implicit — there is no way for a developer to signal "this project does not use the memory server" without the server simply not being registered and the error being silently swallowed.

This creates an invisible coupling: a new project cloned from the speckit template must either install and run the memory server or accept silent skip behavior with no explicit opt-out. Neither is a clean developer experience.

## Decision

Add a `memory_enabled` boolean field to the constitution front-matter. When `false`, speckit skills skip all `memory_recall` and `memory_store` calls entirely — no server interaction, no error handling, no silent failures. The gate is enforced at the skill layer (convention in memory-convention.md), not in the server. Default is `true` for backward compatibility.

## Alternatives Considered

### Option A: Constitution front-matter field *(chosen)*

Add `memory_enabled: true/false` to the YAML front-matter of `constitution.md`. Skills read the field before invoking memory tools. The constitution is already read by skills at the start of execution; this is a minor extension.

**Pros**: Explicit, visible, version-controlled; reuses existing constitution read step; simple to implement; co-located with other project governance decisions
**Cons**: Requires skills to parse YAML front-matter (already done by `_strip_frontmatter()` helper); adds one more field to maintain in the constitution

### Option B: Server-side gate

Server reads the constitution and refuses tool calls when `memory_enabled: false`.

**Pros**: Enforced regardless of which caller invokes the tools
**Cons**: Violates the spec requirement that direct MCP tool calls always pass through; couples server to constitution file location; adds server startup dependency on constitution parsing. Rejected.

### Option C: Separate `.speckit-config.yml` config file

New configuration file with `memory_enabled` and other settings.

**Pros**: Clean separation of concerns
**Cons**: Adds a new artifact type to maintain; the constitution already serves as the project governance document — a separate config file for one boolean is over-engineering. Rejected.

### Option D: Rely on existing best-effort skip (status quo post-LOG-049)

Skills already skip silently when memory tools are absent or error. No explicit gate needed.

**Pros**: Zero new code
**Cons**: Provides no developer control; installs without the server must register the server to get the "right" silent skip rather than an error; not an explicit opt-out. Insufficient.

## Rationale

The gate must be explicit (visible in version control, self-documenting) and must not affect the server's behavior for direct callers. Option A satisfies both constraints with the least new surface area. The constitution is the right home for this because it governs how skills behave in the project — memory enablement is a project-level governance decision, not a per-call parameter.

## Consequences

**Positive**: Memory server becomes genuinely optional for projects that don't need it; the coupling documented in LOG-049 is resolved explicitly rather than implicitly
**Negative / Trade-offs**: Skills must check the constitution before invoking memory tools — adds one read step per skill invocation (but the constitution is already read; this is a field check, not an additional file read)
**Risks**: Skills that don't implement the check will still invoke memory tools when `memory_enabled: false`. Mitigation: update all skills in scope (speckit.plan, speckit.review, speckit.audit) and document the requirement in memory-convention.md
**Follow-on decisions required**: None

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-17 | Initial record | speckit.plan |
