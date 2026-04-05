# Contract: `/speckit.review-profile` Command

**Feature Branch**: `000-review-benchmark`
**Created**: 2026-04-03
**Type**: Claude Code slash command

---

## Invocation

```
/speckit.review-profile [gate] [--rigor FULL|STANDARD|LIGHTWEIGHT]
/speckit.review-profile --compare [gate]
```

### Parameters

| Parameter | Required | Default | Values | Description |
|---|---|---|---|---|
| `gate` | yes (review mode) / yes (compare mode) | — | `spec` / `plan` / `task` / `pre-implementation` | Which artifact set to review or compare |
| `--rigor` | no | `FULL` | `FULL` / `STANDARD` / `LIGHTWEIGHT` | Panel composition for review mode |
| `--compare` | no | absent | flag | Triggers compare mode instead of review mode |

---

## Modes

### Review Mode (default)

Runs the full three-phase review against `specs/000-review-benchmark/fixture/` artifacts
at the specified gate, then appends the Panel Efficiency Report.

**Input**:
- `specs/000-review-benchmark/fixture/spec.md` (spec gate)
- `specs/000-review-benchmark/fixture/plan.md` (plan gate, also reads spec.md)
- `specs/000-review-benchmark/fixture/tasks.md` (task gate, reads all three)
- `specs/000-review-benchmark/benchmark-key.md` (scoring pass only — never passed to Phase A agents)

**Output**:
1. Terminal: full synthesis report + Panel Efficiency Report
2. File: `specs/000-review-benchmark/runs/YYYY-MM-DD-<gate>-<RIGOR>-run<N>.md`

**Panel compositions** — gate-accurate, matching production `/speckit.review` (ADR-007, supersedes ADR-001):

| Gate | FULL | STANDARD | LIGHTWEIGHT |
|---|---|---|---|
| spec | product-strategist, security-reviewer, devils-advocate | product-strategist, devils-advocate | devils-advocate |
| plan | systems-architect, security-reviewer, delivery-reviewer, devils-advocate | systems-architect, security-reviewer, devils-advocate | devils-advocate |
| task | delivery-reviewer, systems-architect, devils-advocate | delivery-reviewer, devils-advocate | devils-advocate |

synthesis-judge always added. Panel compositions must stay in sync with `.claude/commands/speckit.review.md` — document any divergence as a maintenance note.

**Scoring pass** (benchmark mode, after synthesis — benchmark-key.md read HERE for the first time):
1. Run contamination check (FR-003): abort with CONTAMINATED flag if any Phase A finding contains a verbatim planted issue ID
2. Filter benchmark-key.md to `applicable_gate = current gate` — only these issues are scored
3. For each applicable PlantedIssue, score against Phase A findings using FR-006 rules
4. Issues in other gates are excluded from the denominator (not counted as "Missed")
5. Compute: unique contribution by agent, overlap clusters (from synthesis judge output), false positive records, scored issues
6. Append Panel Efficiency Report (with Limitations header per validity model) to terminal output and save to run file

---

### Compare Mode (`--compare`)

Reads the three most recent run files for the specified gate (one per rigor level) and
produces the Coverage by Rigor Level comparison table.

**Input**:
- `specs/000-review-benchmark/runs/*-<gate>-FULL-run*.md` (most recent)
- `specs/000-review-benchmark/runs/*-<gate>-STANDARD-run*.md` (most recent)
- `specs/000-review-benchmark/runs/*-<gate>-LIGHTWEIGHT-run*.md` (most recent)

**Output**:
1. Terminal: Coverage by Rigor Level table + PASS/FAIL verdict for STANDARD
2. No file saved (comparison is derived from existing run files)

**PASS/FAIL verdict** (SC-003): PASS = zero CRITICAL planted issues missed at STANDARD; FAIL = one or more CRITICAL issues missed.

---

## Panel Efficiency Report Format

```markdown
## Panel Efficiency Report

**Mode**: Benchmark
**Panel**: [agent names]
**Gate**: [spec / plan / task / pre-implementation]
**Rigor**: [FULL / STANDARD / LIGHTWEIGHT]
**Run**: [YYYY-MM-DD run N]
**Contamination**: CLEAN | CONTAMINATED (if contaminated, report stops here)

### Unique Contribution by Agent

| Agent | Unique Findings | Shared Findings | Unique Rate |
|-------|----------------|-----------------|-------------|
| [agent] | N | N | N% |

### Overlap Clusters

Issues raised by 2+ agents:

| Finding Topic | Agents | Overlap Type | Verdict |
|---------------|--------|--------------|---------|
| [topic] | agent-a, agent-b | Same framing / Different angle | Redundant / Keep both |

### False Positive Rate *(benchmark mode only)*

| Agent | False Positives Raised | FP Count |
|-------|----------------------|----------|
| [agent] | [finding text] | N |

### Miss Rate *(benchmark mode only)*

| Planted Issue | Expected Agent | Caught By | Result |
|---------------|---------------|-----------|--------|
| [ID] | [agent] | [agent(s)] | Caught / Caught (partial) / Missed |
```

---

## Coverage by Rigor Level Table Format (compare mode)

```markdown
## Coverage by Rigor Level

**Gate**: [spec / plan / task]
**Runs compared**: [FULL: date run N], [STANDARD: date run N], [LIGHTWEIGHT: date run N]

| Issue ID | Severity | FULL | STANDARD | LIGHTWEIGHT |
|----------|----------|------|----------|-------------|
| PROD-1   | HIGH     | Caught | Missed | Missed |
| SEC-2    | CRITICAL | Caught | Caught (partial) | Missed |
| ...      | ...      | ...  | ...      | ...         |

### STANDARD Verdict: PASS / FAIL

**Basis**: [N] CRITICAL issues at STANDARD — [Caught all / Missed: list IDs]
```

---

## Error States

| Condition | Behavior |
|---|---|
| Contamination detected | Abort scoring, output `CONTAMINATION DETECTED`, prompt re-run |
| Run file for a rigor level missing (compare mode) | Error: "No [RIGOR] run found for gate [gate]. Run `/speckit.review-profile [gate] --rigor [RIGOR]` first." |
| All three run files missing (compare mode) | Error: "No benchmark runs found. Run all three rigor levels first." |
| fixture/ directory missing | Error: "Benchmark fixture not found at specs/000-review-benchmark/fixture/. Run the benchmark setup tasks first." |
