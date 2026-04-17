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

## Sources

- [Superpowers GitHub Repository](https://github.com/obra/superpowers)
- [Anthropic Official Plugin Marketplace](https://github.com/anthropics/claude-plugins-official)
- [Superpowers Plugin Hub Entry](https://www.claudepluginhub.com/plugins/obra-superpowers-2)
- [Superpowers Blog Post (Oct 2025)](https://blog.fsck.com/2025/10/09/superpowers/)
- [Superpowers Complete Guide](https://www.pasqualepillitteri.it/en/news/215/superpowers-claude-code-complete-guide)
