# Plan: Review Efficiency Profiler

**Feature Branch**: `001-review-efficiency-profiler`
**Created**: 2026-04-02
**Status**: Ready to implement
**Context**: Designed in conversation — structural changes already merged to main (2026-04-02).

## Background

The `/speckit.review` panel runs 4-5 agents in parallel, each independently reading the
same artifacts. We made four structural changes in session (already committed):

1. **Constitution injection** — orchestrator pre-reads constitution, injects `CALIBRATION_BLOCK`
   into each agent prompt. Agents no longer read constitution.md themselves.
2. **Phase B scoping** — devil's advocate receives consensus summary only (findings raised by
   2+ reviewers), not full reports. Orchestrator builds summary before contacting DA.
3. **Scope boundaries** — delivery-reviewer owns execution risk; systems-architect owns
   dependency correctness. Each has explicit "Do NOT cover X" directives.
4. **Quality floor removed** — "MUST identify 3 concerns" replaced with "quality over quantity"
   across all specialist agents.

The next step is an empirical test harness to measure whether these changes (and future ones)
actually reduce overlap without losing signal.

---

## What to Build

### 1. Benchmark Artifact Set

Location: `specs/000-review-benchmark/`

A canonical spec/plan/tasks triplet with **deliberately planted issues** of known types.
Agents never see the key file; it's only used to score results afterward.

#### `specs/000-review-benchmark/spec.md`

Scenario: a simple user notification preferences feature for a web app.

**Planted issues:**
- `PROD-1` (HIGH) — Missing persona: admin users can't manage notification settings for
  other users. No story covers this. *(Expected catcher: product-strategist)*
- `PROD-2` (MEDIUM) — P1 and P2 priorities are reversed: the story about email preferences
  is P2 but it's the core use case; push notification (P1) is an enhancement.
  *(Expected catcher: product-strategist)*
- `SEC-1` (HIGH) — No requirement specifies that users can only modify their own preferences
  (missing authorization requirement — IDOR setup). *(Expected catcher: security-reviewer)*
- `FALSE-1` — A requirement that looks ambiguous but is actually intentionally scoped narrow.
  Any agent raising this as a gap is a false positive.

#### `specs/000-review-benchmark/plan.md`

Scenario: REST API + React frontend for notification preferences.

**Planted issues:**
- `ARCH-1` (HIGH) — Single preferences table shared by email, push, and SMS channels with
  a nullable-column-per-channel pattern. No ADR documents this schema decision. Doesn't
  scale when a 4th channel is added. *(Expected catcher: systems-architect)*
- `ARCH-2` (MEDIUM) — A Redis dependency is introduced in the plan for rate limiting but
  doesn't appear in the stack table, no ADR documents it, and it creates a new SPOF.
  *(Expected catcher: systems-architect or consistency-auditor)*
- `SEC-2` (CRITICAL) — No mention of rate limiting on the preference-update endpoint. The
  Redis plan exists but isn't wired to the endpoint. *(Expected catcher: security-reviewer)*
- `FALSE-2` — Architecture decision that looks underspecified but is intentionally deferred
  to a documented ADR (reference included). Any agent raising this as a gap is a false positive.

#### `specs/000-review-benchmark/tasks.md`

**Planted issues:**
- `DEL-1` (HIGH) — Test tasks for User Story 2 are written AFTER the implementation tasks
  by task ID, violating TDD ordering. *(Expected catcher: delivery-reviewer)*
- `DEL-2` (MEDIUM) — Two tasks marked `[P]` share a write to the same config file (a hidden
  state conflict). *(Expected catcher: delivery-reviewer or systems-architect)*
- `ARCH-3` (MEDIUM) — Redis setup task appears in Phase 3 (User Story 1) rather than Phase 2
  (Foundational), meaning Story 2's rate limiting tasks have a hidden dependency on a
  later phase. *(Expected catcher: systems-architect)*
- `FALSE-3` — A task that looks like it's missing a test but the test is covered by an
  integration task two IDs later (clearly referenced). False positive if raised.

#### `specs/000-review-benchmark/benchmark-key.md`

