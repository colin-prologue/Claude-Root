# Superpowers Plugin + Spec-Kit Integration Research

**Date**: 2026-04-17
**Branch**: `claude/research-superpowers-integration-so5uv`
**Status**: Research complete — awaiting decision

---

## 1. Executive Summary

The **Superpowers** plugin (by obra, Anthropic marketplace-approved) and your **Spec-Kit** framework are highly complementary with minimal overlap. Superpowers excels at *micro-level development discipline* (TDD enforcement, systematic debugging, 2-5 minute task granularity). Spec-Kit excels at *macro-level governance* (multi-persona adversarial review, ADR tracking, doc-code audit, semantic memory). Integrating both gives you disciplined code-level execution inside a governed specification-to-delivery pipeline.

**Key finding**: No slash command conflicts exist (`speckit.*` vs superpowers' skill-based activation). The two systems can coexist with targeted wiring at 3-4 integration points.

---

## 2. Superpowers Inventory

### 2.1 Skills (14 total)

| Skill | Purpose | Activation |
|-------|---------|------------|
| `using-superpowers` | Master orchestrator; routes to other skills | Always (entry point) |
| `brainstorming` | Socratic 9-step design refinement | Before any creative work |
| `writing-plans` | Micro-task breakdown (2-5 min units) | After approved design |
| `executing-plans` | Batch execution with human checkpoints | With plan |
| `subagent-driven-development` | Per-task subagent dispatch + two-stage review | With plan (alternative to executing-plans) |
| `dispatching-parallel-agents` | Concurrent subagent workflows | When tasks are parallelizable |
| `test-driven-development` | Strict RED-GREEN-REFACTOR with restart enforcement | All features, bug fixes, refactors |
| `systematic-debugging` | 4-phase root cause analysis | Any technical issue |
| `verification-before-completion` | Post-fix validation gate | After any fix |
| `requesting-code-review` | Pre-review checklist validation | Before submitting for review |
| `receiving-code-review` | Feedback response handling | After receiving review |
| `using-git-worktrees` | Parallel branch isolation | After design approval |
| `finishing-a-development-branch` | Merge/PR decision workflow | End of feature |
| `writing-skills` | Meta-skill: author new skills using TDD | When creating new skills |

### 2.2 Agents

| Agent | Role |
|-------|------|
| `code-reviewer` | Single code quality reviewer (spec compliance + craftsmanship) |

### 2.3 Slash Commands

| Command | Status |
|---------|--------|
| `/brainstorm` | Deprecated → use brainstorming skill |
| `/write-plan` | Deprecated → use writing-plans skill |
| `/execute-plan` | Deprecated → use executing-plans skill |

### 2.4 Key Design Principles

- **Auto-activation**: Skills trigger on context detection (even 1% likelihood)
- **Instruction hierarchy**: User directives > Superpowers skills > Default system prompt
- **Rationalization defense**: 9 "red flag" patterns that signal skill bypass attempts
- **TDD is absolute**: Code before test = delete and restart. No exceptions.
- **Micro-tasks**: Every plan item is 2-5 minutes with exact file paths and verification steps

---

## 3. Spec-Kit Inventory

### 3.1 Slash Commands (16 total)

| Command | Purpose |
|---------|---------|
| `speckit.brainstorm` | Multi-persona divergent ideation → roadmap.md |
| `speckit.constitution` | Interactive project governance setup |
| `speckit.specify` | User stories, requirements, success criteria |
| `speckit.clarify` | Resolve spec ambiguities (up to 5 questions) |
| `speckit.checklist` | Custom quality checklist for feature |
| `speckit.plan` | Technical approach + research + ADRs |
| `speckit.tasks` | Dependency-ordered task breakdown |
| `speckit.analyze` | Cross-artifact consistency check |
| `speckit.implement` | Execute tasks from tasks.md |
| `speckit.codereview` | Multi-persona adversarial code review |
| `speckit.audit` | Bidirectional doc↔code consistency audit |
| `speckit.review` | Multi-persona adversarial review at any gate |
| `speckit.review-profile` | Benchmark review panel efficiency |
| `speckit.retro` | Post-implementation retrospective |
| `speckit.taskstoissues` | Convert tasks to GitHub issues |
| `speckit.init` | Initialize Spec-Kit template in repo |

### 3.2 Agent Personas (13 total)

| Agent | Model | Focus |
|-------|-------|-------|
| `product-strategist` | Sonnet | User value, requirements completeness |
| `systems-architect` | Sonnet | Scalability, modularity, technical design |
| `security-reviewer` | Sonnet | Vulnerabilities, threat vectors, data protection |
| `delivery-reviewer` | Sonnet | Dependencies, risk, test coverage |
| `operational-reviewer` | Sonnet | Observability, failure modes, rollback |
| `devils-advocate` | Opus | Assumption challenges, hidden risks |
| `synthesis-judge` | Opus | Integrates findings, preserves dissent |
| `code-reviewer` | Sonnet | Correctness, test quality, ADR compliance |
| `consistency-auditor` | Opus | Bidirectional doc-code drift |
| `visionary` | Sonnet | Unconstrained creative ideation |
| `user-advocate` | Sonnet | Daily user needs, pain points |
| `technologist` | Sonnet | Elegant solutions, platform capabilities |
| `provocateur` | Sonnet | Lateral thinking, assumption inversion |

### 3.3 Unique Capabilities (not in Superpowers)

- **Memory Server (MCP)**: LanceDB + Ollama semantic vector search over ADRs, specs, and decision records. Recall-before/store-after convention for cross-session knowledge.
- **Constitution-driven governance**: Calibrated rigor levels (FULL/STANDARD/LIGHTWEIGHT) per review gate, benchmark-validated.
- **3-phase anti-convergence reviews**: Independent analysis → cross-examination → synthesis with preserved dissent.
- **ADR/LOG decision record system**: Sequential numbering, hard gates blocking implementation without ADRs.
- **Bidirectional audit with health scoring**: A-F grade across 5 dimensions.
- **Extension hooks**: `.specify/extensions.yml` for pre/post-implement hooks.

---

## 4. Head-to-Head Comparison

### 4.1 Capability Matrix

| Capability | Spec-Kit | Superpowers | Verdict |
|------------|----------|-------------|---------|
| **Brainstorming** | 4-persona divergent panel → prioritized roadmap | Single-agent Socratic 9-step → design doc | Different scope: Spec-Kit decomposes products; Superpowers refines single features |
| **Planning** | plan.md + research.md + ADRs + data-model | 2-5 min micro-tasks with exact code blocks | Complementary layers: Spec-Kit = architecture; Superpowers = execution granularity |
| **Task breakdown** | tasks.md with phases, dependencies, [P] markers | Writing-plans with verification steps per task | Spec-Kit is higher level; Superpowers goes atomic |
| **TDD enforcement** | "Tests before code (NON-NEGOTIABLE)" in implement | Strict RED-GREEN-REFACTOR with delete/restart rules, anti-pattern catalog | **Superpowers is significantly stronger** — rationalization defense, restart enforcement |
| **Implementation** | Phase-by-phase from tasks.md, extension hooks | Subagent-per-task with inline two-stage review | Different models: Spec-Kit = orchestrated; Superpowers = distributed |
| **Debugging** | None | 4-phase systematic debugging + root cause tracing | **Gap in Spec-Kit** — Superpowers fills it entirely |
| **Code review** | 3-phase adversarial panel (2-7 reviewers + synthesis judge) | Single code-reviewer agent, two-stage (spec then quality) | **Spec-Kit is far richer** — multi-persona, anti-convergence, severity calibration |
| **Doc-code audit** | 5-dimension health score, decision record discovery | None | **Unique to Spec-Kit** |
| **Adversarial review** | Multi-gate panels with devil's advocate + synthesis | None | **Unique to Spec-Kit** |
| **Decision records** | ADR/LOG system with hard gates, sequential numbering | None | **Unique to Spec-Kit** |
| **Semantic memory** | LanceDB + Ollama MCP server, recall-before/store-after | None | **Unique to Spec-Kit** |
| **Constitution/governance** | Calibrated rigor levels, benchmark-validated defaults | None | **Unique to Spec-Kit** |
| **Git workflow** | Branch-per-feature (`###-feature-name`) | Git worktrees for parallel isolation | Superpowers adds parallel workspace capability |
| **Verification** | Completion validation in implement step 10 | Dedicated verification-before-completion skill | Superpowers is more systematic |
| **Meta/extensibility** | Extension hooks in extensions.yml | writing-skills meta-skill (TDD for process docs) | Both extensible, different mechanisms |
| **Auto-activation** | Explicit slash command invocation | Context-detected, mandatory skill checks | Fundamentally different activation models |

### 4.2 Where Superpowers Fills Spec-Kit Gaps

1. **TDD discipline** — Spec-Kit says "tests first" but has no enforcement teeth. Superpowers adds: rationalization defense, delete-and-restart rules, anti-pattern catalog, mandatory RED verification before GREEN.

2. **Systematic debugging** — Spec-Kit has no debugging methodology. When tests fail during `/speckit.implement`, there's no structured approach. Superpowers' 4-phase debugging fills this completely.

3. **Micro-task granularity** — Spec-Kit's tasks.md breaks work into phases with multi-step tasks. Superpowers decomposes further into 2-5 minute units with exact code, exact commands, exact expected output. This reduces agent drift during long implementation sessions.

4. **Verification-before-completion** — Spec-Kit's implement command validates at the phase level. Superpowers adds per-fix, per-task verification as a standalone skill.

5. **Git worktrees** — Spec-Kit uses branch-per-feature. Superpowers adds worktree isolation for parallel development without branch switching.

### 4.3 Where Spec-Kit Is Stronger (Keep These)

1. **Multi-persona adversarial review** — Superpowers has one code-reviewer. Spec-Kit has 7+ specialized reviewers with a 3-phase anti-convergence protocol. This is dramatically more thorough.

2. **ADR/LOG decision tracking** — No equivalent in Superpowers. Hard gates that block implementation without documented decisions prevent architectural drift.

3. **Semantic memory** — Cross-session recall of prior decisions, review findings, and plan summaries. Superpowers has no memory mechanism.

4. **Bidirectional audit** — Doc-code consistency checking with health scoring. Nothing comparable in Superpowers.

5. **Constitution-driven calibration** — Rigor levels that scale review intensity to project context. Superpowers is one-size-fits-all.

6. **Brainstorming at product scale** — Spec-Kit's 4-persona divergent ideation with MoSCoW prioritization and dependency mapping produces roadmaps. Superpowers' brainstorming refines a single feature into a design doc.

---

## 5. Integration Architecture

### 5.1 No Namespace Conflicts

Spec-Kit commands: `speckit.*` (16 commands)
Superpowers: skill-based activation (no slash commands in active use)

These can coexist without any renaming. Superpowers' deprecated `/brainstorm`, `/write-plan`, `/execute-plan` commands won't conflict with `speckit.brainstorm`, `speckit.plan`, `speckit.implement`.

### 5.2 Recommended Integration Points

#### Integration Point 1: TDD Enforcement in `/speckit.implement`

**Current state**: Step 8 says "Tests before code (NON-NEGOTIABLE)" but relies on the implementing agent's discipline.

**With Superpowers**: Invoke the `test-driven-development` skill during task execution. This adds:
- Mandatory RED phase verification (test must fail for the right reason)
- Delete-and-restart if code is written before test
- Anti-rationalization patterns ("too simple to test", "I'll test after")
- YAGNI enforcement during GREEN phase

**Mechanism**: Add a reference in `speckit.implement.md` step 8:
```
When writing code for any task, follow the superpowers test-driven-development skill:
RED → verify fail → GREEN → verify pass → REFACTOR. No exceptions.
```

#### Integration Point 2: Systematic Debugging When Tests Fail

**Current state**: When a test fails during implementation, there's no structured debugging approach.

**With Superpowers**: Invoke `systematic-debugging` skill when:
- A test fails unexpectedly during implementation
- 2+ fix attempts fail for the same issue
- Integration tests break after passing unit tests

**Mechanism**: Add to `speckit.implement.md` error handling (step 9):
```
If a task fails after 2 fix attempts, invoke the systematic-debugging skill:
Phase 1: Root cause investigation (gather evidence, no fixes)
Phase 2: Pattern analysis (find working examples, compare)
Phase 3: Hypothesis testing (one variable at a time)
Phase 4: Implementation (failing test first, then fix)
```

#### Integration Point 3: Micro-Task Decomposition

**Current state**: `speckit.tasks` produces phase-level tasks with dependencies and [P] markers.

**With Superpowers**: Use `writing-plans` to decompose each spec-kit task into 2-5 minute atomic units during execution.

**Two options**:
- **Option A (Recommended)**: Keep `speckit.tasks` for the high-level breakdown. During `speckit.implement`, decompose each task into micro-steps using the writing-plans pattern (exact files, exact code, exact commands).
- **Option B**: Replace `speckit.tasks` entirely with superpowers' `writing-plans`. Risk: loses dependency mapping, [P] markers, and phase structure.

#### Integration Point 4: Verification Before Task Completion

**Current state**: `speckit.implement` marks tasks complete (`[X]`) after execution.

**With Superpowers**: Run `verification-before-completion` before marking any task done:
- Confirm the fix actually works (not just "tests pass")
- Check for side effects
- Verify against the original requirement

#### Integration Point 5 (Optional): Subagent-Driven Task Execution

**Current state**: `speckit.implement` executes tasks sequentially/parallel within the main session.

**With Superpowers**: For [P]-marked parallel tasks, use `subagent-driven-development` to dispatch fresh subagents per task with two-stage review. This is especially valuable for large features with many independent tasks.

**Tradeoff**: Subagent dispatch loses the main session's context. Works best for well-specified tasks with clear boundaries. May conflict with Spec-Kit's ADR gate (subagents need ADR context injected).

### 5.3 What NOT to Integrate

| Superpowers Feature | Why Skip |
|---------------------|----------|
| `brainstorming` skill | `speckit.brainstorm` is more powerful (4 personas, roadmap output, MoSCoW, dependency mapping). Use superpowers brainstorming only for quick single-feature design refinement outside the spec-kit workflow. |
| `code-reviewer` agent | `speckit.codereview` has 3-7 specialized reviewers + synthesis judge. Superpowers' single reviewer would be a downgrade. |
| `requesting-code-review` / `receiving-code-review` | These manage review submission flow. Spec-Kit's `/speckit.codereview` handles the full lifecycle. |
| `finishing-a-development-branch` | Spec-Kit's Definition of Done + `/speckit.retro` is more comprehensive. |
| Auto-activation behavior | Superpowers skills auto-trigger on context detection. This could conflict with Spec-Kit's explicit workflow ordering. **Disable auto-activation** for skills that overlap with spec-kit commands. |

### 5.4 Activation Model Tension

This is the biggest integration risk. Superpowers' core principle is: "Invoke relevant skills BEFORE any response or action — even at 1% likelihood." Spec-Kit uses explicit slash command invocation in a defined order.

**Resolution**: Configure superpowers to respect spec-kit's workflow phases:
- During `speckit.implement`: Allow TDD, debugging, verification, and micro-task skills to auto-activate
- During `speckit.review`/`speckit.codereview`/`speckit.audit`: Suppress superpowers skills (these phases are spec-kit's domain)
- During ad-hoc coding (no active spec-kit phase): Let superpowers auto-activate freely

---

## 6. Implementation Plan

### Phase 1: Install and Test (Low risk)

1. Install superpowers plugin: `claude plugin install obra/superpowers`
2. Verify no command conflicts
3. Test TDD skill on a small standalone task (outside spec-kit workflow)
4. Test systematic-debugging skill on a known bug

### Phase 2: Wire Integration Points (Medium risk)

1. Add TDD enforcement reference to `speckit.implement.md` (Integration Point 1)
2. Add debugging fallback to `speckit.implement.md` (Integration Point 2)
3. Add verification gate to `speckit.implement.md` (Integration Point 4)
4. Test full spec-kit workflow with superpowers skills active

### Phase 3: Advanced Integration (Higher risk, optional)

1. Add micro-task decomposition (Integration Point 3)
2. Experiment with subagent-driven development for [P] tasks (Integration Point 5)
3. Create extensions.yml hooks to trigger superpowers skills at implement boundaries
4. Store superpowers design docs through memory server for recall

### Phase 4: Tune Activation Boundaries

1. Document which superpowers skills should auto-activate and when
2. Create a `.claude/rules/superpowers-integration.md` with activation policy
3. Test combined workflow end-to-end on a real feature

---

## 7. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Auto-activation conflicts with spec-kit workflow order | High | Medium | Activation policy rules file |
| TDD restart rule deletes code during spec-kit implementation | Medium | High | Scope TDD enforcement to individual tasks, not phases |
| Superpowers brainstorming overrides speckit.brainstorm | Low | Medium | Skip brainstorming skill; keep speckit.brainstorm |
| Dual code-reviewer agents produce conflicting reviews | Low | Low | Skip superpowers code-reviewer; keep speckit.codereview panel |
| Token budget inflation from loading 14 skills + 16 commands | Medium | Medium | Superpowers skills load on demand; monitor context usage |
| Subagent dispatch loses ADR context | Medium | High | Inject ADR content into subagent prompts explicitly |

---

## 8. Recommendation

**Install superpowers and integrate at 3 points** (TDD, debugging, verification). This gives you the biggest value with the lowest risk:

- Your TDD enforcement gets real teeth (rationalization defense, restart rules)
- You gain systematic debugging (currently a gap)
- Task completion gets an explicit verification gate

Skip: brainstorming, code review, branch finishing, and auto-activation of overlapping skills. Your spec-kit versions are stronger in these areas.

**Next step**: Say the word and I'll install the plugin and wire the integration points into `speckit.implement.md`.

---

## 9. Deep Dive: Implementation Approach Trade-Offs

### 9.1 What You Lose Using Superpowers' Execution Instead of Spec-Kit's

If you replaced `speckit.implement` with superpowers' `executing-plans` or `subagent-driven-development`:

| Spec-Kit Capability Lost | Consequence | Severity |
|--------------------------|-------------|----------|
| **ADR Decision Record Gate** (step 5) | No pre-implementation check that all architectural decisions have ADRs. No mid-implementation stopping to create ADRs when new decisions surface. Decisions silently go untracked. | **CRITICAL** |
| **Extension hooks** (before/after implement) | No `.specify/extensions.yml` integration. Custom pre/post hooks (linting, security scans, memory sync) won't fire. | HIGH |
| **Checklist gate** (step 2) | No verification that UX/test/security checklists are complete before starting. | HIGH |
| **Phase-based execution from tasks.md** | Superpowers executes tasks linearly from its own plan format. Loses phase grouping (Setup → Tests → Core → Integration → Polish), [P] parallel markers, and dependency ordering from spec-kit's tasks.md. | HIGH |
| **Tasks.md checkbox tracking** | Superpowers uses TodoWrite for progress. Spec-Kit marks `[X]` directly in tasks.md — creating a durable, version-controlled progress record visible across sessions. | MEDIUM |
| **Project setup verification** (step 4) | No auto-detection of .gitignore, .dockerignore, .eslintignore patterns based on tech stack. | LOW |
| **Completion validation against spec** (step 10) | Spec-Kit validates implemented features match original specification. Superpowers' verification is per-task, not feature-wide. | MEDIUM |
| **Constitution-aware implementation** | Spec-Kit loads constitution.md and respects rigor calibration throughout. Superpowers has no concept of governance calibration. | HIGH |

### 9.2 What You Gain Using Superpowers' Execution

| Superpowers Capability | Value |
|------------------------|-------|
| **Per-task subagent isolation** | Fresh context per task prevents cross-contamination between tasks. Each subagent starts clean with only its task context. |
| **Two-stage inline review** | Every task gets reviewed for spec compliance THEN code quality before proceeding. Catches bugs per-task rather than per-feature. |
| **Micro-task granularity** | 2-5 minute tasks with exact code blocks, exact commands, exact expected output. Reduces agent drift. |
| **Strict TDD with teeth** | RED must fail for the right reason. Code before test = delete and restart. Anti-rationalization patterns. |
| **Systematic debugging built-in** | 4-phase root cause analysis when things break. |
| **Verification-before-completion** | Dedicated skill ensuring fixes actually work before marking done. |
| **Git worktree isolation** | Parallel workspaces without branch switching. |

### 9.3 The Core Tension: Governance vs. Discipline

**Spec-Kit's implementation is governance-oriented**: It asks "are all decisions tracked? are all gates passed? does the output match the spec?" It trusts the agent to write good code but wraps execution in documentation and compliance checks.

**Superpowers' implementation is discipline-oriented**: It asks "did you write the test first? did it fail? did you write the minimum code? did you verify?" It doesn't care about ADRs or checklists but enforces rigorous moment-to-moment coding discipline.

Neither alone is complete. Spec-Kit can produce well-governed code that wasn't actually TDD'd. Superpowers can produce perfectly TDD'd code with zero decision tracking.

---

## 10. File Output Patterns & Cross-Referencing

### 10.1 Where Each System Puts Its Files

| Artifact | Spec-Kit Location | Superpowers Location | Conflict? |
|----------|-------------------|----------------------|-----------|
| **Design docs** | `specs/###-feature/spec.md` | `docs/superpowers/specs/YYYY-MM-DD-topic-design.md` | **YES** — parallel design docs with no cross-reference |
| **Plans** | `specs/###-feature/plan.md` + `tasks.md` | `docs/superpowers/plans/YYYY-MM-DD-feature.md` | **YES** — parallel plans with different granularity |
| **Decision records** | `.specify/memory/ADR_NNN_*.md`, `LOG_NNN_*.md` | None | No conflict — superpowers doesn't create these |
| **Research** | `specs/###-feature/research.md` | None | No conflict |
| **Data model** | `specs/###-feature/data-model.md` | None | No conflict |
| **Contracts** | `specs/###-feature/contracts/` | None | No conflict |
| **Progress tracking** | `specs/###-feature/tasks.md` (checkboxes `[X]`) | TodoWrite (ephemeral, in-session only) | Different mechanisms — spec-kit is persistent, superpowers is ephemeral |
| **Brainstorm artifacts** | `roadmap.md`, `brainstorm-notes.md` | `docs/superpowers/specs/*-design.md` | Different scope, different location |
| **Git branches** | `###-feature-name` (branch per feature) | Worktree in `.worktrees/` or `~/.config/superpowers/worktrees/` | Different branching models |
| **Code review output** | Inline report from multi-persona panel | Inline per-task review (not persisted) | Spec-Kit is richer; superpowers is ephemeral |
| **Memory/recall** | `.specify/memory/.index/` (LanceDB vectors) | None | Unique to spec-kit |

### 10.2 The Cross-Referencing Problem

If both systems run, you get **parallel artifact trees with no links between them**:

```
specs/006-new-feature/
  spec.md              ← spec-kit knows about this
  plan.md              ← spec-kit knows about this
  tasks.md             ← spec-kit knows about this

docs/superpowers/
  specs/
    2026-04-18-new-feature-design.md    ← superpowers knows about this
  plans/
    2026-04-18-new-feature.md           ← superpowers knows about this
```

Neither system reads the other's artifacts. Superpowers' brainstorming skill won't check `specs/006-new-feature/spec.md`. Spec-Kit's `/speckit.implement` won't read `docs/superpowers/plans/*.md`.

### 10.3 Consolidation Options

#### Option A: Spec-Kit Owns All Artifacts (Recommended)

Keep spec-kit's file layout as the single source of truth. Suppress superpowers' file output and redirect its inputs.

**How**:
1. **Skip superpowers' brainstorming** — use `speckit.brainstorm` and `speckit.specify` exclusively
2. **Skip superpowers' writing-plans** — use `speckit.tasks` for task breakdown; let superpowers' TDD/debugging/verification skills operate within `speckit.implement` without generating their own plan files
3. **Configure superpowers to not emit design/plan docs** — either:
   - Add a `.claude/rules/superpowers-integration.md` rule that says: "Do NOT create files under `docs/superpowers/`. All design artifacts live in `specs/###-feature/`. All decision records live in `.specify/memory/`."
   - Or disable the brainstorming and writing-plans skills entirely (only keep TDD, debugging, verification, worktrees)

**What you wire in from superpowers**: Only the execution-discipline skills (TDD, debugging, verification, optionally worktrees). These don't create their own artifacts — they modify behavior during implementation.

**Trade-off**: You lose superpowers' micro-task plan format (2-5 min with exact code). Spec-Kit's tasks.md is higher level.

#### Option B: Superpowers Owns Execution, Spec-Kit Owns Governance

Let superpowers handle brainstorming → planning → execution. Spec-Kit handles review, audit, ADRs, memory.

**How**:
1. Superpowers writes design docs and plans to `docs/superpowers/`
2. Before `speckit.review`, a bridge step copies or references superpowers artifacts:
   - Add spec-kit `spec.md` that references `docs/superpowers/specs/*-design.md`
   - Create tasks.md from superpowers' plan (manual or scripted)
3. After implementation, run `speckit.codereview` and `speckit.audit` as normal
4. ADRs are created by spec-kit's gates during review/audit

**Trade-off**: You maintain two artifact trees. The bridge step is manual friction. Drift between `docs/superpowers/` and `specs/` is likely over time.

#### Option C: Merge File Layouts Into a Single Tree

Reconfigure superpowers to write into spec-kit's file structure.

**How**:
1. Create a `.claude/rules/superpowers-integration.md` that remaps output paths:
   ```
   When the brainstorming skill would write to docs/superpowers/specs/, write to specs/###-feature/ instead.
   When writing-plans would write to docs/superpowers/plans/, write as specs/###-feature/superpowers-plan.md instead.
   ```
2. Update `speckit.implement.md` to also load `superpowers-plan.md` if it exists (micro-task detail augmenting the higher-level tasks.md)
3. Update `speckit.codereview.md` and `speckit.audit.md` to include `superpowers-plan.md` in their DOC_CONTEXT
4. Add memory-recall hooks so superpowers design docs get indexed by the memory server

**Trade-off**: Requires maintaining a rules file that overrides superpowers' default behavior. May break on superpowers plugin updates. But gives you a single artifact tree with both levels of detail.

### 10.4 Making Systems Aware of Each Other

Regardless of which option you choose, these cross-references are needed:

| Direction | What Needs to Happen |
|-----------|---------------------|
| **Superpowers → Spec-Kit artifacts** | Superpowers skills need to read `specs/###-feature/spec.md` and `plan.md` as context. Add to rules: "Before executing any superpowers skill, check for an active feature in `specs/` and load its spec.md and plan.md as context." |
| **Superpowers → ADRs** | Superpowers' TDD and debugging skills should respect existing ADRs. Add to rules: "When making implementation decisions, check `.specify/memory/ADR_*.md` for existing architectural decisions. Do not contradict them." |
| **Superpowers → Memory server** | After superpowers generates a design doc or plan, store a summary chunk via `memory_store` with `source_file: "synthetic"`. This makes superpowers' outputs recallable in future sessions. |
| **Spec-Kit → Superpowers skills** | `speckit.implement` should invoke TDD/debugging/verification skills during execution. Add skill references to implement.md steps 7-9. |
| **Spec-Kit audit → Superpowers artifacts** | If Option B or C, `speckit.audit` needs to scan `docs/superpowers/` or `superpowers-plan.md` for consistency checking. |
| **Worktrees → Branch naming** | Superpowers creates worktrees with its own naming. Add rule: "When creating git worktrees, use spec-kit's `###-feature-name` branch convention." |

---

## 11. Recommendation (Updated)

**Option A (Spec-Kit owns artifacts) is the cleanest path.** Here's why:

1. **No file layout changes needed** — everything stays in `specs/` and `.specify/memory/`
2. **No cross-referencing infrastructure** — superpowers' execution-discipline skills don't create files
3. **No drift risk** — one artifact tree, one source of truth
4. **You keep governance** — ADR gates, checklist gates, extension hooks, memory server all work unchanged
5. **You gain discipline** — TDD enforcement, systematic debugging, verification gates operate inside `speckit.implement`

The trade-off (losing superpowers' micro-task plan format) is minor — you could enhance `speckit.tasks` to generate more granular tasks if needed, without adopting superpowers' separate plan file.

**Concrete next steps**:
1. Install superpowers plugin
2. Create `.claude/rules/superpowers-integration.md` with activation policy (which skills activate when, artifact path overrides)
3. Add TDD/debugging/verification references to `speckit.implement.md`
4. Disable or suppress: brainstorming, writing-plans, executing-plans, subagent-driven-development, finishing-a-development-branch, code-reviewer
5. Test on a real feature

---

## Sources

- [Superpowers GitHub Repository](https://github.com/obra/superpowers)
- [Anthropic Official Plugin Marketplace](https://github.com/anthropics/claude-plugins-official)
- [Superpowers Plugin Hub Entry](https://www.claudepluginhub.com/plugins/obra-superpowers-2)
- [Superpowers Blog Post (Oct 2025)](https://blog.fsck.com/2025/10/09/superpowers/)
- [Superpowers Complete Guide](https://www.pasqualepillitteri.it/en/news/215/superpowers-claude-code-complete-guide)
