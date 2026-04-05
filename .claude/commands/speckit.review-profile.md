---
description: Run a benchmark review of the panel efficiency fixture with finding-tagging, overlap extraction, and a Panel Efficiency Report. Supports --compare mode to merge rigor-level run files into a Coverage by Rigor Level table.
---

## User Input

```text
$ARGUMENTS
```

**MAINTENANCE NOTE**: Panel compositions in this command MUST stay in sync with
`.claude/commands/speckit.review.md`. If panels in speckit.review.md change, update
the compositions below in Branch A Step 3 to match. Divergence invalidates benchmark
comparisons (ADR-007).

---

## Parse Arguments

Parse `$ARGUMENTS`:

- Extract `gate`: first positional token — one of `spec`, `plan`, `task`, `pre-implementation`
- Extract `--rigor`: value after `--rigor` flag — one of `FULL`, `STANDARD`, `LIGHTWEIGHT`; default `FULL` if absent
- Detect `--compare` flag: if `--compare` is present in `$ARGUMENTS`, route to **Branch B** instead of Branch A

If `--compare` is present: go to **Branch B — Compare Mode**.
Otherwise: proceed with **Branch A — Review Mode**.

---

## Branch A — Review Mode

### Step 1: Validate Prerequisites

Check that `specs/000-review-benchmark/fixture/` exists and contains the artifact for the
requested gate:
- `spec` gate: `specs/000-review-benchmark/fixture/spec.md`
- `plan` gate: `specs/000-review-benchmark/fixture/spec.md` and `fixture/plan.md`
- `task` gate: `specs/000-review-benchmark/fixture/spec.md`, `fixture/plan.md`, and `fixture/tasks.md`

If the fixture directory is missing:
> Error: "Benchmark fixture not found at specs/000-review-benchmark/fixture/. Run the benchmark setup tasks first."

### Step 2: Load Constitution

Read `.specify/memory/constitution.md`. Extract `CALIBRATION_BLOCK`:
- Project Context section (if present) verbatim
- Principles rigor list (e.g., "I:FULL II:NON-NEGOTIABLE …")

**Do NOT pass constitution.md path to agents — inject CALIBRATION_BLOCK directly into
each agent prompt.** benchmark-key.md is NOT loaded at this step; it is read in Step 7 only.

### Step 3: Compose Panel

Select agents based on `gate` and `--rigor`. Panel compositions match production
`/speckit.review` exactly (ADR-007):

| Gate | FULL | STANDARD | LIGHTWEIGHT |
|---|---|---|---|
| spec | product-strategist, security-reviewer, devils-advocate | product-strategist, devils-advocate | devils-advocate |
| plan | systems-architect, security-reviewer, delivery-reviewer, operational-reviewer, devils-advocate | systems-architect, delivery-reviewer, devils-advocate | devils-advocate |
| task | delivery-reviewer, systems-architect, operational-reviewer, devils-advocate | delivery-reviewer, devils-advocate | devils-advocate |

synthesis-judge is always added regardless of rigor level.

### Step 4: Phase A — Independent Analysis (Parallel)

Spawn all panel agents (excluding synthesis-judge) simultaneously. Each agent receives:

```
You are the [AGENT_NAME] reviewer for a benchmark review of a fictional
"User Notification Preferences" feature. Review ONLY the artifacts listed below —
do not read any other files in specs/000-review-benchmark/.

Artifacts for [gate] gate:
[List fixture artifact paths for this gate]

Project context (from constitution — do not re-read the file):
[CALIBRATION_BLOCK]

IMPORTANT — Phase A protocol:
- This is independent analysis. You have NOT seen other reviewers' findings.
- Work independently and produce your findings using your standard output format.
- Quality over quantity. If an artifact section is genuinely sound, state that clearly.
- Tag each finding row with your agent name in this format:
  [agent-name] | SEVERITY | category | location | finding
  (e.g., [product-strategist] | HIGH | Missing persona | User Stories §1 | No admin story)
- Do NOT read specs/000-review-benchmark/benchmark-key.md — it is not an artifact for review.
```

Wait for ALL Phase A agents to complete before proceeding.

Collect all Phase A outputs. Store agent name → findings list mapping for scoring in Step 7.

**CONTAMINATION PRE-SCAN**: After Phase A completes, before Phase B, scan ALL Phase A
findings for the following exact strings: PROD-1, PROD-2, SEC-1, FALSE-1, ARCH-1, ARCH-2,
SEC-2, FALSE-2, DEL-1, DEL-2, ARCH-3, FALSE-3. Match full IDs only (e.g., "SEC-1" matches;
"SEC" alone does not). If any exact ID appears verbatim in any Phase A finding:
- Output: `⚠️ CONTAMINATION DETECTED — benchmark-key.md was referenced by a Phase A agent.`
- Output: `This run is invalid. Re-run after verifying no agent received benchmark-key.md.`
- Set `contamination_flag = true`
- Skip Steps 5–7. Save a run file with contamination flag set. Stop.

