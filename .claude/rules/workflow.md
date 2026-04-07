# Spec-Kit Workflow

New features follow this order:

0. `/speckit.brainstorm` *(optional)* — explore a vague idea, decompose into features, produce roadmap
1. `/speckit.constitution` — interactive project setup (context + calibrated governance)
2. `/speckit.specify` — write user stories and requirements
3. `/speckit.review` *(recommended)* — adversarial review of spec
4. `/speckit.clarify` *(optional)* — resolve ambiguities before planning
5. `/speckit.plan` — technical approach and project structure
6. `/speckit.review` *(recommended)* — adversarial review of plan
7. `/speckit.checklist` *(optional)* — validate spec quality
8. `/speckit.tasks` — actionable task list
9. `/speckit.review` *(recommended)* — adversarial review of tasks
10. `/speckit.analyze` *(optional)* — cross-artifact consistency check
11. `/speckit.implement` — execute tasks
12. `/speckit.codereview` *(recommended)* — adversarial code review: correctness, test quality, ADR compliance
13. `/speckit.audit` *(recommended)* — bidirectional doc-code consistency audit
14. `/speckit.retro` *(recommended)* — reassess assumptions, update roadmap, feed learnings back

Feature specs live in `specs/[###-feature-name]/`.

## Review Gates

`/speckit.review` spawns an Agent Team of specialized reviewers calibrated to the
project context set in the constitution. Review panels vary by phase:

| Gate | Panel |
|---|---|
| Spec | product-strategist, security-reviewer, devils-advocate |
| Plan | systems-architect, security-reviewer, delivery-reviewer, devils-advocate |
| Tasks | delivery-reviewer, systems-architect, devils-advocate |
| Pre-implementation | full panel |

Reviews follow a three-phase anti-convergence protocol:
1. **Phase A** — Independent analysis (parallel, isolated)
2. **Phase B** — Cross-examination (devil's advocate challenges findings)
3. **Phase C** — Synthesis (judge integrates with preserved dissent)

Panel size scales with Principle VIII rigor level (FULL/STANDARD/LIGHTWEIGHT).

## Code Review

`/speckit.codereview` reviews the feature's implementation after `/speckit.implement`:
- **Correctness**: bugs, unhandled errors, boundary conditions, logic vs. spec divergence
- **Test quality**: coverage gaps, vacuous assertions, untested error paths
- **ADR compliance**: implementation matches decided technology choices and patterns
- **Maintainability**: duplication (Rule of Three), dead code, naming

Default panel: `code-reviewer` + `devils-advocate` (LIGHTWEIGHT). Add `security-reviewer` for auth, payments, PII, or cryptography (STANDARD/FULL).

**Relationship to /speckit.audit**: complementary, not redundant. Run codereview first (catches bugs), then audit (catches drift).

## Consistency Audit

`/speckit.audit` performs bidirectional doc-code scanning after implementation:
- **Docs → Code**: Are ADR decisions followed? Are spec requirements implemented?
- **Code → Docs**: Are dependencies documented? Do undocumented architectural decisions exist?
- **Decision Discovery**: Recommends new ADRs/LOGs for decisions hiding in code
- **Health Score**: Grades consistency across 5 dimensions (A-F scale)
- Supports focused modes: `decisions`, `freshness`, `compliance`
