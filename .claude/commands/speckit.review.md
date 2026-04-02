---
description: Spawn a multi-persona adversarial review panel calibrated to the current project context and spec-kit phase. Produces a synthesis report with majority findings, preserved dissent, and unresolved items.
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Goal

Orchestrate a multi-persona adversarial review of the current feature's artifacts using Agent Teams. The review panel composition and intensity are calibrated by the Project Context and principle rigor levels in the constitution.

## Prerequisites

1. Agent Teams must be enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)
2. A constitution with Project Context must exist at `.specify/memory/constitution.md`
3. At least one artifact must exist to review (spec.md, plan.md, or tasks.md)

## Execution Steps

### 1. Detect Current Phase

Run `.specify/scripts/bash/check-prerequisites.sh --json` from repo root to determine available artifacts. Based on what exists, determine the review gate:

| Available Artifacts | Gate | Phase Name |
|---|---|---|
| spec.md only | Post-specify | specification |
| spec.md + plan.md | Post-plan | plan |
| spec.md + plan.md + tasks.md | Post-tasks | task |
| User explicitly requests pre-implementation review | Pre-implement | pre-implementation |

If the user specifies a gate in `$ARGUMENTS` (e.g., "review the plan", "review tasks"), use that gate regardless of available artifacts.

For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

### 2. Load Constitution & Calibration

Read `.specify/memory/constitution.md` once. Extract and store as `CALIBRATION_BLOCK`:
- The full **Project Context** section verbatim
- Each principle's rigor level as a compact list (e.g., "I:FULL II:STANDARD III:FULL …")
- **Adversarial Review principle** (Principle VIII) rigor level — determines panel composition

If no Project Context section exists, warn the user and recommend running `/speckit.constitution` first. Proceed with STANDARD defaults if the user wants to continue.

**Do NOT instruct agents to re-read constitution.md.** Inject `CALIBRATION_BLOCK` directly into each agent's prompt in Step 4. This avoids redundant file reads across the panel.

### 3. Compose Review Panel

Based on the gate and Principle VIII rigor level, select the review panel:

**Post-specify (specification gate):**

| Principle VIII Rigor | Panel |
|---|---|
| FULL | product-strategist, security-reviewer, devils-advocate |
| STANDARD | product-strategist, devils-advocate |
| LIGHTWEIGHT | devils-advocate only |

**Post-plan (plan gate):**

| Principle VIII Rigor | Panel |
|---|---|
| FULL | systems-architect, security-reviewer, delivery-reviewer, devils-advocate |
| STANDARD | systems-architect, security-reviewer, devils-advocate |
| LIGHTWEIGHT | devils-advocate only |

**Post-tasks (task gate):**

| Principle VIII Rigor | Panel |
|---|---|
| FULL | delivery-reviewer, systems-architect, devils-advocate |
| STANDARD | delivery-reviewer, devils-advocate |
| LIGHTWEIGHT | devils-advocate only |

**Pre-implementation (full gate):**

| Principle VIII Rigor | Panel |
|---|---|
| FULL | product-strategist, systems-architect, security-reviewer, delivery-reviewer, devils-advocate |
| STANDARD | systems-architect, security-reviewer, delivery-reviewer, devils-advocate |
| LIGHTWEIGHT | security-reviewer, devils-advocate |

The **synthesis-judge** is ALWAYS spawned after all panel reviewers complete, regardless of rigor level.

### 4. Execute Three-Phase Review

**CRITICAL: This is the anti-convergence protocol. Do not skip or compress phases.**

#### Phase A: Independent Analysis (Parallel)

Spawn all panel reviewers as Agent teammates simultaneously. Each reviewer receives:

```
You are the [PERSONA_NAME] reviewer. Review the following artifacts for [FEATURE_NAME]:

[List artifact paths]

Project context and calibration (extracted from constitution — do not re-read the file):
[CALIBRATION_BLOCK]

IMPORTANT: This is Phase A — independent analysis. You have NOT seen other reviewers' findings.
Work independently. Produce your findings using your standard output format.

Quality over quantity. If artifacts are genuinely sound, state that clearly with evidence —
do not manufacture findings. The synthesis judge handles noise filtering; better not to generate it.
```

