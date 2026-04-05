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
12. `/speckit.audit` *(recommended)* — bidirectional doc-code consistency audit
13. `/speckit.retro` *(recommended)* — reassess assumptions, update roadmap, feed learnings back

Feature specs live in `specs/[###-feature-name]/`.

## Review Gates

`/speckit.review` spawns an Agent Team of specialized reviewers calibrated to the
project context set in the constitution. Review panels vary by phase:

| Gate | Panel |
|---|---|
| Spec | product-strategist, security-reviewer, devils-advocate |
| Plan | systems-architect, security-reviewer, delivery-reviewer, operational-reviewer, devils-advocate |
| Tasks | delivery-reviewer, systems-architect, operational-reviewer, devils-advocate |
| Pre-implementation | full panel |

Reviews follow a three-phase anti-convergence protocol:
1. **Phase A** — Independent analysis (parallel, isolated)
2. **Phase B** — Cross-examination (devil's advocate challenges findings)
3. **Phase C** — Synthesis (judge integrates with preserved dissent)

Panel size scales with Principle VIII rigor level (FULL/STANDARD/LIGHTWEIGHT).

### Rigor Selection Guide

Benchmark-validated defaults (`000-review-benchmark`). Rigor is gate-specific — the optimal level differs at each phase.

| Gate | Default | Use FULL when | Skip to LIGHTWEIGHT when |
|---|---|---|---|
| Spec | STANDARD | Feature touches auth, PII, payments, or compliance (adds security-reviewer) | Never — LIGHTWEIGHT produces 0% planted-issue detection at this gate without specialist reviewers |
| Plan | STANDARD | Production service with on-call/SLA obligations (adds delivery + operational depth) | Pre-pass to surface blockers before committing to STANDARD |
| Task | LIGHTWEIGHT | You need delivery-reviewer explicitly: rollback posture, PR sizing, repository test gaps | Default — DA catches TDD ordering violations and [P] marker defects as reliably as STANDARD |

**Key findings from benchmark:**
- LIGHTWEIGHT at spec gate is not useful: no product-strategist or security-reviewer means product and security gaps are systematically missed even when present.
- STANDARD at plan gate matches FULL for planted-issue detection. FULL adds operational depth (failure modes, health check sequencing), not new finding categories.
- FULL at task gate has the same detection rate as STANDARD and LIGHTWEIGHT. Incremental value is depth, not breadth.
- The devils-advocate alone catches constitutional violations (TDD ordering, invalid [P] markers, missing ADRs) at any gate — LIGHTWEIGHT is effective wherever those are the primary concern.

## Consistency Audit

`/speckit.audit` performs bidirectional doc-code scanning after implementation:
- **Docs → Code**: Are ADR decisions followed? Are spec requirements implemented?
- **Code → Docs**: Are dependencies documented? Do undocumented architectural decisions exist?
- **Decision Discovery**: Recommends new ADRs/LOGs for decisions hiding in code
- **Health Score**: Grades consistency across 5 dimensions (A-F scale)
- Supports focused modes: `decisions`, `freshness`, `compliance`
