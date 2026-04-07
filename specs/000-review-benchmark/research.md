# Research: Review Panel Benchmark

**Feature Branch**: `000-review-benchmark`
**Created**: 2026-04-03
**Phase**: 0 — Design Research

## Questions Investigated

### Q1: Where should the synthetic fixture artifacts live?

**Problem**: `specs/000-review-benchmark/spec.md`, `plan.md`, and `tasks.md` are already
used by Spec-Kit for this feature's own specification artifacts. The 001 plan assumed the
synthetic "user notification preferences" artifacts would live at the 000 folder root, but
that creates a naming collision.

**Decision**: Place synthetic fixture artifacts in `specs/000-review-benchmark/fixture/`.

**Rationale**:
- Eliminates naming collision entirely
- Makes agent scope explicit: `/speckit.review-profile` passes `fixture/spec.md`,
  `fixture/plan.md`, `fixture/tasks.md` as the artifacts to review — never the real
  spec.md/plan.md
- `fixture/` is a universally understood term for test data
- `benchmark-key.md` stays at the 000 root (one level above fixture/) to emphasize its
  separation from the reviewed artifacts

**Alternatives considered**:
- `artifacts/` — equally clear but `fixture/` is more idiomatic for test infrastructure
- Root-level with different names (`notif-spec.md`, `notif-plan.md`) — avoids
  subdirectory but pollutes root with oddly named files
- A completely different location (`specs/bench-fixture/`) — over-separates what logically
  belongs to the 000 feature

---

### Q2: Should `--compare` be a branch in `/speckit.review-profile` or a separate command?

**Problem**: FR-009 requires a `--compare` mode that reads three saved run files and
produces the Coverage by Rigor Level table. This is a fundamentally different operation
from running a review.

**Decision**: Single command file (`.claude/commands/speckit.review-profile.md`) with
explicit conditional branching on `$ARGUMENTS`.

**Rationale**:
- A separate `speckit.review-profile-compare.md` would duplicate the benchmark-key.md
  lookup logic and run-file format knowledge
- Both modes share the same mental model (benchmark profiling) and the same user — a
  maintainer who just ran three review runs and wants to compare them
- Claude Code command files handle `$ARGUMENTS` conditionals naturally in markdown
  (the executing Claude reads "if --compare is present, do X; else do Y")
- Fewer files = lower maintenance surface; Principle II (Simplicity, NON-NEGOTIABLE)

**Alternatives considered**:
- Separate command — cleaner separation of concerns but doubles the surface area and
  creates two files both needing knowledge of the run-file format

---

### Q3: Post-processing vs. command-embedded scoring

**Problem**: Review MIN-4 flagged that embedding scoring in the review command risks
"measuring modified behavior" (the review runs differently because profiling is active).
A post-processing approach (score an existing synthesis output) would measure unmodified
behavior.

**Decision**: Command-embedded. Post-processing is ruled out by FR-004.

**Rationale**:
- FR-004 requires the command to tag each Phase A finding with the agent name **before
  passing findings to Phase B**. This intervention cannot happen in post-processing — it
  requires being active during Phase A collection.
- The overlap matrix (FR-005) requires the synthesis judge to explicitly tag clusters
  with verdicts. Standard `/speckit.review` does not prompt for this tagging; only the
  profile command does. This is an inherent behavioral difference.
- The "modified behavior" concern is valid but unavoidable given the spec's requirements.
  It is acknowledged in Assumptions: benchmark results should be interpreted as measuring
  profiled review behavior, which is close to but not identical to unmodified review.
- The simpler mitigation: make the modifications as lightweight as possible. The only
  changes to Phase A behavior are (1) the agent-name-tag instruction and (2) the overlap
  verdict instruction for the synthesis judge. These are additive, not substantive changes
  to review logic.

**Alternatives considered**:
- Post-processing: simpler, measures unmodified output, but cannot satisfy FR-004 or FR-005

---

### Q4: How should the deterministic scoring pass work?

**Problem**: FR-006 requires "deterministic, rule-based" scoring. This runs inside a Claude
session, so it is technically LLM-executed. "Deterministic" here means: the scoring rules
are explicit enough that any reasonable Claude instance would score identically.

**Decision**: Structured scoring table with explicit match criteria, not open-ended judgment.

**Rationale**: The command instructs Claude to produce a scoring table row-by-row for each
planted issue, applying the three criteria from FR-006 mechanically:
1. Does any finding reference the correct artifact (spec/plan/tasks)?
2. If yes, does it describe the core problem area matching the planted issue's description?
3. Score: both → Caught; artifact-only → Caught (partial); neither → Missed

The contamination check runs first (FR-003): if any finding text contains a verbatim
planted issue ID (e.g., `PROD-1`), the run is flagged before scoring.

No LLM judgment about severity, quality, or alternative interpretations — just the three
rules above applied to each planted issue against the full set of Phase A findings.

**Alternatives considered**:
- Semantic similarity scoring (embedding-based): more robust but requires external tooling
  outside the command context; over-engineered for the current scope

---

### Q5: How should finding-tagging work in Phase A?

**Problem**: FR-004 requires Phase A findings to be tagged with the agent name. The
synthesis judge and orchestrator need to know which finding came from which agent to build
the overlap matrix and unique-contribution table.

**Decision**: Each Phase A agent prefixes their findings output with `[AGENT_NAME]` in
the output structure. The review-profile command instructs each Phase A agent to include
their agent name in every finding row.

**Rationale**: This is the simplest possible tagging mechanism. The orchestrator already
collects each agent's output separately — the agent-name tag is redundant in the
orchestrator's view but necessary for the synthesis judge who receives all Phase A outputs
concatenated.

**Alternatives considered**:
- Structured JSON output with agent field — over-engineered; markdown tables with name
  column are sufficient and consistent with the report format
- Orchestrator adds tags after collection — adds an extra pass and risks mislabeling if
  output format varies

---

## Summary

All Phase 0 questions are resolved. No external research required. All decisions are
architectural choices derivable from the spec requirements and Principle II.

| # | Question | Decision | ADR |
|---|---|---|---|
| Q1 | Fixture file location | `fixture/` subdirectory | ADR-004 |
| Q2 | `--compare` mode | Same command file, conditional branching | ADR-005 |
| Q3 | Post-processing vs. embedded | Command-embedded (required by FR-004) | ADR-006 |
| Q4 | Scoring pass implementation | Structured scoring table, mechanical criteria | (see ADR-006) |
| Q5 | Finding tagging | Agent-name prefix in output rows | (see ADR-006) |
