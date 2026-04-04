# Feature Specification: Review Panel Benchmark

**Feature Branch**: `000-review-benchmark`
**Created**: 2026-04-02
**Status**: Draft
**Input**: User description: "Build benchmark artifact set for testing review panel efficiency — synthetic spec/plan/tasks with planted issues and a review-profile command"

## Decision Records

| # | Type | File | Title | Status |
|---|---|---|---|---|
| ADR-001 | Decision | ADR_001_standard-panel-composition.md | STANDARD Panel Composition | Accepted |
| LOG-002 | Question | LOG_002_benchmark-isolation-strategy.md | Benchmark-Key Isolation Strategy | Resolved |
| LOG-003 | Question | LOG_003_benchmark-variance-strategy.md | Benchmark Run Variance Strategy | Resolved |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run a Measurable Panel Benchmark (Priority: P1)

A Spec-Kit maintainer wants to empirically measure whether changes to the review panel
(agent prompts, phase structure, rigor levels) improve signal quality without increasing
overlap. They run the benchmark against a canonical artifact set with known planted issues
and get a structured efficiency report showing which agents caught which issues, where
overlap occurred, and how many false positives each agent raised.

**Why this priority**: Without a repeatable benchmark, all panel tuning is subjective.
This is the core capability — everything else supports it.

**Independent Test**: Given a fully assembled `specs/000-review-benchmark/` directory
with spec.md, plan.md, tasks.md, and benchmark-key.md, when a maintainer runs
`/speckit.review-profile` at the `spec` gate, the command produces a synthesis report
followed by a Panel Efficiency Report that lists each agent's unique and shared findings,
identifies overlap clusters, and scores against the benchmark key — all without the agents
having read benchmark-key.md.

**Acceptance Scenarios**:

1. **Given** the benchmark artifacts exist, **When** `/speckit.review-profile spec` is run, **Then** the output includes a "Panel Efficiency Report" section with unique-contribution counts per agent.
2. **Given** an agent raises a finding that matches a `FALSE-*` entry in benchmark-key.md, **When** the report is generated, **Then** that finding is counted as a false positive in the FP Rate table.
3. **Given** an agent raises a finding matching a planted issue (e.g., `SEC-1`), **When** the report is generated, **Then** that planted issue is marked "Caught" in the Miss Rate table.
4. **Given** two agents both raise a finding about the same topic, **When** the overlap matrix is built, **Then** the finding appears in the Overlap Clusters table with a verdict of either "Different angle — keep both" or "Redundant."

---

### User Story 2 - Compare Rigor Levels (Priority: P2)

A maintainer wants to know whether STANDARD or LIGHTWEIGHT review panels catch enough
critical and high-severity issues to be safe defaults for lower-stakes projects. They run
the benchmark at FULL, STANDARD, and LIGHTWEIGHT, then compare the Coverage by Rigor Level
table across all three runs.

**Why this priority**: The calibration comparison is only possible after Story 1's
benchmark and command exist. Its value is in producing data that drives the constitution
default recommendation.

**Independent Test**: Given the benchmark and `/speckit.review-profile` command exist from
Story 1, when a maintainer runs the benchmark three times specifying FULL, STANDARD, and
LIGHTWEIGHT panels, then each run produces a Coverage by Rigor Level table, and the three
tables can be compared to determine which planted issues (by severity) each level catches.

**Acceptance Scenarios**:

1. **Given** FULL panel results, **When** compared against STANDARD results via `--compare`, **Then** any CRITICAL or HIGH planted issue missed by STANDARD is surfaced as a gap in the Coverage by Rigor Level table.
2. **Given** all three run files exist in `specs/000-review-benchmark/runs/`, **When** `--compare` is run, **Then** it produces a single table with all planted issues × all rigor levels and an explicit PASS/FAIL verdict for STANDARD.

---

### Edge Cases

