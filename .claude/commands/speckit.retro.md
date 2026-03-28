---
description: Post-implementation retrospective that reassesses roadmap assumptions, updates priorities, and feeds learnings back into the brainstorm roadmap and constitution.
handoffs:
  - label: Update Roadmap
    agent: speckit.brainstorm
    prompt: Update the roadmap based on retrospective findings...
  - label: Update Constitution
    agent: speckit.constitution
    prompt: Update the constitution based on what we learned...
  - label: Specify Next Feature
    agent: speckit.specify
    prompt: Specify the next feature from the updated roadmap...
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Goal

After implementing one or more features, step back and reassess. What did we learn?
What assumptions were wrong? How should the roadmap change? This command closes the
feedback loop between implementation and planning.

The retro updates `roadmap.md` with validated/invalidated assumptions, adjusts
priorities, and may surface new features or kill planned ones.

## When to Run

- After completing a roadmap phase (all MVP features done)
- After completing a significant feature that changed your understanding
- When the team feels the roadmap no longer reflects reality
- Periodically (e.g., monthly) on active projects

## Execution Steps

### 1. Load Context

Read these files (as available):

- `roadmap.md` (or `specs/roadmap.md`) — current feature roadmap
- `brainstorm-notes.md` — original brainstorm artifacts
- `.specify/memory/constitution.md` — project context and governance
- All completed feature specs: `specs/*/spec.md`
- All completed plans: `specs/*/plan.md`
- All task files: `specs/*/tasks.md` (check completion status)
- All ADRs and LOGs: `.specify/memory/ADR_*.md`, `.specify/memory/LOG_*.md`

If no `roadmap.md` exists, inform the user this command is designed to update
an existing roadmap. Suggest running `/speckit.brainstorm` first.

### 2. Implementation Summary

Produce a quick snapshot of what's been built:

```markdown
## Implementation Summary

**Features completed**: [list with status]
**Features in progress**: [list]
**Features not started**: [list]
**ADRs created**: [count, key decisions]
**LOGs open**: [count, key questions]
**LOGs resolved**: [count]
```

### 3. Assumption Review

For each completed feature, revisit the **Assumptions** listed in `roadmap.md`:

```markdown
## Assumption Review

| Feature | Assumption | Status | What We Learned |
|---------|-----------|--------|----------------|
| 001-auth | Users want email/password login | Validated | Also need SSO for enterprise |
| 002-search | Full-text search is sufficient | Invalidated | Users need semantic/fuzzy search |
| 003-export | CSV export covers most needs | Partially validated | Also need PDF for reports |
```

For each assumption:
- **Validated**: Evidence from implementation/testing confirms it
- **Invalidated**: Reality was different — what was it actually?
- **Partially validated**: Mostly right, but with caveats
- **Untested**: We haven't learned anything about this yet

Present to user for review. They may have insights from user feedback,
support tickets, or their own experience that aren't in the code.

### 4. Interactive Retrospective Questions

Ask these ONE AT A TIME, adapting based on answers:

1. **What surprised you during implementation?**
   - Technical surprises, scope surprises, user feedback surprises
   - These often reveal wrong assumptions in the roadmap

2. **What was harder than expected? What was easier?**
   - Effort estimates in the roadmap may need recalibrating
   - Features marked "Straightforward" that turned out "Exploratory" need attention

3. **Did users/stakeholders request anything unexpected?**
   - New feature ideas that emerged from real usage
   - These should be added to the roadmap's raw idea pool

4. **What would you do differently if starting over?**
   - Architectural decisions that should be ADRs
   - Ordering changes (should feature X have come before feature Y?)

5. **Has the problem statement changed?**
   - Sometimes building the MVP reveals the real problem is different
   - If so, the roadmap's Phase 2/3 features may need rethinking

6. **Are any planned features now unnecessary?**
   - Features that seemed important before MVP but are now redundant
   - Features that an existing tool or dependency already handles

### 5. Roadmap Impact Analysis

Based on the retro findings, categorize impacts:

**Priority Changes:**
- Features that should move UP in priority (validated need, higher urgency)
- Features that should move DOWN (less important than thought)
- Features that should be KILLED (invalidated assumption, no longer relevant)

**New Features:**
- Features surfaced by implementation experience or user feedback
- Quick-classify with MoSCoW (Must/Should/Could/Won't)

**Effort Recalibration:**
- Features whose effort estimate changed based on implementation experience
- Infrastructure features that are now easier/harder because of what was built

**Dependency Changes:**
- New dependencies discovered during implementation
- Dependencies that no longer exist (shared infrastructure was built)

**Constitution Updates:**
- Project context changes (audience grew, data sensitivity changed, team changed)
- Principle rigor adjustments (learned TDD is more/less important than thought)

Present the full impact analysis to the user for approval.

### 6. Update Roadmap

With user approval, update `roadmap.md`:

1. **Update feature statuses** — Mark completed features, adjust in-progress
2. **Move features between phases** — Based on priority changes
3. **Add new features** — From retro discoveries, with feature detail blocks
4. **Remove killed features** — Move to Deferred with "Killed in retro [date]: [reason]"
5. **Update effort estimates** — Based on implementation experience
6. **Update feasibility ratings** — Based on what we now know
7. **Revise assumptions** — Update Assumptions in feature details with validated/invalidated status
8. **Add Revision History entry**:
   ```
   | [YYYY-MM-DD] | Post-[phase] retrospective: [summary] | /speckit.retro |
   ```
9. **Update "Last Updated" date**

### 7. Update Brainstorm Notes

Append a retro section to `brainstorm-notes.md`:

```markdown
## Retrospective — [YYYY-MM-DD]

### What We Learned
[Key findings]

### Assumptions Validated
[List]

### Assumptions Invalidated
[List]

### New Ideas Surfaced
[List — added to roadmap raw idea pool]

### Features Killed
[List with reasons]
```

### 8. Recommend Follow-Up Actions

Based on findings, suggest concrete next steps:

```
Retrospective complete. Recommended actions:

[If constitution needs updating:]
→ Run `/speckit.constitution` to update Project Context
  (audience/stakes/team changed based on what we learned)

[If new features were added:]
→ Run `/speckit.specify [feature]` for new high-priority features

[If ADRs are missing:]
→ Run `/speckit.audit decisions` to surface untracked decisions

[If roadmap changed significantly:]
→ Review updated roadmap.md and confirm Phase 2 priorities

[If problem statement shifted:]
→ Consider running `/speckit.brainstorm` again with the refined understanding
```

## Operating Principles

### Honesty Over Optimism

The retro is the place to confront reality. If a feature took 3x longer than estimated,
say so. If the original problem statement was wrong, say so. Sugarcoating findings
defeats the purpose.

### Assumptions Are First-Class Citizens

The most valuable retro output is validated/invalidated assumptions. These prevent
the team from building Phase 2 features based on Phase 1 assumptions that turned
out to be wrong.

### The Roadmap Is a Living Document

The roadmap is not a commitment — it's a plan that updates as you learn. Features
being killed or reprioritized is a sign of healthy project management, not failure.

### Non-Destructive

This command does NOT delete completed specs, plans, or tasks. It only updates
`roadmap.md` and `brainstorm-notes.md`. Existing artifacts remain as the historical
record of what was built and why.

## Context

$ARGUMENTS
