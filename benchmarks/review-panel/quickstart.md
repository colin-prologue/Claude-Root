# Quickstart: Review Panel Benchmark

**Feature Branch**: `000-review-benchmark`

## What This Is

A repeatable benchmark for measuring Spec-Kit review panel efficiency. Run it whenever you
tune agent prompts, change panel composition, or adjust the review protocol, to check
whether signal quality improved or regressed.

## Prerequisites

- Branch: `000-review-benchmark` (or main after merge)
- Agent Teams enabled: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- Fixture artifacts built: `specs/000-review-benchmark/fixture/` exists with spec.md, plan.md, tasks.md
- Benchmark key built: `specs/000-review-benchmark/benchmark-key.md` exists

## Running a Benchmark

### Single run (review mode)

```
/speckit.review-profile spec --rigor FULL
/speckit.review-profile spec --rigor STANDARD
/speckit.review-profile spec --rigor LIGHTWEIGHT
```

Each run saves a report to `specs/000-review-benchmark/runs/`.

### Compare three runs

After running all three rigor levels:

```
/speckit.review-profile --compare spec
```

Outputs the Coverage by Rigor Level table and a PASS/FAIL verdict for STANDARD.

## Interpreting Results

**Miss Rate table**: Each of the 12 planted issues shows Caught / Caught (partial) / Missed.
Focus on CRITICAL and HIGH items — these are the ones that matter for panel default decisions.

**STANDARD verdict**:
- **PASS**: Zero CRITICAL issues missed at STANDARD. STANDARD is likely safe as a default
  for lower-stakes projects.
- **FAIL**: One or more CRITICAL issues missed. Review which issues were missed and consider
  whether the missing agents (those in FULL but not STANDARD) are needed for the issue type.

**Unique Contribution table**: Shows which agents add independent signal vs. echo each other.
An agent with <20% unique contribution rate is a candidate for removal from STANDARD.

**External validity caveat**: These results measure detection of discrete, known planted
issues in synthetic artifacts. Real-world performance may differ for emergent, systemic, or
ambiguous problems. Use results as directional signal, not absolute truth.

## Known Limitations

- Single run per rigor level: results are indicative, not statistically significant
- Profiled behavior differs slightly from standard `/speckit.review` (agents are asked to
  tag findings and the synthesis judge is asked to tag overlap clusters)
- Three FALSE-* traps (one per artifact) give limited false-positive data per agent

## Falsification Criteria

The benchmark has lost discriminative power when either of the following conditions holds:

1. **Fixture too obvious from repeated exposure**: If any rigor level scores ≥95% catch rate
   across all HIGH and CRITICAL planted issues, the fixture may need refreshing. Agents that
   have seen the fixture in prior sessions may recognize patterns rather than reasoning to them.
   Consider replacing planted issues with structurally similar but content-distinct variants.

2. **Panel size no longer discriminates**: If FULL and LIGHTWEIGHT produce identical Miss Rate
   tables across two consecutive runs, planted issues may be trivially detectable regardless of
   panel composition. Review each fixture issue for keyword-detectability (SC-005): if any issue
   can be surfaced by matching on "missing", "undocumented", or similar signal words without
   content reasoning, revise that issue.

## Calibration Run Observations

**2026-04-03 — First calibration run (spec gate only)**

| Issue | FULL | STANDARD | LIGHTWEIGHT |
|---|---|---|---|
| PROD-1 (HIGH) | Caught | Caught | Missed |
| PROD-2 (MEDIUM) | Caught (partial) | Caught (partial) | Missed |
| SEC-1 (HIGH) | Caught | Missed | Missed |
| FALSE-1 (FP trap) | Not raised ✓ | False positive (DA) | False positive (DA) |

Key observations:
- SEC-1 detection depends on the security-reviewer being in the panel (FULL only). STANDARD and
  LIGHTWEIGHT both missed it, consistent with expected behavior since security-reviewer is absent
  from both smaller panels.
- PROD-2 was caught only partially at all rigor levels — the business-reach framing (email =
  100% user coverage, push = mobile only) was not surfaced in Phase A by any agent. It emerged
  only via the devil's advocate in Phase B cross-examination during FULL. This may indicate PROD-2
  needs slightly stronger implicit signal in the fixture.
- FALSE-1 trap (OQ-2 master toggle) was triggered by the devil's advocate at MEDIUM in both
  STANDARD and LIGHTWEIGHT runs, but not in the FULL run (where a product-strategist was present
  and framed it as LOW with hedging). This is consistent with the DA's adversarial framing style.
- Detection rates are well within the falsification bounds: no rigor level approaches 95% on
  HIGH/CRITICAL issues, and FULL vs. LIGHTWEIGHT show meaningful differentiation.

## Files

| File | Purpose |
|---|---|
| `fixture/spec.md` | Synthetic spec with PROD-1, PROD-2, SEC-1, FALSE-1 |
| `fixture/plan.md` | Synthetic plan with ARCH-1, ARCH-2, SEC-2, FALSE-2 |
| `fixture/tasks.md` | Synthetic tasks with DEL-1, DEL-2, ARCH-3, FALSE-3 |
| `benchmark-key.md` | Scoring table — do not share with agents |
| `runs/` | Saved run reports (one file per run) |