- What happens when an agent raises a finding that partially matches a planted issue (same artifact, different framing)? It is scored as "Caught (partial)" — a distinct third state in the Miss Rate table, counted separately from full catches but not as missed. This satisfies SC-001 (no issue is unscored) while preserving diagnostic signal.
- What if benchmark-key.md leaks into agent context? The command must not pass the file to Phase A agents. Additionally, the scoring pass MUST run a contamination check: if any agent finding contains an exact benchmark-key issue ID (e.g., `PROD-1`, `SEC-1`) verbatim, the run is flagged as potentially contaminated, the result is invalidated, and the maintainer is prompted to re-run with a clean context. Contamination detection takes precedence over scoring.
- What if a planted issue is never caught by any agent across all rigor levels? It should appear in the Miss Rate table with "Missed at all levels" and be flagged for review as either too subtle or a gap in agent coverage.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The benchmark artifact set MUST contain realistic-looking spec.md, plan.md, and tasks.md files for a "user notification preferences" feature — convincing enough that agents reason about content rather than pattern-match on synthetic markers.
- **FR-002**: Each artifact MUST contain the planted issues specified in `specs/001-review-efficiency-profiler/plan.md` (PROD-1, PROD-2, SEC-1, FALSE-1 in spec; ARCH-1, ARCH-2, SEC-2, FALSE-2 in plan; DEL-1, DEL-2, ARCH-3, FALSE-3 in tasks).
- **FR-003**: benchmark-key.md MUST list all planted issues with ID, type, severity, artifact, description, expected catcher, and overlap risk — and MUST NOT be referenced in Phase A agent prompts. The scoring pass MUST include a contamination check before scoring: if any Phase A finding contains an exact issue ID from the key (e.g., `PROD-1`, `SEC-1`) verbatim, the run MUST be flagged as contaminated, the scoring result invalidated, and the maintainer prompted to re-run.
- **FR-004**: The `/speckit.review-profile` command MUST tag each Phase A finding with the agent name that raised it before passing findings to Phase B.
- **FR-005**: The synthesis judge MUST identify overlapping findings across Phase A outputs as part of its Phase C reasoning, tagging each overlap cluster with a verdict of "Redundant" or "Different angle." The command then extracts these tagged clusters to populate the Overlap Clusters table in the Panel Efficiency Report.
- **FR-006**: When reviewing `000-review-benchmark`, the command MUST perform a deterministic (rule-based, not LLM-based) scoring pass against benchmark-key.md and append False Positive Rate and Miss Rate tables to the report. Scoring rules: (a) a finding is "Caught" if it references the correct artifact section and core problem area matching a planted issue's description; (b) "Caught (partial)" if it references the correct artifact but with incorrect framing or only partial problem identification; (c) "Missed" if no finding addresses the planted issue. The contamination check (FR-003) runs before scoring.
- **FR-007**: The Panel Efficiency Report MUST include: Unique Contribution by Agent table, Overlap Clusters table, and (in benchmark mode) False Positive Rate and Miss Rate tables. The report MUST be output to the terminal AND saved to `specs/000-review-benchmark/runs/YYYY-MM-DD-<gate>-<RIGOR>-run<N>.md` (e.g., `2026-04-03-spec-FULL-run1.md`) to prevent filename collisions across rigor levels and repeated runs on the same day.
- **FR-008**: The `/speckit.review-profile` command MUST accept a rigor level parameter (FULL / STANDARD / LIGHTWEIGHT) to support calibration comparison runs.
- **FR-009**: After all three calibration runs complete (FULL, STANDARD, LIGHTWEIGHT), the command MUST support a `--compare` mode that reads all three saved run files for the same gate and produces a single Coverage by Rigor Level table showing each planted issue's catch status (Caught / Caught (partial) / Missed) at each rigor level, plus a pass/fail verdict for STANDARD (PASS = zero CRITICAL planted issues missed; FAIL otherwise).

### Key Entities

- **Planted Issue**: A deliberately embedded flaw in a benchmark artifact with a known ID, severity, expected catching agent, and false-positive flag.
- **Overlap Cluster**: A set of findings from two or more agents that refer to the same underlying problem, with a verdict on whether they add independent value.
- **Panel Efficiency Report**: The structured output appended to synthesis that scores agent performance, overlap, false positives, and miss rate.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Each planted issue in the benchmark key has a known status after a FULL panel run — one of "Caught," "Caught (partial)," or "Missed" — zero issues are unscored.
- **SC-002**: Each agent's unique contribution rate is quantified — the report produces a number (unique findings / total findings) per agent for every benchmark run.
- **SC-003**: After three calibration runs (FULL / STANDARD / LIGHTWEIGHT at the same gate), the `--compare` mode produces a Coverage by Rigor Level table covering all planted issues, and the table includes a pass/fail verdict for STANDARD (PASS = zero CRITICAL issues missed; FAIL = one or more CRITICAL issues missed). The table and verdict together constitute the decision input — no separate "written recommendation" is required as a success criterion.
- **SC-004**: False positive rate per agent is known — any agent raising a `FALSE-*` issue as a genuine concern is identifiable and quantified.
- **SC-005**: Benchmark artifacts are convincing enough that at least one planted issue per artifact requires genuine reasoning to catch (not keyword matching on "missing" or "undocumented").

## Clarifications

### Session 2026-04-02

- Q: How should the command identify that two agents raised the same issue to build the overlap matrix? → A: The synthesis judge determines overlap as part of Phase C reasoning; it tags each overlap cluster with a verdict, which the command extracts to populate the Overlap Clusters table.
- Q: Where should the Panel Efficiency Report be saved? → A: Terminal output AND saved to `specs/000-review-benchmark/runs/YYYY-MM-DD-<gate>.md` for three-way comparison across calibration runs.
- Q: Which agents compose the STANDARD panel? → A: systems-architect + security-reviewer + devils-advocate.
- Q: How should partial matches be scored in the Miss Rate table? → A: "Caught (partial)" — a distinct third state, counted separately from full catches and from missed, ensuring no issue is unscored.

## Assumptions

- The benchmark artifacts represent a web application feature context (REST API + React frontend) consistent with existing constitution defaults.
- Benchmark-key.md isolation is enforced by not passing the file to Phase A agent prompts. Contamination detection (FR-003) provides a secondary layer: exact issue ID matches in findings indicate key exposure.
- "Rigor level" maps to explicit panel compositions: FULL = all six specialist agents, STANDARD = systems-architect + security-reviewer + devils-advocate, LIGHTWEIGHT = devils-advocate only.
- Initial calibration uses one run per rigor level. LLM non-determinism means single-run results are indicative, not statistically significant. Variance across repeated runs is a known limitation; multi-run averaging is deferred to a future benchmark iteration.
- Benchmark results on synthetic planted issues are a necessary but not sufficient input to panel tuning. Results measure detection of known, discrete flaws and may not fully generalize to emergent issues in real feature reviews. The STANDARD verdict (SC-003) should be interpreted with this caveat.
- The cross-feature reference in FR-002 (`specs/001-review-efficiency-profiler/plan.md`) is a dependency: that plan defines the complete planted issue list. If plan.md is unavailable at implementation time, inline the planted issue definitions directly from the list in FR-002.
