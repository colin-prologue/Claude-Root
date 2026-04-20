---
description: Run a bidirectional consistency audit between documentation artifacts and source code. Detects drift, orphaned features, duplicate implementations, and recommends new ADRs/LOGs for untracked decisions found in code.
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Goal

Perform a comprehensive bidirectional audit of the current feature's documentation artifacts against the actual source code implementation. Unlike `/speckit.analyze` (which only checks spec↔plan↔tasks consistency), this command closes the loop by comparing **documentation to code and code to documentation**.

The audit also proactively recommends new decision records (ADRs, LOGs) for architectural choices that exist in code but aren't formally tracked.

## Prerequisites

1. At least one feature must exist in `specs/` with implementation code in `src/`
2. A constitution must exist at `.specify/memory/constitution.md`
3. For best results, the feature should have spec.md, plan.md, and tasks.md

If no implementation code exists yet, the audit focuses on documentation-internal consistency and pre-implementation readiness checks.

## Execution Steps

### 1. Determine Audit Scope

If `$ARGUMENTS` specifies a feature (e.g., "audit 001-user-auth"), use that feature directory.

Otherwise, run `.specify/scripts/bash/check-prerequisites.sh --json` to detect the active feature. If no active feature, offer to audit the full repository (CLAUDE.md, constitution, global structure).

Determine what's available:

| Available | Audit Mode |
|---|---|
| Only docs (no src/) | Pre-implementation readiness audit |
| Docs + partial code | Active development audit |
| Docs + complete code | Post-implementation audit |
| Only code (no docs) | Documentation gap audit |

### 2. Load Context

Read these files (as available):

**Documentation artifacts:**
- `.specify/memory/constitution.md` — principles and project context
- `specs/[feature]/spec.md` — requirements and user stories
- `specs/[feature]/plan.md` — technical approach
- `specs/[feature]/tasks.md` — task checklist with completion status
- `specs/[feature]/data-model.md` — data model (if exists)
- `specs/[feature]/contracts/` — API contracts (if exist)
- `specs/[feature]/research.md` — research findings (if exists)
- `.specify/memory/ADR_*.md` — all existing ADRs
- `.specify/memory/LOG_*.md` — all existing LOGs
- `CLAUDE.md` — project context and stack info

**Memory recall** (apply gate per `memory-convention.md`): if enabled, call `memory_recall("ADR decisions architectural patterns prior audit findings")` and use surfaced decisions as context for the auditor.