### Step 5: Phase B — Cross-Examination (Sequential)

Build consensus summary: findings raised by 2+ agents on the same topic. Note uncovered areas.

Send consensus summary to devil's advocate:

```
Here is the consensus summary from Phase A (findings raised by 2+ reviewers):
[CONSENSUS_SUMMARY]

Also note: these topic areas received no coverage:
[UNCOVERED_AREAS]

Execute your Consensus Challenge protocol:
- Challenge each consensus finding — genuine signal or groupthink?
- Investigate uncovered areas
- Propose at least one reframe of the overall review
```

Share devil's advocate challenges back to each specialist reviewer:

```
The devil's advocate has challenged your findings:
[Devil's advocate output]

Respond to the challenges. You may defend, withdraw, strengthen, or raise new concerns.
Do NOT simply agree with the devil's advocate to avoid conflict.
```

### Step 6: Phase C — Synthesis

Spawn synthesis-judge with all Phase A and Phase B outputs:

```
You are the synthesis judge. Here are all reviewer findings and cross-examination results:

[All Phase A outputs with agent-name tags]
[Devil's advocate challenges]
[All Phase B responses]

Produce the Review Synthesis Report following your standard format.
Preserve majority findings, minority dissents, and unresolved items.

ADDITIONAL REQUIREMENT — Overlap Clusters table:
For each finding topic raised by 2 or more agents, add a cluster row in this exact schema:
| Finding Topic | Agents | Overlap Type | Verdict |
where Overlap Type is one of: Same framing / Different angle / Partial match
and Verdict is one of: Redundant / Keep both

If no findings were raised by 2+ agents, output a warning:
"⚠️ No overlap clusters detected — all Phase A findings were unique per agent."
and skip the table. Do not fail the run.
```

### Step 7: Scoring Pass

**benchmark-key.md is read HERE for the first time. It was never in any agent's context.**

Read `specs/000-review-benchmark/benchmark-key.md`.

**a. Gate filter**: Filter benchmark-key.md to rows where `applicable_gate = [current gate]`.
Issues in other gates are excluded from the denominator entirely — NOT counted as Missed.

For `spec` gate: PROD-1, PROD-2, SEC-1, FALSE-1
For `plan` gate: ARCH-1, ARCH-2, SEC-2, FALSE-2
For `task` gate: DEL-1, DEL-2, ARCH-3, FALSE-3

**b. Score each applicable PlantedIssue** against Phase A findings using FR-006 rules:

- **Caught**: A Phase A finding references the correct artifact section AND addresses the
  core problem area. The finding must be in the agent's own words — reproducing the exact
  signal phrase from the artifact does not qualify unless it is the only way to describe it.
- **Caught (partial)**: Correct artifact section, but wrong framing or only partial
  identification of the issue.
- **Missed**: No Phase A finding addresses the issue.

For FALSE-* entries: record which agents (if any) raised the false-positive trap as a
definitive MEDIUM or HIGH concern without hedging language ("may," "unclear if," "could be
intentional," "possibly out of scope"). These populate the False Positive Rate table. Agents
that raised it WITH hedging, or did not raise it, do not count as false positives.

**c. Compute unique contribution per agent**:
- For each agent: count findings that appear ONLY in that agent's output (not raised by any
  other agent on the same topic). Unique Rate = unique findings / total findings × 100%.

**d. Extract overlap clusters** from the synthesis judge's Phase C output (the structured
table produced in Step 6). If the table is absent, log: "⚠️ No overlap cluster table in
synthesis output — skipping overlap section."

**e. Determine run number**: Look for existing files in `specs/000-review-benchmark/runs/`
matching `YYYY-MM-DD-[gate]-[RIGOR]-run*.md` where YYYY-MM-DD is today's date. If none
exist, run_number = 1. If one or more exist, run_number = highest existing N + 1.

### Step 8: Panel Efficiency Report

Append to terminal output after the synthesis report:

