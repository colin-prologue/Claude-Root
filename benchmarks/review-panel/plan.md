# Implementation Plan: Review Panel Benchmark

**Branch**: `000-review-benchmark` | **Date**: 2026-04-03 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/000-review-benchmark/spec.md`

## Summary

Build the Spec-Kit panel efficiency benchmark: (1) a synthetic "user notification
preferences" spec/plan/tasks artifact set with 12 deliberately planted issues of known
types stored in `specs/000-review-benchmark/fixture/`, (2) a `benchmark-key.md` scoring
instrument, and (3) a `/speckit.review-profile` command that runs a full three-phase review
with finding-tagging and overlap extraction, appends a Panel Efficiency Report, and saves
run files to `runs/`. The command also supports `--compare` mode to merge three rigor-level
runs into a single Coverage by Rigor Level table with a PASS/FAIL verdict for STANDARD.

## Decision Records

| # | Type | File | Title | Status |
|---|---|---|---|---|
| ADR-001 | Decision | ADR_001_standard-panel-composition.md | STANDARD Panel Composition | Accepted |
| LOG-002 | Question | LOG_002_benchmark-isolation-strategy.md | Benchmark-Key Isolation Strategy | Resolved |
| LOG-003 | Question | LOG_003_benchmark-variance-strategy.md | Benchmark Run Variance Strategy | Resolved |
| ADR-004 | Decision | ADR_004_fixture-file-location.md | Synthetic Fixture File Location | Accepted |
| ADR-005 | Decision | ADR_005_compare-mode-architecture.md | `--compare` Mode Architecture | Accepted |
| ADR-006 | Decision | ADR_006_benchmark-scoring-architecture.md | Benchmark Scoring Architecture | Accepted |
| ADR-007 | Decision | ADR_007_gate-accurate-panel-composition.md | Gate-Accurate Panel Composition | Accepted — supersedes ADR-001 |

## Technical Context

**Language/Version**: N/A — no application code; all deliverables are Markdown files
**Primary Dependencies**: Claude Code command system (`$ARGUMENTS`, Agent Teams)
**Storage**: File system — `runs/` directory for run reports; `fixture/` for synthetic artifacts
**Testing**: Manual execution — running `/speckit.review-profile spec` and verifying output
**Target Platform**: Claude Code CLI (darwin/linux, Claude agent session)
**Project Type**: Developer tooling — markdown command prompt + static fixture content
**Performance Goals**: N/A (single-maintainer tool; response time is review session duration)
**Constraints**: Fixture artifacts must be convincing enough to require reasoning (SC-005); command stays within Claude's single-session context window
**Scale/Scope**: 12 planted issues, 3 rigor levels, 1 gate per initial calibration run

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **Pass 1 — Assumptions**: Challenged via spec gate adversarial review; all blocking findings resolved in spec revisions (CF-1 through CF-4)
- [x] **Pass 2 — Research**: Phase 0 research resolved all design unknowns (Q1–Q5 in research.md); no external dependencies or technology gaps
- [x] **Pass 3 — Plan scrutiny**: Riskiest decision = scoring pass determinism (LOG-003); addressed by rule-based scoring criteria in FR-006 and ADR-006

- [x] Principle I: Spec approved post-clarify and post-spec-gate review; all ambiguities resolved
- [x] Principle II: No speculative abstractions — the command extends `/speckit.review` with minimal additive changes; `fixture/` subdirectory is the minimal file structure change
- [x] Principle III: TDD inapplicable in traditional sense (no compilable code); "tests" = benchmark runs against fixture artifacts with known expected outcomes
- [x] Principle IV: Story 1 (P1 — single benchmark run) is independently deliverable; Story 2 (P2 — compare mode) depends on Story 1's runs output but is a separate workflow step
- [x] PR Policy: All deliverables are Markdown files; total LOC will be under 300 for each PR

## Project Structure

### Documentation (this feature)

```text
specs/000-review-benchmark/
├── spec.md              ← Feature specification
├── plan.md              ← This file
├── research.md          ← Phase 0 research
├── data-model.md        ← Entity definitions
├── contracts/
│   └── review-profile-command.md   ← Command interface contract
├── benchmark-key.md     ← Scoring instrument (not for agents)
├── fixture/             ← Synthetic benchmark artifacts (reviewed by agents)
│   ├── spec.md          ← "User notification preferences" spec with planted issues
│   ├── plan.md          ← Plan with planted issues
│   └── tasks.md         ← Tasks with planted issues
├── runs/                ← Created at runtime by review-profile command
│   └── YYYY-MM-DD-<gate>-<RIGOR>-run<N>.md
└── tasks.md             ← Created by /speckit.tasks
```

### Source Code (repository root)

```text
.claude/commands/
└── speckit.review-profile.md   ← New command (review profiling + --compare mode)
```

No source code — all deliverables are Markdown files.

**Structure Decision**: Single-feature structure with a `fixture/` subdirectory to isolate
synthetic artifacts from real Spec-Kit planning artifacts (ADR-004). No `src/` or `tests/`
directories. The command file lives in `.claude/commands/` alongside existing Spec-Kit
commands. The `runs/` directory is created at runtime by the first review-profile execution.

## Complexity Tracking

No constitution violations. All deliverables are Markdown files within Spec-Kit's existing
patterns. No new abstractions, no new infrastructure.

---

## Benchmark Validity Model

*(Added post-plan-gate review — BLOCK-1)*

### What the benchmark measures

Detection rates for discrete, pre-defined flaws of known types in synthetic Spec-Kit
artifacts, by panel composition and rigor level. The output answers: "At STANDARD rigor,
what percentage of planted issues of each type does the panel catch?"

### Validity conditions

Results are valid for comparison only when:
1. **Same scorer, same prompt**: The scoring pass uses the same Claude model version and
   FR-006 rule text across all runs being compared. Scorer variance is a constant bias that
   does not cancel if the scorer changes between runs.
2. **Gate-accurate panels**: The panel used in each run matches the production
   `/speckit.review` composition for that gate and rigor level (ADR-007).
3. **Gate-scoped scoring**: Each run's Miss Rate denominator includes only planted issues
   `applicable_gate` matches the gate that was run. Issues in other artifacts are excluded
   from the denominator, not counted as missed.
4. **Clean runs only**: Contamination-flagged runs are excluded from all comparisons.

### What the benchmark does not measure

- Detection of emergent, systemic, or ambiguous issues in real feature reviews
- Performance on issues not structurally similar to the planted issue types
- Review quality on non-Spec-Kit artifact formats

### Falsification criteria

The benchmark has lost discriminative power when:
- Any rigor level scores ≥95% catch rate across all HIGH and CRITICAL issues (fixture may
  have become too obvious from repeated exposure)
- FULL and LIGHTWEIGHT produce identical Miss Rate tables across two consecutive runs
  (fixture issues may be trivially detectable regardless of panel size)

### Scoring variance acknowledgement

FR-006 rule 2 ("describes the core problem area") requires semantic judgment. Absolute
detection rates have an unknown error margin. Only deltas between runs scored by the same
scorer and model version are reliably interpretable. This limitation is stated in every
Panel Efficiency Report under a "Limitations" header.

---

## Implementation Design

### Component 1: Fixture Artifacts (`fixture/spec.md`, `fixture/plan.md`, `fixture/tasks.md`)

**What to build**: Three convincing, realistic-looking Spec-Kit artifacts for a fictional
"User Notification Preferences" web feature. Quality bar: an agent must reason about the
content to catch planted issues — keyword matching on "missing" or "undocumented" should
not surface them.

**Planted issue placement** (authoritative list — inlined here; `specs/001-review-efficiency-profiler/plan.md` reference is superseded):

*In `fixture/spec.md`:*
- `PROD-1` (HIGH): Missing admin persona — no story covers admin management of other users' notification settings
- `PROD-2` (MEDIUM): P1/P2 priority reversal — email preferences (P2) is the core case; push notification (P1) is an enhancement
- `SEC-1` (HIGH): No authorization requirement — users can modify preferences without owning them (IDOR setup)
- `FALSE-1`: A requirement that appears ambiguous but is intentionally scoped narrow (any agent raising it as a gap is a false positive)

*In `fixture/plan.md`:*
- `ARCH-1` (HIGH): Single preferences table with nullable columns per channel — no ADR, doesn't scale to a 4th channel
- `ARCH-2` (MEDIUM): Redis dependency introduced for rate limiting but absent from the stack table with no ADR
- `SEC-2` (CRITICAL): Rate limiting planned (Redis) but not wired to the preference-update endpoint
- `FALSE-2`: Architecture decision that appears underspecified but is intentionally deferred to a referenced existing ADR

*In `fixture/tasks.md`:*
- `DEL-1` (HIGH): Test tasks for User Story 2 appear after implementation tasks by task ID (TDD violation)
- `DEL-2` (MEDIUM): Two tasks marked `[P]` (parallel) share a write to the same config file (hidden state conflict)
- `ARCH-3` (MEDIUM): Redis setup task is in Phase 3 (User Story 1) instead of Phase 2 (Foundational), creating a hidden dependency for Story 2's rate limiting tasks
- `FALSE-3`: A task that looks like it's missing a test but the test is covered by an integration task two IDs later (clearly referenced)

**Authorship guidelines**:
- Write each artifact as a legitimate Spec-Kit document that would pass casual review
- False positives must be genuine traps — write them to look exactly like the issue they mimic
- Use real Spec-Kit formatting (section names, priority notation, task IDs)
- Do not name planted issues anywhere in the fixture files — agents must discover them organically

---

### Component 2: Benchmark Key (`benchmark-key.md`)

One Markdown table with all 12 planted issues, using the schema from `data-model.md`:
`ID | Type | Severity | Artifact | Description | Expected Agent | Overlap Risk`

The scoring pass references this file. Phase A agents never receive it.

---

### Component 3: `/speckit.review-profile` Command

**File**: `.claude/commands/speckit.review-profile.md`

**Structure** (two-branch command):

```
Branch A — Review Mode (default, when --compare is absent):
  1. Detect mode from $ARGUMENTS
  2. Read constitution for CALIBRATION_BLOCK
  3. Compose panel using gate-accurate compositions matching /speckit.review (ADR-007):
     - Spec gate FULL: product-strategist, security-reviewer, devils-advocate
     - Spec gate STANDARD: product-strategist, devils-advocate
     - Plan gate FULL: systems-architect, security-reviewer, delivery-reviewer, devils-advocate
     - Plan gate STANDARD: systems-architect, security-reviewer, devils-advocate
     - Task gate FULL: delivery-reviewer, systems-architect, devils-advocate
     - Task gate STANDARD: delivery-reviewer, devils-advocate
     - LIGHTWEIGHT at any gate: devils-advocate only
     - synthesis-judge always added
  4. Phase A: Spawn panel agents with CALIBRATION_BLOCK + finding-tag instruction
     - Each agent receives: fixture/[artifacts for gate] + tag-your-findings instruction
     - benchmark-key.md is NOT in the artifact list (hard invariant: never read before step 7)
  5. Phase B: Build consensus summary → DA challenge → specialist responses
  6. Phase C: Synthesis judge with overlap-verdict instruction
     - Synthesis judge is asked to produce overlap clusters in structured table format:
       | Finding Topic | Agents | Overlap Type | Verdict |
       (schema required for extraction; if absent, log warning and skip overlap table)
  7. Scoring pass (benchmark-key.md read here for the FIRST time):
     a. Contamination check (FR-003): scan findings for verbatim key IDs → abort if found
     b. Filter planted issues to applicable_gate = current gate (gate-scoped scoring)
     c. Score each applicable PlantedIssue against Phase A findings (FR-006 rules)
     d. Compute: unique contribution, overlap clusters (from judge), FP records, scored issues
  8. Append Panel Efficiency Report to output (include Limitations header per validity model)
  9. Save to runs/YYYY-MM-DD-<gate>-<RIGOR>-run<N>.md

