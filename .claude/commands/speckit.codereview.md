---
description: Spawn a code review panel against the feature's implementation. Reviews the git diff and all files touched by the feature for correctness, test quality, ADR compliance, and maintainability.
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Goal

Orchestrate an adversarial code review of the current feature's implementation using Agent Teams. Unlike `/speckit.audit` (which checks doc-code consistency and drift), this command reviews **code quality** — correctness, test adequacy, ADR compliance, and maintainability.

Run after `/speckit.implement`, before or alongside `/speckit.audit`.

## Prerequisites

1. Agent Teams must be enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)
2. A constitution must exist at `.specify/memory/constitution.md`
3. Implementation code must exist (git diff from main must be non-empty)
4. At least spec.md should exist for the active feature

## Execution Steps

### 1. Determine Scope

Run `.specify/scripts/bash/check-prerequisites.sh --json` from repo root to detect the active feature.

If `$ARGUMENTS` specifies a feature (e.g., `001-user-auth`) or a branch, use that. Otherwise use the active feature.

### 2. Collect Code Artifacts

Run these commands and store output as `CODE_CONTEXT`:

```bash
# 1. Get the diff since branching from main
git diff main...HEAD

# 2. Get all files changed in this branch
git diff --name-only main...HEAD

# 3. For each changed file, also identify files it imports/requires
#    (grep for import/require/include patterns in changed files)
#    Add those files to the touched-files list
```

Build `TOUCHED_FILES`: the union of (files changed in diff) + (files directly imported by changed files, one level deep). Do not recurse further — one level is enough to catch shared utilities and interfaces without pulling in the whole codebase.

Read each file in `TOUCHED_FILES` in full.

### 3. Load Documentation Context

Read these files and store as `DOC_CONTEXT`:

- `specs/[feature]/spec.md` — requirements and acceptance criteria
- `.specify/memory/ADR_*.md` — all existing ADRs (for compliance checking)
- `CLAUDE.md` — project conventions (naming, structure, commit format)
- `.specify/memory/constitution.md` — extract `CALIBRATION_BLOCK` (Project Context + principle rigor levels)

**Do NOT instruct agents to re-read these files.** Inject `CALIBRATION_BLOCK` and relevant excerpts directly into each agent's prompt.

### 4. Compose Review Panel

Determine rigor from Principle VIII in the constitution, or apply the benchmark-validated default:

**Default rigor for code review gate: LIGHTWEIGHT**

Rationale: `code-reviewer` + `devils-advocate` covers correctness, test gaps, and assumption challenges for the majority of features. Upgrade to STANDARD when the feature touches security-sensitive code (auth, payments, PII handling, cryptography).

| Rigor | Panel |
|-------|-------|
| FULL | code-reviewer, security-reviewer, devils-advocate |
| STANDARD | code-reviewer, security-reviewer, devils-advocate |
| LIGHTWEIGHT | code-reviewer, devils-advocate |

The `synthesis-judge` is ALWAYS spawned after all panel reviewers complete.

If `$ARGUMENTS` contains `--rigor FULL`, `--rigor STANDARD`, or `--rigor LIGHTWEIGHT`, use that override.

### 5. Execute Three-Phase Review

**CRITICAL: Anti-convergence protocol. Do not skip or compress phases.**

#### Phase A: Independent Analysis (Parallel)

Spawn all panel reviewers simultaneously. Each reviewer receives:

```
You are the [PERSONA_NAME] reviewer performing a code review.

Feature: [FEATURE_NAME]
Branch diff: [git diff output from CODE_CONTEXT]
Touched files: [full content of each file in TOUCHED_FILES]

Documentation context:
- spec.md requirements: [relevant acceptance criteria]
- Existing ADRs: [full ADR content]
- Project conventions (CLAUDE.md): [naming, structure, commit format section]

Project context and calibration (extracted from constitution — do not re-read the file):
[CALIBRATION_BLOCK]

IMPORTANT: This is Phase A — independent analysis. You have NOT seen other reviewers' findings.
Work independently. Produce your findings using your standard output format.

Quality over quantity. If the code is genuinely solid, state that clearly with evidence —
do not manufacture findings. The synthesis judge handles noise filtering; better not to generate it.
```