Wait for ALL reviewers to complete Phase A before proceeding.

#### Phase B: Cross-Examination (Sequential)

After all Phase A findings are collected:

1. Before contacting the devil's advocate, **build a consensus summary**: identify all findings raised by 2+ reviewers (same issue, same or different framing). This is what the DA is specifically tasked to challenge — do not send full reports.

Share the consensus summary with the devils-advocate reviewer:

```
Here is the consensus summary from Phase A (findings raised by 2+ reviewers):

[CONSENSUS_SUMMARY — list of agreed findings with reviewer names, not full reports]

Also note: these topic areas received NO coverage from any reviewer:
[UNCOVERED_AREAS — gaps you identified while building the summary]

Execute your Consensus Challenge protocol:
- Challenge each consensus finding — is the agreement genuine or groupthink?
- Investigate the uncovered areas
- Propose at least one reframe of the problem
```

2. Share the devil's advocate challenges back to each specialist reviewer:

```
The devil's advocate has challenged your findings:

[Devil's advocate output]

Respond to the challenges. You may:
- Defend your finding with additional evidence
- Withdraw a finding if the challenge is valid
- Strengthen a finding based on the challenge
- Raise a new concern triggered by the challenge

Do NOT simply agree with the devil's advocate to avoid conflict.
```

#### Phase C: Synthesis

Spawn the synthesis-judge with ALL outputs from Phase A and Phase B:

```
You are the synthesis judge. Here are all reviewer findings and cross-examination results:

[All Phase A outputs]
[Devil's advocate challenges]
[All Phase B responses]

Produce the Review Synthesis Report following your standard format.
Ensure majority findings, minority dissents, and unresolved items are all preserved.
Map unresolved items to LOG file recommendations.
Map architectural decisions to ADR file recommendations.
```

### 5. Present Results

Display the synthesis report to the user. Then:

1. **If CRITICAL findings exist**:
   - Recommend resolving before proceeding to next phase
   - Offer to create LOG files for unresolved items
   - Offer to create ADR files for architectural decisions surfaced by review

2. **If only MEDIUM/LOW findings exist**:
   - User may proceed
   - Offer to document accepted risks as LOG entries

3. **Create Decision Records** (Principle VII):
   - For each unresolved item in the synthesis report, offer to create a `LOG_NNN_*.md` with type QUESTION or CHALLENGE
   - For each architectural decision surfaced, offer to create an `ADR_NNN_*.md`
   - Update the feature's Decision Records table in spec.md or plan.md with back-references

### 6. Gate Decision

Ask the user:

```
Review complete. Options:
1. PROCEED — accept findings and continue to next phase
2. REVISE — go back and address critical/high findings first
3. RE-REVIEW — run another review after making changes
4. OVERRIDE — proceed despite critical findings (documents as accepted risk)
```

If OVERRIDE is selected, create a `LOG_NNN_accepted_risk_[feature].md` documenting the decision to proceed despite findings.

## Operating Principles

### Anti-Convergence is Structural

The three-phase protocol (independent → challenge → synthesize) is the primary defense against premature consensus. Do NOT compress phases or allow reviewers to see each other's work during Phase A.

### Calibration Drives Efficiency

A solo dev's personal project should NOT spawn 5 reviewers for a spec review. The constitution's Project Context and Principle VIII rigor level determine panel size. Respect the calibration — the user set it intentionally.

### Dissent is Signal

Minority findings are preserved in the synthesis report even when other reviewers disagree. A finding dismissed by the majority is documented with reasoning, not deleted.

### Reviews are Non-Destructive

This command NEVER modifies spec.md, plan.md, or tasks.md. It produces a report and offers to create decision records (ADRs/LOGs). All artifact changes happen in subsequent commands or manual edits.

## Context

$ARGUMENTS
