---
description: Create or update the project constitution through an interactive guided conversation that establishes project context, calibrates governance principles, and configures review gates.
handoffs:
  - label: Build Specification
    agent: speckit.specify
    prompt: Implement the feature specification based on the updated constitution. I want to build...
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

You are creating or updating the project constitution at `.specify/memory/constitution.md`. This is an **interactive guided conversation** structured in three acts. Your goal is to understand the project, the people involved, and the stakes — then produce a calibrated constitution where principle rigor levels match the actual project context.

**Note**: If `.specify/memory/constitution.md` does not exist yet, copy `.specify/templates/constitution-template.md` to `.specify/memory/constitution.md` first. If an existing constitution exists, load it and offer to update specific sections rather than starting from scratch.

## Act 1: Project Identity

**Goal**: Understand what we're building and why.

Present these questions ONE AT A TIME. For each, provide a recommended answer if you can infer one from the repo context (README, existing code, CLAUDE.md, package files). The user can accept, modify, or provide their own answer.

1. **What does this project do?** (one sentence)
   - Scan README.md, package.json/pyproject.toml, CLAUDE.md for context
   - Suggest if inferable: `**Suggested:** [inferred purpose]`

2. **What problem does it solve, and for whom?**
   - This identifies the core value proposition and primary user

3. **Is this greenfield or extending something existing?**
   - Options: `Greenfield` / `Extending existing codebase` / `Replacing legacy system`
   - Scan for existing src/ code to infer

4. **What's the tech stack?** (or "undecided")
   - Scan existing files for language, framework, database, testing tools
   - Present findings: `**Detected:** [stack details]`
   - Ask if this is correct or if changes are planned

5. **What's the project status?**
   - Options: `Prototype/Experiment` / `Active development` / `Production` / `Maintenance`

Record all answers in working memory. Do not write files yet.

## Act 2: People & Stakes

**Goal**: Understand who's involved and what's at risk. This calibrates governance intensity.

Present these questions ONE AT A TIME with recommended options. Group related questions when natural.

### Development Team
6. **Who's building this?**
   - Options: `Just me` / `Small team (2-5)` / `Team (6-15)` / `Large org (15+)` / `Open source community`
   - **Recommended:** Infer from git log contributors if available

7. **What's the team's experience level with this stack?**
   - Options: `Learning` / `Comfortable` / `Expert`

8. **How stable is the team?**
   - Options: `Stable (same people long-term)` / `Moderate churn` / `High rotation`
   - Note: For "Just me" in Q6, auto-set to `Stable` and skip

9. **How does the team collaborate?**
   - Options: `Async (different timezones/schedules)` / `Mixed` / `Real-time co-located`
   - Note: For "Just me" in Q6, auto-set to `Solo` and skip

### Content & Maintenance
10. **Will non-developers create or maintain content?**
    - Options: `No, developers only` / `Technical writers` / `Non-technical staff` / `External contributors`

11. **How often will this be updated after initial build?**
    - Options: `Rarely (set and forget)` / `Monthly` / `Weekly` / `Continuous deployment`

12. **Who operates this in production?**
    - Options: `I do (creator-operated)` / `Dedicated ops team` / `Managed service/serverless` / `Not deployed (library/tool)`

### Audience
13. **Who uses this?**
    - Options: `Just me` / `Known small group (<100)` / `Medium audience (100-10K)` / `Large audience (10K+)` / `Other developers (library/API)`

14. **How diverse is your user base?**
    - Options: `Single persona (I know exactly who)` / `Few known types` / `Broad public (unknown diversity)`
    - Note: For "Just me" in Q13, auto-set to `Single persona` and skip

15. **What accessibility level is needed?**
    - Options: `Minimal (internal tool)` / `Standard (WCAG AA)` / `Strict (regulatory requirement)`
    - **Recommended:** Based on audience — broad public should default to Standard

