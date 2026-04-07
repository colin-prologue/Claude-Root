# Agent Personas

Twelve agent personas live in `.claude/agents/` for use with Agent Teams.

## Review Agents (spawned by `/speckit.review`)

| Agent | Model | Focus | Gates |
|---|---|---|---|
| `product-strategist` | Sonnet | User value, requirements completeness, stakeholder coverage | Spec |
| `systems-architect` | Sonnet | Scalability, modularity, technical design quality | Plan, Tasks |
| `security-reviewer` | Sonnet | Vulnerabilities, threat vectors, data protection | Spec, Plan |
| `delivery-reviewer` | Sonnet | Dependencies, risk, test coverage, execution readiness | Tasks, Pre-impl |
| `devils-advocate` | Opus | Assumption challenges, hidden risks, anti-convergence | All gates |
| `synthesis-judge` | Opus | Integrates findings, preserves dissent, produces consensus | All gates |

## Code Review Agents (spawned by `/speckit.codereview`)

| Agent | Model | Focus | Gates |
|---|---|---|---|
| `code-reviewer` | Sonnet | Correctness, test quality, ADR compliance, maintainability, conventions | Code |
| `security-reviewer` | Sonnet | In-code vulnerabilities: injection, secrets, missing auth, unsafe deserialization | Code (STANDARD/FULL) |

## Audit Agent (spawned by `/speckit.audit`)

| Agent | Model | Focus |
|---|---|---|
| `consistency-auditor` | Opus | Bidirectional doc-code drift, decision record discovery |

## Brainstorming Agents (spawned by `/speckit.brainstorm`)

| Agent | Model | Focus |
|---|---|---|
| `visionary` | Sonnet | Unconstrained creative ideation, boundary-pushing features |
| `user-advocate` | Sonnet | Daily user needs, pain points, practical value |
| `technologist` | Sonnet | Elegant solutions, platform capabilities, enabling infrastructure |
| `provocateur` | Sonnet | Lateral thinking, assumption inversion, contrarian ideas |

Brainstorming agents operate in **divergent mode** — no judgment, no feasibility checks.
Ideas are evaluated only after all rounds complete.

## Calibration

All agents read `.specify/memory/constitution.md` at startup to calibrate review
intensity based on the Project Context and principle rigor levels (FULL/STANDARD/LIGHTWEIGHT).

The devil's advocate and synthesis judge always run at FULL rigor regardless of project context.
