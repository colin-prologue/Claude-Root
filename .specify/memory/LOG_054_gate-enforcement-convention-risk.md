# LOG-054: Constitution gate (memory_enabled) is convention-only — no server-side enforcement

**Date**: 2026-04-18
**Type**: CHALLENGE
**Status**: Open — accepted risk with partial mitigation
**Raised In**: `specs/008-auto-sync-staleness/` — code review (speckit.codereview)
**Related ADRs**: ADR-051

---

## Description

FR-008 and ADR-051 define a `memory_enabled: false` field in the constitution front-matter that signals skills to skip all `memory_recall` and `memory_store` calls. The gate is enforced at the skill layer (convention in `memory-convention.md`) — the server itself does not inspect the constitution or refuse tool calls. A skill that forgets to implement the gate check will invoke memory tools regardless of the constitution setting.

## Risk

Any new skill, or any existing skill updated without the gate check, silently re-introduces the LOG-049 coupling that this feature was designed to eliminate. The coupling manifests as:
- Error-swallowing when the server is absent (best-effort fallback)
- Real tool calls when the server is present and `memory_enabled: false` is set

The test coverage for this is limited: T015 verifies `memory-convention.md` contains the gate documentation; T018 spot-checks that `speckit.plan`, `speckit.review`, and `speckit.audit` contain the gate reference. Neither test verifies the check is correctly implemented in the skill's control flow — only that the relevant text is present in the file.

## Why Server-Side Enforcement Was Rejected

ADR-051 § Alternatives Considered: server-side enforcement would require the server to read `constitution.md` on every tool call, coupling the server to the constitution file location, and would break FR-010 (direct MCP tool calls must always pass through regardless of constitution settings). The skill-layer convention was chosen as the only approach compatible with FR-010.

## Mitigation

- T018 audit test added to `test_staleness.py`: greps skill command files for `memory_enabled` or `constitution` keyword presence
- `memory-convention.md` updated with explicit gate-check template and cross-reference guidance
- Code review checklist: any new skill that is added to the recall/store table in `memory-convention.md` must be verified to include the gate check block

## Impact

- 2026-04-21: The gate check is no longer convention-only at the three gated skill sites (`speckit.plan.md`, `speckit.review.md`, `speckit.audit.md`). The full front-matter parse + `memory_enabled` check is inlined at each recall site, making the gate locally inspectable in each command file and eliminating the "aspirational reference" risk previously flagged here (/speckit.audit 2026-04-20 T018).

## Open Questions

1. Should the gate check be extracted into a reusable prompt fragment (e.g., a separate `.claude/rules/gate-check.md` that is included in skill prompts) to reduce copy-paste drift?
2. If a third skill is added that requires recall/store, will the T018 audit test be updated proactively, or will it lag?

**Revisit trigger**: A skill is found in production that made `memory_recall` calls despite `memory_enabled: false`. At that point, consider server-side enforcement (violates FR-010) or a shared prompt fragment approach.
