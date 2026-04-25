# Data Model: Review Panel Benchmark

**Feature Branch**: `000-review-benchmark`
**Created**: 2026-04-03

This feature produces no database schema. All data lives as structured Markdown in files.
The "data model" here documents the fields and relationships of those structured documents.

---

## Entities

### PlantedIssue

Lives in: `specs/000-review-benchmark/benchmark-key.md`

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | yes | Unique identifier, e.g., `PROD-1`, `SEC-2`, `FALSE-1` |
| `type` | string | yes | Issue category: `Missing persona`, `Auth gap`, `Schema decision`, etc. |
| `severity` | enum | yes | `CRITICAL` / `HIGH` / `MEDIUM` / `—` (for false positives) |
| `artifact` | enum | yes | `spec.md` / `plan.md` / `tasks.md` |
| `description` | string | yes | What the issue is and where it appears in the artifact |
| `expected_catcher` | string | yes | Agent persona expected to catch it, or `none` for false positives |
| `overlap_risk` | enum | yes | `low` / `medium` / `high` — risk that multiple agents raise it |
| `applicable_gate` | enum | yes | `spec` / `plan` / `task` — the gate at which this issue is reviewable |

**Constraints**:
- IDs with prefix `FALSE-` are false-positive traps; `severity` = `—` and `expected_catcher` = `none`
- All other entries have a non-null severity and expected_catcher
- Exactly 12 planted issues: 4 per artifact (3 real issues + 1 false positive)
- `applicable_gate` maps to the artifact file: spec.md issues → `spec`; plan.md issues → `plan`; tasks.md issues → `task`
- The scoring pass MUST filter by `applicable_gate = current gate` before scoring. Issues outside the current gate are excluded from the denominator — NOT counted as "Missed".

---

### PhaseAFinding

Lives in: Phase A agent output (in-session, not persisted directly)

| Field | Type | Required | Description |
|---|---|---|---|
| `agent` | string | yes | Agent name, e.g., `product-strategist` |
| `severity` | enum | yes | `CRITICAL` / `HIGH` / `MEDIUM` / `LOW` |
| `category` | string | yes | Agent-defined category label |
| `location` | string | yes | Artifact and section reference |
| `finding` | string | yes | Description of the issue found |
| `recommendation` | string | no | Suggested fix |

**Constraints**:
- Agent field is populated via the agent-name prefix instruction (FR-004)
- All Phase A findings are passed to Phase B with agent attribution preserved

---

### OverlapCluster

Lives in: synthesis judge Phase C output, extracted into Panel Efficiency Report

| Field | Type | Required | Description |
|---|---|---|---|
| `topic` | string | yes | Brief description of the overlapping finding |
| `agents` | list[string] | yes | Agent names that raised the finding (2+) |
| `overlap_type` | string | yes | Free-form: `Same framing` / `Different angle` / `Partial match` |
| `verdict` | enum | yes | `Redundant` / `Keep both` |

---

### ScoredIssue

Lives in: Panel Efficiency Report (Miss Rate table), derived from PlantedIssue + PhaseAFindings

| Field | Type | Required | Description |
|---|---|---|---|
| `planted_issue_id` | string | yes | FK → PlantedIssue.id |
| `expected_catcher` | string | yes | Copied from PlantedIssue |
| `caught_by` | list[string] | yes | Agent names that caught it (may be empty) |
| `result` | enum | yes | `Caught` / `Caught (partial)` / `Missed` |

**Constraints**:
- Every PlantedIssue must have exactly one ScoredIssue after scoring (zero unscored issues = SC-001)
- False positives (FALSE-*) appear in FP Rate table, not Miss Rate table

---

### FalsePositiveRecord

Lives in: Panel Efficiency Report (FP Rate table)

| Field | Type | Required | Description |
|---|---|---|---|
| `agent` | string | yes | Agent that raised a FALSE-* as a genuine concern |
| `false_positive_id` | string | yes | FK → PlantedIssue.id (must have `FALSE-` prefix) |
| `finding_text` | string | yes | The agent's finding that matched the false positive trap |

---

### RunReport

Lives in: `specs/000-review-benchmark/runs/YYYY-MM-DD-<gate>-<RIGOR>-run<N>.md`

| Field | Type | Required | Description |
|---|---|---|---|
| `date` | date | yes | Run date (YYYY-MM-DD) |
| `gate` | enum | yes | `spec` / `plan` / `task` / `pre-implementation` |
| `rigor` | enum | yes | `FULL` / `STANDARD` / `LIGHTWEIGHT` |
| `run_number` | integer | yes | Sequential index for same-day, same-gate, same-rigor runs |
| `panel` | list[string] | yes | Agent names in the panel |
| `contamination_flag` | boolean | yes | True if contamination was detected; run is invalid if true |
| `efficiency_report` | EfficiencyReport | yes | Embedded Panel Efficiency Report |

---

### EfficiencyReport

Embedded section within RunReport

| Section | Content |
|---|---|
| Unique Contribution by Agent | Table: agent, unique findings count, shared findings count, unique rate |
| Overlap Clusters | Table: topic, agents, overlap type, verdict |
| False Positive Rate | Table: agent, false positives raised, FP rate (benchmark mode only) |
| Miss Rate | Table: planted issue ID, expected agent, caught by, result (benchmark mode only) |

---

## Relationships

```
PlantedIssue (12 per benchmark)
    ↓ scored against
PhaseAFinding (N per run, tagged with agent)
    ↓ produces
ScoredIssue (1:1 with PlantedIssue, all must be scored)
FalsePositiveRecord (0..N per run)
    ↓ combined into
EfficiencyReport
    ↓ embedded in
RunReport (1 per benchmark run, named by date+gate+rigor+N)
```

---

## File Structure

```
specs/000-review-benchmark/
  benchmark-key.md           ← PlantedIssue table (12 rows)
  fixture/
    spec.md                  ← Synthetic "user notification preferences" spec
    plan.md                  ← Synthetic plan with planted issues
    tasks.md                 ← Synthetic tasks with planted issues
  runs/
    YYYY-MM-DD-spec-FULL-run1.md      ← RunReport + EfficiencyReport
    YYYY-MM-DD-spec-STANDARD-run1.md
    YYYY-MM-DD-spec-LIGHTWEIGHT-run1.md
.claude/commands/
  speckit.review-profile.md  ← Command (review profiling + --compare mode)
```