```markdown
---

## Panel Efficiency Report

**Mode**: Benchmark
**Panel**: [comma-separated agent names]
**Gate**: [gate]
**Rigor**: [FULL / STANDARD / LIGHTWEIGHT]
**Run**: [YYYY-MM-DD run N]
**Contamination**: CLEAN

### Unique Contribution by Agent

| Agent | Unique Findings | Shared Findings | Unique Rate |
|-------|----------------|-----------------|-------------|
| [agent] | N | N | N% |

### Overlap Clusters

Issues raised by 2+ agents:

| Finding Topic | Agents | Overlap Type | Verdict |
|---------------|--------|--------------|---------|
| [topic] | agent-a, agent-b | [type] | [verdict] |

*(or the warning message if no clusters)*

### False Positive Rate *(benchmark mode only)*

| Agent | False Positive Raised | Finding Text |
|-------|----------------------|--------------|
| [agent] | [FALSE-N] | [brief finding text] |

*(If no false positives raised by any agent, note: "No false positives raised.")*

### Miss Rate *(benchmark mode only)*

| Planted Issue | Severity | Expected Agent | Caught By | Result |
|---------------|----------|---------------|-----------|--------|
| [ID] | [SEV] | [agent] | [agent(s) or —] | Caught / Caught (partial) / Missed |

*(Only applicable-gate issues appear here — [N] of 12 total planted issues)*

### Limitations

Scoring requires semantic judgment — "describes the core problem area" is not a binary
criterion. Absolute detection rates have an unknown error margin. Only **deltas between
runs scored by the same Claude model version using the same FR-006 rule text** are reliably
interpretable. If model versions differ across runs being compared, deltas may reflect scorer
variance rather than panel differences, not panel quality differences.
```

### Step 9: Save Run File

Save the complete output (synthesis report + Panel Efficiency Report) to:

```
specs/000-review-benchmark/runs/YYYY-MM-DD-[gate]-[RIGOR]-run[N].md
```

where N is the run number determined in Step 7e.

Include at the top of the file:

```markdown
# Benchmark Run: [gate] / [RIGOR] / [YYYY-MM-DD] run [N]

**Panel**: [agent names]
**Contamination**: CLEAN
**Model**: [note Claude model version if known from session context]
```

---

## Branch B — Compare Mode

### Step 1: Detect Gate

Extract `gate` from `$ARGUMENTS` (token after `--compare`).

### Step 2: Locate Run Files

For each rigor level (FULL, STANDARD, LIGHTWEIGHT), find the most recent run file at the
specified gate in `specs/000-review-benchmark/runs/`:

Pattern: `*-[gate]-[RIGOR]-run*.md`

Most recent = lexicographically last filename (YYYY-MM-DD prefix ensures correct date sort;
on same-date tie, highest run-N wins).

**Error states**:
- If a run file for one rigor level is missing:
  > Error: "No [RIGOR] run found for gate [gate]. Run `/speckit.review-profile [gate] --rigor [RIGOR]` first."
- If all three run files are missing:
  > Error: "No benchmark runs found for gate [gate]. Run all three rigor levels first:
  > `/speckit.review-profile [gate] --rigor FULL`
  > `/speckit.review-profile [gate] --rigor STANDARD`
  > `/speckit.review-profile [gate] --rigor LIGHTWEIGHT`"

### Step 3: Extract Miss Rate Tables

Read each located run file. Extract the Miss Rate table section from each Panel Efficiency
Report. Parse the `Result` column (Caught / Caught (partial) / Missed) per planted issue ID.

### Step 4: Build Coverage Table

Produce the Coverage by Rigor Level table:

```markdown
## Coverage by Rigor Level

**Gate**: [gate]
**Runs compared**:
- FULL: [YYYY-MM-DD] run [N]
- STANDARD: [YYYY-MM-DD] run [N]
- LIGHTWEIGHT: [YYYY-MM-DD] run [N]

⚠️ Validity condition: these comparisons are only meaningful when all three runs used
the same Claude model version and the same FR-006 scoring rule text. If model versions
differ across runs, deltas may reflect scorer variance rather than panel differences.

| Issue ID | Severity | FULL | STANDARD | LIGHTWEIGHT |
|----------|----------|------|----------|-------------|
| [ID]     | [SEV]    | [result] | [result] | [result] |

### STANDARD Verdict: PASS / FAIL

**Basis**: STANDARD rigor caught [N] of [M] CRITICAL issues.
[PASS: "Zero CRITICAL issues missed — STANDARD is likely safe as a default for lower-stakes projects."]
[FAIL: "CRITICAL issues missed at STANDARD: [list IDs]. Review whether the missing agents (present in FULL but not STANDARD) are needed for these issue types."]
```

PASS = zero CRITICAL planted issues missed at STANDARD.
FAIL = one or more CRITICAL planted issues missed at STANDARD.

### Step 5: Output

Display the Coverage by Rigor Level table and STANDARD verdict to terminal.
**No file is written in compare mode** — the comparison is derived from existing run files
and is terminal-only per contract.