16. **Where are your users?**
    - Options: `Single region` / `Multi-region` / `Global`

17. **What's the trust level of users?**
    - Options: `Internal/trusted` / `Authenticated external` / `Anonymous public`

### Stakes & Constraints
18. **What kind of data does this handle?**
    - Options: `Nothing sensitive` / `User accounts (email/password)` / `PII (names, addresses)` / `Financial` / `Health/medical` / `Regulated (specify)`

19. **What happens if this breaks?**
    - Options: `I'm annoyed` / `Users are inconvenienced` / `Workflow is blocked` / `Revenue impact` / `Safety risk`

20. **What availability is required?**
    - Options: `Best-effort` / `Business hours` / `24/7 with acceptable downtime` / `24/7 strict SLA`

21. **Any compliance requirements?**
    - Options: `None I know of` / `Internal company standards` / `Industry standard (OWASP, SOC2)` / `Legal mandate (GDPR, HIPAA, PCI-DSS)`

**Adaptive questioning**: Skip questions that are already answered by prior responses (e.g., if "Just me" for team size, skip stability and collaboration questions). Aim for the minimum necessary questions — do not ask all 21 if context is clear from earlier answers.

Record all answers in working memory. Do not write files yet.

## Act 3: Governance Calibration

**Goal**: Propose calibrated principle rigor levels based on the answers, then finalize the constitution.

### Step 1: Compute Rigor Levels

**First, derive two named calibration variables from Act 2 answers:**

```
BLAST_RADIUS = <low | medium | high>
  low    → "I'm annoyed" impact, personal/internal use, best-effort availability
  medium → Workflow blocked, small external audience, or revenue impact possible
  high   → Revenue/safety risk, SLA obligation, compliance required, 10K+ users

DATA_SENSITIVITY = <none | standard | sensitive>
  none      → Nothing sensitive, internal/trusted users only
  standard  → User accounts (email/password), authenticated external users
  sensitive → PII, financial, health, regulated data, or anonymous public users
```

Record these two values explicitly before proceeding. They are the primary drivers of security, adversarial review, and test rigor. Reference them by name in each principle decision below.

Using the collected answers (and the BLAST_RADIUS / DATA_SENSITIVITY variables), assign each principle a rigor level:

**Principle I: Specification Before Implementation**
- FULL: Team (6+), or audience 10K+, or revenue/safety impact
- STANDARD: Small team, or medium audience, or workflow-blocking impact
- LIGHTWEIGHT: Solo dev, personal use, annoyance-level impact

**Principle II: Simplicity**
- FULL: Junior-heavy team, or high turnover, or learning stack
- STANDARD: Mixed team, comfortable with stack
- LIGHTWEIGHT: Expert solo dev, stable team (simplicity still matters but less ceremony needed)

**Principle III: Test-Driven Development**
- FULL: Production status, or revenue/safety impact, or compliance required
- STANDARD: Active development, or workflow-blocking impact
- LIGHTWEIGHT: Prototype/experiment, personal use (still write tests but less strict red-green-refactor ceremony)
- Adapt description: LIGHTWEIGHT allows "write tests alongside implementation" instead of strict TDD

**Principle IV: Incremental & Independent Delivery**
- FULL: Team (6+), or continuous deployment, or multiple personas
- STANDARD: Small team, or weekly updates
- LIGHTWEIGHT: Solo dev, or rarely updated

**Principle V: Security by Default**
- FULL: DATA_SENSITIVITY = sensitive, or BLAST_RADIUS = high
- STANDARD: DATA_SENSITIVITY = standard, or BLAST_RADIUS = medium
- LIGHTWEIGHT: DATA_SENSITIVITY = none and BLAST_RADIUS = low (basics still apply: no secrets in code)
- Adapt additions: FULL adds threat modeling requirement; STANDARD adds input validation emphasis