```markdown
# Benchmark Key (NOT visible to review agents)

| ID | Type | Severity | Artifact | Description | Expected Agent | Overlap Risk |
|----|------|----------|----------|-------------|----------------|--------------|
| PROD-1 | Missing persona | HIGH | spec.md | Admin user story absent | product-strategist | low |
| PROD-2 | Wrong priority | MEDIUM | spec.md | P1/P2 reversed | product-strategist | low |
| SEC-1 | Auth gap | HIGH | spec.md | No IDOR protection requirement | security-reviewer | medium (DA) |
| ARCH-1 | Schema decision | HIGH | plan.md | Nullable-column pattern, no ADR | systems-architect | low |
| ARCH-2 | Missing dependency | MEDIUM | plan.md | Redis undocumented | systems-architect | medium (DA) |
| SEC-2 | Missing control | CRITICAL | plan.md | Rate limiting unconnected | security-reviewer | medium (DA) |
| DEL-1 | TDD violation | HIGH | tasks.md | Tests after impl by ID | delivery-reviewer | low |
| DEL-2 | False parallel | MEDIUM | tasks.md | Shared config write under [P] | delivery-reviewer | medium (arch) |
| ARCH-3 | Wrong phase | MEDIUM | tasks.md | Redis in story phase not foundational | systems-architect | medium (delivery) |
| FALSE-1 | — | — | spec.md | Intentionally narrow scope | none | — |
| FALSE-2 | — | — | plan.md | Deferred to existing ADR | none | — |
| FALSE-3 | — | — | tasks.md | Test covered later in same story | none | — |
```

---

### 2. `/speckit.review-profile` Command

Location: `.claude/commands/speckit.review-profile.md`

This command runs a review on the benchmark (or any specified feature) and appends an
efficiency report to the synthesis output.

#### What it does differently from `/speckit.review`

1. Tags each Phase A finding with `[AGENT_NAME]` as it collects outputs
2. After synthesis, runs a second pass over all Phase A outputs to build the overlap matrix
3. Scores each agent against the benchmark key (if reviewing `000-review-benchmark`)
4. Appends the Panel Efficiency Report to the synthesis output

#### Panel Efficiency Report format

```markdown
## Panel Efficiency Report

**Mode**: [Benchmark / Live — benchmark if reviewing 000-review-benchmark]
**Panel**: [agent names]
**Gate**: [spec / plan / task / pre-implementation]

### Unique Contribution by Agent
| Agent | Unique Findings | Shared Findings | Unique Rate | Tokens Est. |
|-------|----------------|-----------------|-------------|-------------|

### Overlap Clusters
Issues raised by 2+ agents (same finding, possibly different framing):
| Finding Topic | Agents | Overlap Type | Verdict |
|---------------|--------|--------------|---------|
| [topic] | agent-a, agent-b | Same framing / Different angle | Keep both / Redundant |

### False Positive Rate (benchmark mode only)
| Agent | False Positives Raised | FP Rate |
|-------|----------------------|---------|

### Miss Rate (benchmark mode only)
| Planted Issue | Expected Agent | Caught By | Result |
|---------------|---------------|-----------|--------|

### Coverage by Rigor Level (benchmark mode only)
Run the benchmark at FULL, STANDARD, and LIGHTWEIGHT to populate:
| Issue ID | Severity | FULL | STANDARD | LIGHTWEIGHT |
|----------|----------|------|----------|-------------|

### Recommendations
[Agent-specific recommendations based on this run's overlap data]
```

---

### 3. Calibration comparison runs

After the command exists, run three benchmark passes:
1. `FULL` panel (all agents)
2. `STANDARD` panel (reduced agents)
3. `LIGHTWEIGHT` panel (devil's advocate only)

Compare which planted issues are caught at each level. This produces the data needed to
decide whether STANDARD panels can be the default for lower-stakes projects without
meaningful signal loss.

---

## Implementation Order

1. **Create `specs/000-review-benchmark/`** — spec.md, plan.md, tasks.md, benchmark-key.md
   - Write realistic-looking artifacts (not obviously synthetic)
   - Plant issues subtly enough that agents have to actually reason, not pattern-match
   - Each false positive should be a genuine trap, not obviously fine

2. **Create `.claude/commands/speckit.review-profile.md`**
   - Base it on speckit.review.md structure
   - Add finding-tagging logic to Phase A collection
   - Add overlap matrix construction between Phase A and synthesis
   - Add benchmark scoring pass (benchmark-key.md lookup)

3. **Run all three calibration passes**
   - Document results in `specs/001-review-efficiency-profiler/results.md`
   - Use findings to propose next round of agent tuning

---

## Success Criteria

- Each agent's unique contribution rate is measurable
- Overlap clusters are identified with verdict (genuine different angle vs. redundant)
- False positive rate per agent is known
- Miss rate per planted issue type is known
- We have data to answer: "Does STANDARD catch enough CRITICAL/HIGH to be the default?"

---

## Files to Create

```
specs/000-review-benchmark/
  spec.md
  plan.md
  tasks.md
  benchmark-key.md          ← not readable by review agents
.claude/commands/
  speckit.review-profile.md
specs/001-review-efficiency-profiler/
  plan.md                   ← this file
  results.md                ← created after runs
```