**Code artifacts:**
- `src/` — all source files (scan structure and key files)
- `tests/` — all test files
- Dependency manifests: `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `Gemfile`, `requirements.txt`, etc.
- Configuration files: `.env.example`, `docker-compose.yml`, CI configs, Terraform/Pulumi files
- Lock files for version verification: `package-lock.json`, `poetry.lock`, etc.

### 3. Execute Three-Pass Audit

Spawn the `consistency-auditor` agent with the collected context. The agent performs:

**Pass 1 — Documentation → Code (Compliance)**
- ADR decisions reflected in code?
- Spec requirements implemented?
- Plan structure matches filesystem?
- Completed tasks have real implementations?
- Contracts match actual endpoints?

**Pass 2 — Code → Documentation (Freshness)**
- Undocumented dependencies?
- Architectural patterns without ADRs?
- Undocumented API endpoints?
- CLAUDE.md accuracy?
- Dead/orphaned features?
- Decisions hiding in config files?

**Pass 3 — Consistency Crosscheck**
- Naming convention drift?
- Error handling divergence?
- Duplicate implementations (Rule of Three)?
- Terminology differences across artifacts?

### 4. Decision Record Discovery

This is the critical value-add. For each finding, the auditor assesses whether it implies an untracked decision:

**ADR-worthy decisions** (architectural choices embedded in code):
- Technology/library choices not formally decided
- Design patterns consistently used but never documented
- Infrastructure decisions in config files
- Security approaches (auth strategy, encryption, token handling)
- Data storage and caching strategies
- API versioning and serialization formats

**LOG-worthy items** (questions, challenges, updates):
- TODO/FIXME/HACK comments indicating unresolved decisions
- Inconsistent patterns suggesting undecided direction
- Feature flags or commented-out code (deferred decisions)
- Skipped tests indicating known issues
- Code contradicting documented ADRs (challenges)
- Superseded decisions not updated (updates)

### 5. Health Score Computation

Compute a health score across five dimensions (0-100%):

**ADR Compliance** (weight: 25%)
```
Score = (ADR decisions followed in code / Total ADR decisions) * 100
Deductions: -20 per CRITICAL violation, -10 per HIGH, -5 per MEDIUM
```

**Spec Coverage** (weight: 25%)
```
Score = (Requirements with implementation evidence / Total requirements) * 100
Deductions: -15 per unimplemented P1 requirement, -10 per P2, -5 per P3
```

**Documentation Freshness** (weight: 20%)
```
Score = (Accurate doc claims / Total doc claims checked) * 100
Deductions: -10 per stale major claim (stack, architecture), -5 per minor
```

**Code Consistency** (weight: 15%)
```
Score = 100 - (Divergent patterns * 5) - (Naming violations * 2) - (Duplicate impls * 3)
Floor at 0
```

**Decision Tracking** (weight: 15%)
```
Score = (Tracked decisions / (Tracked + Untracked decisions found)) * 100
Deductions: -15 per untracked architectural decision, -5 per untracked config decision
```

**Overall Health** = Weighted average, displayed as a letter grade:
- A (90-100): Excellent consistency
- B (80-89): Good, minor issues
- C (70-79): Needs attention
- D (60-69): Significant drift
- F (<60): Critical — stop and fix before proceeding

### 6. Present Results

Display the full audit report. Then offer actions:

**If CRITICAL findings exist:**
```
Critical consistency issues found. Recommended actions:
1. FIX — Address critical drift before continuing development
2. DOCUMENT — Create recommended ADRs/LOGs for untracked decisions
3. BOTH — Fix critical issues AND create decision records
4. ACKNOWLEDGE — Log findings as accepted drift (creates LOG entries)
```

**If only MEDIUM/LOW findings:**
```
No critical issues. Recommended actions:
1. DOCUMENT — Create recommended ADRs/LOGs (quick wins)
2. CLEAN — Address consistency issues (naming, duplicates)
3. SKIP — Accept current state, revisit later
```

### 7. Create Decision Records (if user approves)

For each approved ADR recommendation:
- Determine next available NNN (scan `.specify/memory/` for existing ADR/LOG numbers)
- Create `ADR_NNN_[title].md` using `.specify/templates/adr-template.md`
- Populate Context and Decision sections from audit findings
- Set Status to "Accepted" (the code already implements the decision)
- Set "Decision Made In" to the code location where the decision was detected
- Add back-reference to relevant spec/plan if applicable

For each approved LOG recommendation:
- Create `LOG_NNN_[title].md` using `.specify/templates/log-template.md`
- Set appropriate Type (QUESTION/CHALLENGE/UPDATE)
- Populate Description and Context from audit findings
- Set Status to "Open" for questions, "Resolved" for updates

Update the feature's Decision Records table in spec.md/plan.md with new entries.

### 7.5. Memory Store

If memory is enabled (per `memory-convention.md`), call `memory_store` with a 2-5 sentence summary covering the overall health grade, critical and high findings, and any new ADRs/LOGs created or recommended; use `section: "speckit.audit findings"` and metadata per `memory-convention.md`.

### 8. Update CLAUDE.md (if freshness issues found)

If the audit detected CLAUDE.md inaccuracies, offer to fix them:
- Stack version updates
- Directory structure corrections
- Command updates
- Recent changes entries

Only update with user approval. Each fix is a targeted edit, not a full rewrite.

## Operating Principles

### Evidence-Based Findings
Every finding must reference a specific file and line number. No vague claims like "the code seems inconsistent." Show the evidence.

### Severity Respects Calibration
The constitution's rigor levels determine severity. A naming convention violation in a LIGHTWEIGHT-rigor project is LOW, not MEDIUM. An ADR violation is always HIGH or CRITICAL regardless of rigor.

### Decision Records are the Primary Output
The most valuable output isn't the drift report — it's the recommended ADRs and LOGs. Every project accumulates untracked decisions. Surfacing them is more valuable than flagging style issues.

### Safe Dead Code Flagging
When flagging potentially dead code, always note confidence level:
- **HIGH confidence**: No imports, no test references, no dynamic loading patterns
- **MEDIUM confidence**: No static references but could be dynamically loaded
- **LOW confidence**: Appears unused but is in a plugin/extension directory

Never recommend deleting LOW confidence dead code. For MEDIUM, recommend investigation first.

### Duplicate Code: Rule of Three
Two similar implementations might be intentional (different contexts). Three or more similar implementations almost certainly need refactoring. Only flag duplicates at 3+ occurrences.

## Audit Modes

### Full Repository Audit
```
/speckit.audit
```
Audits all features, global docs (CLAUDE.md, README), and cross-feature consistency.

### Single Feature Audit
```
/speckit.audit 001-user-auth
```
Audits one feature's artifacts against its implementation.

### Focused Audit
```
/speckit.audit decisions
```
Only runs decision record discovery (Pass 2 + recommendations). Fast mode for surfacing untracked ADRs.

```
/speckit.audit freshness
```
Only checks documentation accuracy (CLAUDE.md, stack versions, structure). Fast mode for doc maintenance.

```
/speckit.audit compliance
```
Only checks documented decisions against code (Pass 1). Fast mode for ADR compliance verification.
