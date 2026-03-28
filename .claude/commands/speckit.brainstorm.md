---
description: Explore a vague project idea through structured brainstorming, decompose it into concrete features, and produce a prioritized roadmap ready for /speckit.specify.
handoffs:
  - label: Specify a Feature
    agent: speckit.specify
    prompt: Create a spec for this feature from the roadmap...
  - label: Set Up Constitution
    agent: speckit.constitution
    prompt: Set up the project constitution based on what we discovered during brainstorming...
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Goal

Take a vague project idea and transform it into a prioritized feature roadmap through structured brainstorming. This command sits BEFORE `/speckit.constitution` and `/speckit.specify` in the workflow — it's for when you have a wild idea but don't yet know the shape of the project.

The output is a `roadmap.md` file that lists concrete features, each ready to be individually specified with `/speckit.specify`.

**Re-entry support**: If `roadmap.md` already exists (from a prior brainstorm or `/speckit.retro`), load it and offer to:
- Add new features discovered since last session
- Re-prioritize based on what was learned during implementation
- Start from any phase (skip Problem Definition if it's already solid)

## Operating Principles

### Divergence Before Convergence

This is the most important rule. Brainstorming has two modes that MUST NOT be mixed:

- **Divergent mode**: Generate ideas. No judgment, no feasibility checks, no "but that won't work." Quantity over quality. Wild ideas welcome.
- **Convergent mode**: Evaluate, cluster, prioritize. Apply judgment rigorously.

Mixing these kills creativity. If an agent says "that's not feasible" during divergent ideation, it has failed its job.

### Interactive, Not Autonomous

This command is a guided conversation with the user. Each phase requires user input and validation before proceeding. Do not auto-advance through all phases — pause after each one.

### Language and Domain Agnostic

Do not assume any technology stack, platform, or domain. The brainstorm is about WHAT to build, not HOW to build it. Technology decisions come later in `/speckit.plan`.

### Incremental State Preservation

After EACH phase, write progress to `brainstorm-notes.md` in the output directory. This ensures no work is lost if the session ends mid-brainstorm. The notes file captures:
- Phase 1 → Problem Statement
- Phase 1.5 → Prior Art findings
- Phase 2 → Raw idea pool
- Phase 3 → Clusters, scores, dependencies
- Phase 4 → Final roadmap (also written as `roadmap.md`)

If `brainstorm-notes.md` exists from a prior session, offer to resume from where it left off.

## Execution: Six Phases

### Phase 1: Problem Definition

**Goal**: Understand what we're building and why, before generating any feature ideas.

This is an interactive conversation. Ask these questions ONE AT A TIME, adapting based on answers. Skip questions the user has already answered in `$ARGUMENTS`.

1. **What's the idea?** (one sentence — force brevity)
   - If the user wrote a paragraph, help them distill to one sentence
   - Example: "A tool that helps remote teams track architectural decisions"

2. **Who has this problem?**
   - Identify 2-4 user types / personas
   - For each: what's their role, what frustrates them today?
   - Example: "Tech leads who lose context on past decisions; new team members who don't know why things were built a certain way"

3. **What do they do today without your solution?**
   - Understand the current workarounds, pain points, and costs
   - This reveals the job-to-be-done and the bar you need to clear
   - Example: "Slack threads, lost Google Docs, tribal knowledge in senior devs' heads"

4. **What would success look like?**
   - Not features — outcomes. How would the world be different?
   - Push for measurable signals if possible
   - Example: "New team members can answer 'why was this built this way?' in under 5 minutes"

5. **What is this NOT?**
   - Explicit scope boundaries prevent feature creep later
   - Example: "Not a project management tool. Not a wiki. Not a code editor."

6. **Any constraints or strong opinions?**
   - Open-source? Specific platform? Budget? Timeline?
   - These don't shape features but will inform prioritization

After all questions are answered, produce a **Problem Statement Summary**:

```markdown
## Problem Statement

**Idea**: [one sentence]
**Users**: [2-4 personas with pain points]
**Current alternatives**: [what they do today]
**Success signal**: [measurable outcome]
**Not this**: [explicit boundaries]
**Constraints**: [if any]
```

Present this to the user for approval before proceeding. Iterate if needed.

**Write** the Problem Statement to `brainstorm-notes.md` before continuing.

**Constitution handoff**: This Problem Statement maps directly to the Project Context
section of the constitution. When the user later runs `/speckit.constitution`, reference
`brainstorm-notes.md` to pre-fill:
- Project Identity → from "Idea" and "Not this"
- Audience → from "Users"
- Stakes & Constraints → from "Constraints" and "Success signal"

### Phase 1.5: Prior Art Scan

**Goal**: Understand what already exists before generating ideas, so brainstorming is informed rather than naive.

Use web search (if available) or ask the user to identify:

1. **Existing solutions** — What tools/products attempt to solve this problem today?
   - Search for 3-5 existing alternatives
   - For each: what do they do well? What do they miss?

2. **Adjacent solutions** — What tools do people cobble together as workarounds?
   - These reveal unmet needs and integration opportunities

3. **What's been tried and failed?** — Any known dead products in this space?
   - Understanding failures prevents repeating them

Present findings as a brief landscape summary:

```markdown
## Prior Art

| Solution | What it does well | What it misses | Our opportunity |
|----------|------------------|----------------|-----------------|
```

The user can add to this, correct misconceptions, or skip if they already know the landscape.

**Append** to `brainstorm-notes.md` before continuing.

**Feed into ideation**: Share the Prior Art summary with all brainstorming agents so their ideas build on gaps rather than reinventing what exists.

### Phase 2: Divergent Ideation

**Goal**: Generate 30-50 raw feature ideas from multiple perspectives. NO JUDGMENT.

This phase uses a **brainwriting rotation** pattern. If Agent Teams are available (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1), spawn teammates. If not, simulate the rotation sequentially.

Each agent receives the Problem Statement AND the Prior Art scan, with this framing:
```
Here's what already exists in this space: [Prior Art summary]
Your ideas should fill gaps, combine strengths, or take entirely new approaches.
Do NOT just copy existing solutions. Build on what's missing.
```

#### Round 1: Visionary
```
You are a visionary product thinker. Given this problem statement and prior art:
[Problem Statement + Prior Art from Phase 1/1.5]

Generate 8-10 feature ideas with NO constraints. What would be amazing?
Think big. Ignore feasibility, cost, and timeline.
Format: one line per idea, no evaluation, no caveats.
```

#### Round 2: User Advocate
```
You are a user advocate. Here's the problem statement, prior art, and the visionary's ideas:
[Problem Statement + Prior Art + Round 1 ideas]

Now generate 8-10 feature ideas focused on daily user needs.
What would make users' lives easier? What would they use every day?
You may build on, combine, or contradict the visionary's ideas.
Add your own fresh ideas too.
Format: one line per idea, no evaluation.
```

#### Round 3: Technologist
```
You are a technologist. Here's everything so far:
[Problem Statement + Prior Art + Round 1 + Round 2 ideas]

Generate 8-10 feature ideas focused on what's technically interesting.
What would be elegant to build? What enables other features?
What infrastructure or platform capabilities would unlock value?
Build on previous ideas or add entirely new ones.
Format: one line per idea, no evaluation.
```

#### Round 4: Provocateur
```
You are a provocateur and lateral thinker. Here's everything so far:
[Problem Statement + Prior Art + Round 1 + Round 2 + Round 3 ideas]

Generate 8-10 feature ideas by inverting assumptions.
What if we did the opposite? What's the contrarian approach?
What would our competitors never do? What's the "lazy" solution that might actually be better?
Challenge the framing. Surprise us.
Format: one line per idea, no evaluation.
```

After all rounds, compile the **full idea pool** (30-50 ideas) and present to the user:

```
We generated [N] raw ideas across 4 perspectives:
- Visionary: [count]
- User Advocate: [count]
- Technologist: [count]
- Provocateur: [count]

[Full numbered list]

Take a moment to scan these. You can:
- Add your own ideas to the list
- Star (*) any that immediately resonate
- Cross out (x) any that are clearly wrong for your project
- Or just say "proceed" to move to clustering
```

**Append** raw idea pool to `brainstorm-notes.md`.

Wait for user input before proceeding.

### Phase 3: Clustering & Prioritization

**Goal**: Organize raw ideas into feature groups and prioritize them.

#### Step 1: Affinity Clustering

Group the surviving ideas (after user review) into 6-12 thematic clusters:

```markdown
### Cluster: [Name]
**Theme**: [one sentence description]
**Ideas included**: [list of idea numbers]
**Potential feature**: [synthesized feature description]
```

Present clusters to the user. They may:
- Merge clusters
- Split clusters
- Rename clusters
- Move ideas between clusters

#### Step 2: MoSCoW Classification

For each cluster/feature, ask the user to classify:

```
For each feature, I need your gut reaction:

1. [Feature name] — [one line description]
   Must / Should / Could / Won't?

2. [Feature name] — [one line description]
   Must / Should / Could / Won't?
...
```

**Guidelines to share with the user:**
- **Must Have**: The project fails without this. Users won't adopt it.
- **Should Have**: Important, but v1 can ship without it. High value for v2.
- **Could Have**: Nice to have. Include if easy, defer if not.
- **Won't Have (this version)**: Explicitly out of scope. May revisit later.

**Scope feedback** (soft guidance, not a hard cap):
- If >7 features are "Must Have": "That's a lot of must-haves — MVP scope creep is the #1 project killer. Could any of these ship in v2 without losing core value?"
- If >15 features total across Must+Should: "This is an ambitious roadmap. Consider whether you can validate the core idea with fewer features first."
- If 0 features are "Won't Have": "Saying 'no' to things is how good products stay focused. Is there anything you could explicitly defer?"

These are suggestions, not requirements. Respect the user's final classification.

#### Step 3: Feasibility Gut-Check

Before scoring, do a quick sanity check on the Must Have features:

For each Must Have feature, the technologist agent (or lead) provides a one-line feasibility note:
- **Straightforward**: Well-understood problem, standard approaches exist
- **Moderate**: Some unknowns, but achievable with reasonable effort
- **Exploratory**: Significant unknowns, may need a spike/prototype first
- **Risky**: Novel territory, high chance of unexpected complexity

Present these to the user. Any feature marked "Risky" should prompt:
"This feature has significant unknowns. Consider: (a) keep it in MVP but plan a spike first, (b) move it to Should Have and validate the core idea without it, or (c) keep as-is."

This is informational — the user decides.

#### Step 4: Impact vs. Effort Scoring

For each Must and Should feature, score on two dimensions:

| Feature | Impact (1-5) | Effort (1-5) | Feasibility | Priority Score |
|---------|-------------|-------------|-------------|----------------|

**Impact**: How much does this move the needle on the success signal from Phase 1?
**Effort**: Relative complexity (1=trivial, 5=major undertaking)
**Feasibility**: From Step 3 (Straightforward/Moderate/Exploratory/Risky)
**Priority Score**: Impact / Effort (higher = do first)

The user provides impact scores (they know their domain). You estimate relative effort based on typical complexity for features like these. User can override.

#### Step 5: Dependency Mapping

Identify which features depend on others:
- "Search requires a data model, so data storage comes first"
- "Collaboration requires user auth"
- "Export requires the core feature to exist"

Flag any circular dependencies or features that block many others (these are infrastructure features that should come early).

**Append** clusters, MoSCoW, scores, and dependencies to `brainstorm-notes.md`.

### Phase 4: Feature Roadmap

**Goal**: Produce a `roadmap.md` file that feeds directly into `/speckit.specify`.

#### Step 1: Determine Output Location

- If a project constitution exists, create `specs/roadmap.md`
- If no constitution yet, create `roadmap.md` at project root (will be moved later)
- If the user specifies a location, use that

#### Step 2: Generate Roadmap

```markdown
# [Project Name] Feature Roadmap

**Generated**: [YYYY-MM-DD]
**Last Updated**: [YYYY-MM-DD]
**Status**: [Initial brainstorm / Updated after Phase N implementation]
**Problem Statement**: [one sentence from Phase 1]
**Success Signal**: [from Phase 1]

## Prior Art

| Solution | Strength | Gap | Our Approach |
|----------|----------|-----|-------------|

## Phase 1: MVP (Must Have)

Features required for the minimum viable product. Each is a vertical slice
delivering testable user value.

| # | Feature | Description | Depends On | Effort | Feasibility |
|---|---------|-------------|------------|--------|-------------|
| 001 | [name] | [one sentence] | — | [1-5] | [S/M/E/R] |
| 002 | [name] | [one sentence] | 001 | [1-5] | [S/M/E/R] |

### Feature Details

#### 001-[feature-name]
**User value**: [what the user gets]
**Key scenarios**: [2-3 bullet points of what this enables]
**Success criteria**: [how we know it works]
**Personas served**: [which user types benefit]
**Assumptions**: [what we believe to be true — revisit in /speckit.retro]

#### 002-[feature-name]
...

## Phase 2: Growth (Should Have)

Features that add significant value after MVP is validated.

| # | Feature | Description | Depends On | Effort | Feasibility |
|---|---------|-------------|------------|--------|-------------|

### Feature Details
...

## Phase 3: Differentiation (Could Have)

Features that differentiate from alternatives. Build when core is solid.

| # | Feature | Description | Depends On | Effort | Feasibility |
|---|---------|-------------|------------|--------|-------------|

### Feature Details
...

## Deferred (Won't Have — This Version)

Explicitly excluded for now. Revisit in future planning.

| Feature | Reason Deferred |
|---------|----------------|

## Revision History

| Date | Change | Trigger |
|------|--------|---------|
| [YYYY-MM-DD] | Initial brainstorm | /speckit.brainstorm |

## Brainstorm Artifacts

### Problem Statement
[Full problem statement from Phase 1]

### User Personas
[Persona details from Phase 1]

### Prior Art Scan
[Full prior art findings from Phase 1.5]

### Raw Idea Pool
[Full list of generated ideas, preserved for future reference]

### Clustering Summary
[Cluster names and which ideas mapped to which features]
```

#### Step 3: Present and Confirm

Show the roadmap to the user. They can:
- Reorder features
- Move features between phases
- Add features they thought of during the process
- Remove features
- Adjust effort estimates

#### Step 4: Write Files

Write `roadmap.md` to the determined location.
Write or update `brainstorm-notes.md` with final state.

#### Step 5: Suggest Next Steps

```
Roadmap complete! Here's what to do next:

1. Run `/speckit.constitution` to set up project governance
   (the problem statement and personas from brainstorming will inform
   the Project Context section — I'll reference brainstorm-notes.md
   to pre-fill your answers)

2. Pick the first MVP feature and run `/speckit.specify [feature name]`
   to create a detailed specification

3. Continue through the spec-kit workflow:
   specify → review → clarify → plan → review → tasks → implement

4. After implementing a phase, run `/speckit.retro` to reassess
   assumptions and update the roadmap based on what you learned

Suggested first feature: [highest priority, lowest effort, no dependencies]
```

## Behavior Rules

- NEVER evaluate ideas during Phase 2 (divergent ideation). No "that's not feasible," no "that's too complex," no "users won't want that." Save all judgment for Phase 3.
- ALWAYS wait for user input between phases. Do not auto-advance.
- Keep feature descriptions technology-agnostic. "User authentication" not "JWT-based OAuth2 with bcrypt."
- Feature numbering (001, 002...) aligns with spec-kit's `###-feature-name` convention.
- If the user's idea is very small (single feature, not a product), skip Phase 2 and go directly to helping them refine it for `/speckit.specify`.
- If the user already has a partial feature list, start from Phase 3 (clustering) with their existing ideas.
- Preserve ALL raw ideas in the roadmap — even rejected ones. Future brainstorms may revisit them.
- Write `brainstorm-notes.md` incrementally after each phase for session continuity.
- Scope feedback is advisory — inform the user of risks but respect their decisions.

## Context

$ARGUMENTS