The `security-reviewer` should focus its code review on: hardcoded secrets, injection vulnerabilities, missing input validation, broken auth checks, unsafe deserialization, missing security headers, and insecure direct object references — not spec/plan-level concerns.

Wait for ALL reviewers to complete Phase A before proceeding.

#### Phase B: Cross-Examination (Sequential)

After all Phase A findings are collected:

1. Build a **consensus summary**: findings raised by 2+ reviewers (same issue, same or different framing).

Share with the `devils-advocate`:

```
Here is the consensus summary from Phase A (findings raised by 2+ reviewers):

[CONSENSUS_SUMMARY]

Also note: these areas received NO coverage from any reviewer:
[UNCOVERED_AREAS]

Execute your Consensus Challenge protocol:
- Challenge each consensus finding — is the agreement genuine or groupthink?
- Investigate the uncovered areas
- Propose at least one reframe: what if the code is right and the spec is wrong?
```

2. Share devil's advocate challenges back to each specialist:

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

Spawn `synthesis-judge` with all Phase A and Phase B outputs:

```
You are the synthesis judge. Here are all reviewer findings and cross-examination results:

[All Phase A outputs]
[Devil's advocate challenges]
[All Phase B responses]

Produce the Review Synthesis Report following your standard format.
Ensure majority findings, minority dissents, and unresolved items are all preserved.

For code review specifically:
- Map correctness bugs to immediate fix recommendations
- Map ADR violations to the specific ADR and decision record
- Map test gaps to specific scenarios that need coverage
- Map unresolved architectural questions to LOG recommendations
```

### 6. Present Results

Display the synthesis report. Then:

**If CRITICAL findings exist (correctness bugs, security vulnerabilities, ADR violations):**
```
Critical findings require resolution before merging. Options:
1. FIX — Address and re-run code review
2. DOCUMENT — Create LOG entries for accepted risks and proceed
3. OVERRIDE — Proceed despite critical findings (creates LOG entry)
```

**If only MEDIUM/LOW findings:**
```
No critical issues. Options:
1. FIX — Address findings before merging
2. ACCEPT — Proceed to /speckit.audit or merge
3. LOG — Document accepted findings as technical debt
```

### 7. Create Decision Records (if applicable)

If review surfaces untracked architectural decisions (e.g., a library choice made during implementation, a pattern applied consistently but never documented):

- Offer to create `ADR_NNN_[title].md` for each decision
- Offer to create `LOG_NNN_[title].md` for open questions or accepted risks
- Update the feature's Decision Records table in spec.md or plan.md with back-references

Determine next available NNN by scanning `.specify/memory/` for existing ADR/LOG numbers.

## Operating Principles

### Scope is Bounded

Only review code in `TOUCHED_FILES`. Do not audit the full repository — that's `/speckit.audit`. One level of import expansion is enough to catch interface misuse without scope creep.

### ADR Compliance is Non-Negotiable

An ADR represents a decided architectural choice. Code that contradicts an ADR is always at least a HIGH finding regardless of rigor level. Do not calibrate this down.

### Correctness Over Style

A correctness bug in LIGHTWEIGHT rigor is still a CRITICAL finding. Rigor calibration affects how much attention is paid to maintainability and convention violations — not whether bugs are flagged.

### This Command Does Not Modify Code

`/speckit.codereview` is non-destructive. It produces a report and offers to create decision records. No source files are edited. Fixes happen in follow-up commits.

### Relationship to /speckit.audit

These commands are complementary, not redundant:

| Command | Primary question |
|---------|-----------------|
| `/speckit.codereview` | Is the code correct, well-tested, and well-written? |
| `/speckit.audit` | Do the docs and code tell the same story? |

Run `/speckit.codereview` first (catches bugs), then `/speckit.audit` (catches drift and untracked decisions).
