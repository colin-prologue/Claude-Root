# Agent Personas

Seven agent personas live in `.claude/agents/` for use with Agent Teams.

## Review Agents (spawned by `/speckit.review`)

| Agent | Model | Focus | Gates |
|---|---|---|---|
| `product-strategist` | Sonnet | User value, requirements completeness, stakeholder coverage | Spec |
| `systems-architect` | Sonnet | Scalability, modularity, technical design quality | Plan, Tasks |
| `security-reviewer` | Sonnet | Vulnerabilities, threat vectors, data protection | Spec, Plan |
| `delivery-reviewer` | Sonnet | Dependencies, risk, test coverage, execution readiness | Tasks, Pre-impl |
| `devils-advocate` | Opus | Assumption challenges, hidden risks, anti-convergence | All gates |
| `synthesis-judge` | Opus | Integrates findings, preserves dissent, produces consensus | All gates |

## Audit Agent (spawned by `/speckit.audit`)

| Agent | Model | Focus |
|---|---|---|
| `consistency-auditor` | Opus | Bidirectional doc-code drift, decision record discovery |

## Calibration

All agents read `.specify/memory/constitution.md` at startup to calibrate review
intensity based on the Project Context and principle rigor levels (FULL/STANDARD/LIGHTWEIGHT).

The devil's advocate and synthesis judge always run at FULL rigor regardless of project context.
