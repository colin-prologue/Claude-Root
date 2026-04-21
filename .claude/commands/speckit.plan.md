---
description: Execute the implementation planning workflow using the plan template to generate design artifacts.
handoffs: 
  - label: Create Tasks
    agent: speckit.tasks
    prompt: Break the plan into tasks
    send: true
  - label: Create Checklist
    agent: speckit.checklist
    prompt: Create a checklist for the following domain...
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

1. **Setup**: Run `.specify/scripts/bash/setup-plan.sh --json` from repo root and parse JSON for FEATURE_SPEC, IMPL_PLAN, SPECS_DIR, BRANCH.

2. **Load context**: Read FEATURE_SPEC and `.specify/memory/constitution.md`. Load IMPL_PLAN template (already copied).

2.5. **Memory recall**: Read `.specify/memory/constitution.md` and parse its YAML front-matter block (lines between the opening `---` and the next `---`). If the key `memory_enabled` is present and its value is exactly `false`, skip all `memory_recall` and `memory_store` calls in this skill run. If the key is absent or the file cannot be read, proceed normally (treat as `memory_enabled: true`). When enabled, call `memory_recall("technology choices architecture decisions prior ADRs")` and use surfaced decisions as context for Phase 0 research.

3. **Execute plan workflow**: Follow the structure in IMPL_PLAN template to:
   - Fill Technical Context (mark unknowns as "NEEDS CLARIFICATION")
   - Fill Constitution Check section from constitution
   - Evaluate gates (ERROR if violations unjustified)
   - Phase 0: Generate research.md (resolve all NEEDS CLARIFICATION)
   - Phase 1: Generate data-model.md, contracts/, quickstart.md
   - Phase 1: Update agent context by running the agent script
   - Re-evaluate Constitution Check post-design

4. **Memory store + stop and report**: If `memory_enabled` was not `false` in step 2.5, call `memory_store` with a 2-5 sentence summary of the key technology choices and architectural decisions in the plan; use `section: "speckit.plan summary"` and metadata per `memory-convention.md`. Then report branch, IMPL_PLAN path, and generated artifacts.

## Phases

### Phase 0: Outline & Research

1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task

2. **Generate and dispatch research agents**:

   ```text
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

4. **Create Decision Records** (Principle VII — NON-NEGOTIABLE):
   - For each technology choice or architectural decision recorded in research.md:
     - Determine the next available NNN by scanning `.specify/memory/` for existing `ADR_NNN_*` and `LOG_NNN_*` files (shared counter)
     - Create `ADR_NNN_title.md` in `.specify/memory/` using `.specify/templates/adr-template.md`
     - Set `Decision Made In` to the plan.md path and section
   - For each unresolved question or open challenge surfaced during research:
     - Create `LOG_NNN_title.md` in `.specify/memory/` using `.specify/templates/log-template.md`
   - Update the `## Decision Records` table in `plan.md` with all new ADR/LOG entries
   - **ERROR and stop if any technology choice in research.md lacks a corresponding ADR before Phase 1 begins**

**Output**: research.md with all NEEDS CLARIFICATION resolved; ADR/LOG files written to `.specify/memory/`

### Phase 1: Design & Contracts

**Prerequisites — ADR GATE (hard stop):**
Before doing any Phase 1 work, verify:
1. `research.md` exists and all NEEDS CLARIFICATION items are resolved
2. Every technology choice listed in `research.md` has a corresponding `ADR_NNN_*.md` in `.specify/memory/`

If any technology choice lacks an ADR: **ERROR and stop**. Do not proceed to design until all ADRs are written. List the missing ADRs explicitly so the user can see what's blocking.

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Define interface contracts** (if project has external interfaces) → `/contracts/`:
   - Identify what interfaces the project exposes to users or other systems
   - Document the contract format appropriate for the project type
   - Examples: public APIs for libraries, command schemas for CLI tools, endpoints for web services, grammars for parsers, UI contracts for applications
   - Skip if project is purely internal (build scripts, one-off tools, etc.)

3. **Agent context update**:
   - Run `.specify/scripts/bash/update-agent-context.sh claude`
   - These scripts detect which AI agent is in use
   - Update the appropriate agent-specific context file
   - Add only new technology from current plan
   - Preserve manual additions between markers

4. **Create Decision Records for design choices** (Principle VII):
   - For any architectural decision made during data modeling or contract definition
     (e.g., schema design, normalization choices, API versioning, data format selection):
     - Determine next available NNN from `.specify/memory/` (shared ADR/LOG counter)
     - Create `ADR_NNN_title.md` in `.specify/memory/` using `.specify/templates/adr-template.md`
   - Update the `## Decision Records` table in `plan.md` with all new entries

**Output**: data-model.md, /contracts/*, quickstart.md, agent-specific file, ADR files for design decisions

## Key rules

- Use absolute paths
- ERROR on gate failures or unresolved clarifications
