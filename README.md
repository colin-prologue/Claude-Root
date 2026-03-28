# Spec-Kit Starter Template

A spec-driven development template for Claude Code with multi-agent adversarial review,
structured brainstorming, and bidirectional consistency auditing.

Use this as a starting point for any project — it's language-agnostic and scales from
solo prototypes to team-driven production systems.

## What This Is

A governance and workflow framework that ensures you **think before you build**.
Every feature goes through structured phases: brainstorm → specify → review → plan →
implement → audit. Multi-agent review panels catch blind spots. Decision records
track *why*, not just *what*.

## Quick Start

```bash
# 1. Clone or copy this template into your project
# 2. Open Claude Code and run:

/speckit.brainstorm      # Got a vague idea? Start here.
/speckit.constitution    # Set up project governance (team, audience, stakes)
/speckit.specify         # Write your first feature spec
```

## The Workflow

```
  ┌─────────────────────────────────────────────────────────────────┐
  │                    IDEATION & GOVERNANCE                        │
  │                                                                 │
  │  /speckit.brainstorm ──→ /speckit.constitution                  │
  │  (vague idea → roadmap)   (project context → calibrated rules)  │
  └────────────────────────────────┬────────────────────────────────┘
                                   │
                                   ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │                    PER-FEATURE CYCLE                            │
  │                                                                 │
  │  /speckit.specify ──→ /speckit.review ──→ /speckit.clarify      │
  │  (requirements)       (adversarial)       (resolve ambiguity)   │
  │                                                                 │
  │  /speckit.plan ──→ /speckit.review ──→ /speckit.checklist       │
  │  (architecture)    (adversarial)       (requirement quality)    │
  │                                                                 │
  │  /speckit.tasks ──→ /speckit.review ──→ /speckit.analyze        │
  │  (task breakdown)   (adversarial)       (cross-artifact check)  │
  │                                                                 │
  │  /speckit.implement ──→ /speckit.audit                          │
  │  (build it)             (doc-code consistency)                  │
  └────────────────────────────────┬────────────────────────────────┘
                                   │
                                   ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │                    FEEDBACK LOOP                                │
  │                                                                 │
  │  /speckit.retro ──→ update roadmap ──→ next feature             │
  │  (what did we learn?)                                           │
  └─────────────────────────────────────────────────────────────────┘
```

## Commands Reference

### Ideation & Governance

| Command | Purpose | When |
|---|---|---|
| `/speckit.brainstorm` | Explore a vague idea → prioritized feature roadmap | You have an idea but don't know the shape yet |
| `/speckit.constitution` | Interactive project setup → calibrated governance | Once per project, or when context changes |

### Per-Feature Specification

| Command | Purpose | When |
|---|---|---|
| `/speckit.specify` | Write user stories, requirements, success criteria | Start of every feature |
| `/speckit.clarify` | Resolve ambiguities with targeted questions | Before planning (optional but recommended) |
| `/speckit.plan` | Technical approach, data model, API contracts | After spec is approved |
| `/speckit.checklist` | Validate requirement quality (not implementation) | After plan (optional) |
| `/speckit.tasks` | Generate actionable task list with dependencies | After plan is approved |

### Quality Gates

| Command | Purpose | When |
|---|---|---|
| `/speckit.review` | Multi-agent adversarial review panel | After specify, plan, or tasks |
| `/speckit.analyze` | Cross-artifact consistency check (read-only) | After tasks, before implementing |

### Implementation & Verification

| Command | Purpose | When |
|---|---|---|
| `/speckit.implement` | Execute tasks with TDD discipline | After tasks are approved |
| `/speckit.audit` | Bidirectional doc-code consistency scan | After implementation |
| `/speckit.retro` | Retrospective: reassess assumptions, update roadmap | After completing a feature or phase |

### Utilities

| Command | Purpose | When |
|---|---|---|
| `/speckit.taskstoissues` | Convert tasks.md to GitHub issues | After tasks are generated (optional) |

## Adversarial Review System

`/speckit.review` spawns an Agent Team of specialized reviewers that work in three phases:

1. **Phase A — Independent Analysis**: Each reviewer works alone (no groupthink)
2. **Phase B — Cross-Examination**: Devil's advocate challenges all findings
3. **Phase C — Synthesis**: Judge integrates findings, preserves minority dissent

Review panels scale based on the project's governance calibration:

