# Conventions

## Git

- Default branch MUST be `main` — initialize new repos with `git init -b main`
- Branch per feature: `###-feature-name` (e.g., `001-user-auth`)
- Commit format: conventional commits (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`)
- Commit after each completed task
- PRs target ≤300 LOC (calibrated by constitution; may be 200 or 500 depending on project context)
- No credentials or secrets in source — use environment variables

## Decision Records

All architectural decisions and significant challenges are tracked in `.specify/memory/`:

| Type | Prefix | Purpose |
|---|---|---|
| ADR | `ADR_NNN_title.md` | Technology choices, system structure, data models |
| LOG | `LOG_NNN_title.md` | Challenges, open questions, updates |

Both types share a sequential counter. Cross-references between records and
spec/plan artifacts are mandatory (Principle VII).

## Spec-Kit Artifacts

Each feature lives in `specs/[###-feature-name]/` with:

| File | Purpose | Created by |
|---|---|---|
| `spec.md` | User stories, requirements, success criteria | `/speckit.specify` |
| `plan.md` | Technical approach, architecture, project structure | `/speckit.plan` |
| `tasks.md` | Actionable task checklist with dependencies | `/speckit.tasks` |
| `research.md` | Research findings and alternatives explored | `/speckit.plan` |
| `data-model.md` | Entity definitions, relationships, constraints | `/speckit.plan` |
| `contracts/` | API contracts, interface specifications | `/speckit.plan` |

## Definition of Done

A feature is done when:
1. All tasks in `tasks.md` are checked off
2. The independent test from `spec.md` passes
3. All PRs are within LOC limits or exceptions documented
4. All ADRs and LOGs are written and cross-referenced
5. `CLAUDE.md` reflects any new commands, dependencies, or structure changes
6. Adversarial review findings are addressed or documented as accepted risks
7. Branch is merged and deleted