**Principle VI: Documentation Stays Current**
- FULL: Large org, high turnover, or non-technical content creators
- STANDARD: Small team, moderate churn
- LIGHTWEIGHT: Solo dev, stable (CLAUDE.md + ADRs sufficient, skip runbooks)
- Adapt description based on team context

**Principle VII: Decision Transparency**
- FULL: Team (6+), or high turnover, or compliance required (ALWAYS NON-NEGOTIABLE for teams)
- STANDARD: Small team (ADRs for major decisions, LOGs optional for minor ones)
- LIGHTWEIGHT: Solo dev (ADRs for decisions you'd forget in 6 months)

**Principle VIII: Adversarial Review**
- FULL: Team (6+), or BLAST_RADIUS = high, or DATA_SENSITIVITY = sensitive
- STANDARD: Small team, or BLAST_RADIUS = medium, or DATA_SENSITIVITY = standard
- SKIP: Solo dev AND BLAST_RADIUS = low AND DATA_SENSITIVITY = none AND prototype — offer but don't require
- Adapt description: FULL runs all panels; STANDARD runs targeted panels; LIGHTWEIGHT runs devil's advocate only

**PR Policy calibration**:
- Solo/small team: 500 LOC limit (or no hard limit for solo)
- Team (6+): 300 LOC limit
- Large org: 200 LOC limit

### Step 2: Present Calibration

Present the proposed calibration as a clear summary:

```
Based on your project context, here's my proposed governance calibration:

FULL RIGOR (non-negotiable for your context):
  ✦ [Principle]: [1-sentence reason tied to their answers]

STANDARD (apply consistently, proportionally):
  ✦ [Principle]: [1-sentence reason]

LIGHTWEIGHT (acknowledge, adapt to your scale):
  ✦ [Principle]: [1-sentence reason]

SUGGESTED ADDITIONS for your context:
  ✦ [Any project-specific principles]: [reason]

PR POLICY: [N] lines per PR

Do you agree with this calibration? You can:
- Accept as-is
- Promote/demote any principle
- Add project-specific principles
- Adjust the PR limit
```

Wait for user confirmation. Iterate if they want changes.

### Step 3: Handle Project-Specific Principles

Ask if there are any domain-specific principles to add beyond the standard 8. Examples:
- API Contracts: All endpoints defined in contracts/ before implementation
- Mobile-First: Every UI decision validated on smallest supported screen size
- Offline-First: Features must degrade gracefully without network
- i18n by Default: All user-facing strings externalized from day one

### Step 4: Generate Constitution

Using the template at `.specify/templates/constitution-template.md`, fill all placeholders:

- Replace all `[PROJECT_*]` tokens with Act 1 answers
- Replace all `[TEAM_*]`, `[CONTENT_*]`, `[AUDIENCE_*]`, `[DATA_*]`, etc. with Act 2 answers
- Replace all `[PRINCIPLE_*_RIGOR]` with computed rigor levels
- Replace `[TDD_DESCRIPTION]` — adapt based on rigor:
  - FULL: Standard strict TDD description (red-green-refactor, never implement before test)
  - STANDARD: TDD with pragmatic flexibility (test-first preferred, test-alongside acceptable for spikes)
  - LIGHTWEIGHT: Tests required but TDD ceremony relaxed (write tests, but order is flexible)
- Replace `[SECURITY_ADDITIONS]` — adapt based on rigor:
  - FULL: Add threat modeling requirement, OWASP checklist, dependency scanning
  - STANDARD: Add input validation emphasis
  - LIGHTWEIGHT: Empty (basics in the standard bullets suffice)
- Replace `[DOCUMENTATION_DESCRIPTION]` — adapt based on rigor:
  - FULL: CLAUDE.md + runbooks + API docs + onboarding guide
  - STANDARD: CLAUDE.md + ADRs + README updates
  - LIGHTWEIGHT: CLAUDE.md is sufficient; update when stack/structure changes
- Replace `[ADVERSARIAL_REVIEW_DESCRIPTION]` — adapt based on rigor or omit section if SKIP:
  - FULL: Full panel reviews at every gate; review synthesis required before proceeding
  - STANDARD: Targeted reviews (architecture panel after plan, delivery panel after tasks)
  - LIGHTWEIGHT: Devil's advocate only at pre-implementation gate
- Replace `[ADDITIONAL_PRINCIPLES]` with any project-specific principles from Step 3
- Replace `[PR_LOC_LIMIT]` with calibrated limit
- Set `[RATIFICATION_DATE]` to today's date
- Set version to appropriate number (1.0.0 for new, increment for update)

### Step 5: Version Management

If updating an existing constitution:
- Compare old and new content
- Determine version bump:
  - MAJOR: Principle removed or fundamentally redefined
  - MINOR: New principle, new section, or materially expanded guidance (including adding Project Context)
  - PATCH: Rigor level adjustments, wording clarifications
- Preserve the SYNC IMPACT REPORT format as HTML comment at top

### Step 6: Consistency Propagation

Read these files and verify alignment with updated principles:
- `.specify/templates/plan-template.md` — Constitution Check section matches principles
- `.specify/templates/spec-template.md` — scope/requirements alignment
- `.specify/templates/tasks-template.md` — task categorization reflects principle-driven types
- Agent persona files in `.claude/agents/` — verify they reference calibration correctly

### Step 7: Generate Project README

After the constitution is written, generate (or update) the project README.md.
By this point you have all the context needed: project name, purpose, stack,
team, audience, and governance calibration. If `brainstorm-notes.md` exists,
incorporate the problem statement and user personas.

**If README.md doesn't exist or contains only the setup placeholder**
(look for "will be generated after running `/speckit.constitution`"):
Generate a full project README with:

```markdown
# [Project Name]

[One-paragraph description from Project Identity]

## Quick Start

\`\`\`bash
# Install dependencies
[command — from stack if known, or placeholder]

# Run tests
[command]

# Start dev server
[command]
\`\`\`

## About

[2-3 sentences: what problem this solves, for whom, from Phase 1 / constitution]

## Development

This project uses Spec-Kit for spec-driven development with Claude Code.

### Workflow

\`\`\`
/speckit.brainstorm   — explore ideas
/speckit.specify      — write feature spec
/speckit.review       — adversarial review
/speckit.plan         — technical design
/speckit.tasks        — task breakdown
/speckit.implement    — build it
/speckit.audit        — verify consistency
/speckit.retro        — learn and adjust
\`\`\`

### Project Structure

[Directory tree based on actual project structure]

## Contributing

See \`CLAUDE.md\` for project context and
\`.specify/memory/constitution.md\` for governing principles.
```

**If README.md exists with project-specific content** (no placeholder marker):
Do NOT overwrite. Instead, offer to append a "Development" section with the
Spec-Kit workflow if it's missing. Present the suggested addition and let the
user approve.

### Step 8: Write and Report

1. Write the completed constitution to `.specify/memory/constitution.md`
2. Write or update README.md (from Step 7)
3. Produce a SYNC IMPACT REPORT as HTML comment at top of the constitution
4. Output a final summary:
   - New version and bump rationale
   - Project context summary (1-2 sentences)
   - Calibration summary table (principle → rigor level)
   - README status (generated / updated / skipped)
   - Files flagged for manual follow-up
   - Suggested commit message

Formatting & Style Requirements:
- Use Markdown headings exactly as in the template (do not demote/promote levels)
- Keep readability (<100 chars per line ideally)
- Single blank line between sections
- No trailing whitespace
- Rigor markers in brackets after principle names: `[RIGOR: FULL]`

If the user supplies partial updates (e.g., only changing audience scale), still perform calibration re-computation and version decision.

If critical info missing, insert `TODO(<FIELD_NAME>): explanation` and include in SYNC IMPACT REPORT.