| Gate | FULL Panel | STANDARD | LIGHTWEIGHT |
|---|---|---|---|
| Spec | Product Strategist, Security, Devil's Advocate | Product Strategist, Devil's Advocate | Devil's Advocate |
| Plan | Architect, Security, Delivery, Devil's Advocate | Architect, Security, Devil's Advocate | Devil's Advocate |
| Tasks | Delivery, Architect, Devil's Advocate | Delivery, Devil's Advocate | Devil's Advocate |

## Agent Personas

Eleven agent personas in `.claude/agents/`:

| Agent | Role | Used By |
|---|---|---|
| `product-strategist` | User value, requirements completeness | `/speckit.review` |
| `systems-architect` | Scalability, modularity, technical design | `/speckit.review` |
| `security-reviewer` | Vulnerabilities, threat modeling, data protection | `/speckit.review` |
| `delivery-reviewer` | Dependencies, risk, test coverage | `/speckit.review` |
| `devils-advocate` | Assumption challenges, hidden risks (always FULL rigor) | `/speckit.review` |
| `synthesis-judge` | Integrates findings, preserves dissent | `/speckit.review` |
| `consistency-auditor` | Bidirectional doc-code drift, decision discovery | `/speckit.audit` |
| `visionary` | Unconstrained creative ideation | `/speckit.brainstorm` |
| `user-advocate` | Daily user needs and pain points | `/speckit.brainstorm` |
| `technologist` | Elegant solutions, enabling infrastructure | `/speckit.brainstorm` |
| `provocateur` | Lateral thinking, assumption inversion | `/speckit.brainstorm` |

## Consistency Audit

`/speckit.audit` closes the loop between documentation and code:

- **Docs → Code**: Are ADR decisions followed? Are spec requirements implemented?
- **Code → Docs**: Are dependencies documented? Do undocumented decisions exist in code?
- **Decision Discovery**: Recommends new ADRs/LOGs for architectural choices hiding in code
- **Health Score**: Grades consistency across 5 dimensions (A-F scale)
- **Focused modes**: `/speckit.audit decisions`, `/speckit.audit freshness`, `/speckit.audit compliance`

## Directory Structure

```
.claude/
  commands/             # Spec-Kit slash commands (13 total)
  agents/               # Agent persona definitions (11 total)
  rules/                # Modular instruction files (loaded automatically)
  settings.local.json   # Local settings (not committed)
.specify/
  memory/
    constitution.md     # Project principles + context (source of truth)
    ADR_NNN_*.md        # Architectural Decision Records
    LOG_NNN_*.md        # Decision Logs (challenges, questions, updates)
  templates/            # Document templates for all artifacts
  scripts/              # Helper scripts used by commands
specs/
  roadmap.md            # Feature roadmap (from /speckit.brainstorm)
  ###-feature-name/
    spec.md             # User stories & requirements
    plan.md             # Technical approach & architecture
    tasks.md            # Actionable task checklist
    research.md         # Research findings
    data-model.md       # Entity definitions & relationships
    contracts/          # API contracts & interface specs
src/                    # Application source code
tests/                  # Test suite
docs/                   # Long-form documentation
CLAUDE.md               # Project context for Claude (lean — details in .claude/rules/)
```

## Governance: The Constitution

The constitution (`.specify/memory/constitution.md`) is created interactively via
`/speckit.constitution`. It captures:

**Project Context** — Who's building this, who uses it, what's at stake:
- Team size, expertise, turnover
- Audience scale, diversity, accessibility needs
- Data sensitivity, compliance requirements, blast radius

**Governing Principles** — Each calibrated to your context (FULL / STANDARD / LIGHTWEIGHT):
- I. Specification Before Implementation
- II. Simplicity
- III. Test-Driven Development
- IV. Incremental & Independent Delivery
- V. Security by Default
- VI. Documentation Stays Current
- VII. Decision Transparency (ADRs & LOGs)
- VIII. Adversarial Review

A solo prototype gets LIGHTWEIGHT governance. A team product handling PII gets FULL.
The calibration is set once and informs every review panel's intensity.

## Reusing This Template

1. Copy the entire repo (or fork it) into your new project
2. Run `/speckit.brainstorm` if you're starting from a vague idea
3. Run `/speckit.constitution` to calibrate governance for your context
4. Update `CLAUDE.md` with your project name, stack, and commands
5. Start specifying features with `/speckit.specify`

## Requirements

- [Claude Code](https://claude.ai/code) v2.1.32+
- Agent Teams enabled: set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings
  (already configured in `.claude/settings.local.json`)