Branch B — Compare Mode (when --compare is present):
  1. Detect gate from $ARGUMENTS
  2. Find most recent run file for each rigor level at that gate
  3. Extract Miss Rate tables from each run file
  4. Build Coverage by Rigor Level table (all PlantedIssues × all rigor levels)
  5. Compute PASS/FAIL verdict for STANDARD (zero CRITICAL missed = PASS)
  6. Output to terminal
```

**Key differences from `/speckit.review`**:
1. Artifact list = `fixture/` paths, not the current feature's spec/plan/tasks
2. Phase A prompt adds: "Tag each finding row with your agent name: `[agent-name] | ...`"
3. Phase C synthesis judge prompt adds: "For each topic raised by 2+ agents, add a cluster row with verdict: Redundant or Keep both"
4. After synthesis: contamination check + scoring pass + Panel Efficiency Report

---

## Implementation Order

**Critical path**: Fixture content is the highest-risk, most important deliverable. No other
implementation work begins until fixtures complete pilot validation (BLOCK-4). The command
is scaffolding; the fixtures are the benchmark.

### Phase 1: Fixture Content (P1 — HARD GATE before Phase 2)

1. Write `fixture/spec.md` — "User Notification Preferences" feature spec with PROD-1, PROD-2, SEC-1, FALSE-1 planted
2. Write `fixture/plan.md` — Technical plan with ARCH-1, ARCH-2, SEC-2, FALSE-2 planted
3. Write `fixture/tasks.md` — Task list with DEL-1, DEL-2, ARCH-3, FALSE-3 planted
4. Write `benchmark-key.md` — Scoring table with all 12 entries (include `applicable_gate` column)

**Expected detection rates per fixture issue** (calibration targets for pilot validation):

| Issue ID | Severity | Expected catch rate at FULL | Notes |
|---|---|---|---|
| PROD-1 | HIGH | >70% | Admin persona gap — requires scanning for missing stakeholders |
| PROD-2 | MEDIUM | >50% | Priority reversal — requires reasoning about relative importance |
| SEC-1 | HIGH | >70% | IDOR gap — security-reviewer should catch; others may miss |
| FALSE-1 | — | <20% raised as gap | Must look like a real gap to constitute a trap |
| ARCH-1 | HIGH | >60% | Schema decision — systems-architect primary; requires reading data model |
| ARCH-2 | MEDIUM | >50% | Undocumented dependency — requires cross-referencing stack table |
| SEC-2 | CRITICAL | >80% | Rate limiting gap — should be highly visible to security-reviewer |
| FALSE-2 | — | <20% raised as gap | Must look underspecified with the ADR reference subtle |
| DEL-1 | HIGH | >60% | TDD violation — requires checking task ID ordering, not just content |
| DEL-2 | MEDIUM | >50% | Parallel conflict — requires reading both [P]-marked tasks |
| ARCH-3 | MEDIUM | >40% | Phase ordering — requires tracing the Redis dependency chain |
| FALSE-3 | — | <20% raised as gap | Must look like missing test with integration test reference non-obvious |

**Fixture validation (Phase 1 gate — blocks Phase 2)**:
- Run a single pilot: `/speckit.review spec` (standard review, not profile) against `fixture/spec.md` only
- Goal: verify spec-gate planted issues (PROD-1, PROD-2, SEC-1) require genuine reasoning
- Pass criteria: PROD-1 and SEC-1 are both raised without being trivially keyword-detectable;
  FALSE-1 is either not raised or raised without confidence
- Fail criteria: any planted issue is raised by quoting the exact phrase that signals it
  (e.g., an agent writes "the spec says 'missing admin'" — this means the fixture is too obvious)
- If pilot fails: revise the fixture content around that planted issue and re-pilot

### Phase 2: Review Profile Command (P1, User Story 1)

*Prerequisite: Phase 1 pilot validation passed.*

5. Write `.claude/commands/speckit.review-profile.md` — Full command incorporating:
   - Gate-accurate panel compositions (ADR-007)
   - Gate-scoped scoring (applicable_gate filter)
   - Synthesis judge structured overlap output schema
   - Validity model Limitations header in Panel Efficiency Report
   - benchmark-key.md read sequencing hard invariant (step 7 only)

**Validation**: Run `/speckit.review-profile spec --rigor FULL` against the benchmark. Confirm:
- Panel Efficiency Report appears with Limitations header
- Miss Rate table has only spec-gate issues (PROD-1, PROD-2, SEC-1, FALSE-1) — not all 12
- Overlap Clusters table is populated or warning is logged if empty
- Run file saved to `runs/`

### Phase 3: Compare Mode + Calibration Runs (P2, User Story 2)

6. Extend `speckit.review-profile.md` with `--compare` branch (includes run metadata display)
7. Run benchmark at FULL, STANDARD, LIGHTWEIGHT
8. Run `/speckit.review-profile --compare spec` to produce Coverage by Rigor Level table

**Validation**: Compare table covers only spec-gate issues; STANDARD has PASS/FAIL verdict; run dates are displayed prominently.

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|---|---|---|
| Fixture artifacts are too obvious — pilot validation fails | MEDIUM | Pilot gate in Phase 1 catches this before full benchmark; iterate until detection rates align with targets |
| Scorer variance makes absolute rates uninterpretable | MEDIUM | Use same model+prompt across all comparison runs; interpret only deltas, not absolutes (validity model) |
| Context window exceeded for full 3-gate benchmark run | LOW | Start with spec gate only; plan + tasks gate runs are Phase 3 |
| Contamination detection produces false positives (legitimate "SEC" or "PROD" in findings) | LOW | Check for full IDs only (e.g., `SEC-1`, `PROD-2`) not prefixes |
| Compare mode picks wrong run (same-day tie-breaking) | LOW | Lexicographic sort on filename; highest run-N wins; display run dates prominently |
| Panel composition drift between review-profile and speckit.review | LOW | Note maintenance dependency explicitly in command file header |
| Synthesis judge doesn't use expected overlap table format | LOW | Log warning + skip overlap table if schema not detected; don't fail the run |
