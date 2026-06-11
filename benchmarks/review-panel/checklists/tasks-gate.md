# Tasks-Gate Checklist: Review Panel Benchmark

**Purpose**: Validate that tasks.md adequately covers all requirements before implementation begins. Tests requirement completeness, clarity, and traceability — not whether implementation works.
**Created**: 2026-04-03
**Feature**: [spec.md](../spec.md) | [plan.md](../plan.md) | [tasks.md](../tasks.md)
**Scope**: Both fixture artifact requirements and command interface requirements (equally weighted)
**Risk gating**: Five named plan risks each have an explicit mandatory check

---

## Requirement Completeness — Fixture Artifacts

- [x] CHK001 Are all 12 planted issue IDs (PROD-1, PROD-2, SEC-1, FALSE-1, ARCH-1, ARCH-2, SEC-2, FALSE-2, DEL-1, DEL-2, ARCH-3, FALSE-3) individually named in T003–T005 with their issue type and severity specified? [Completeness, Spec §FR-002, tasks.md §T003–T005] — **Resolved**: Added explicit severities to all 12 IDs in T003–T005: PROD-1 (HIGH), PROD-2 (MEDIUM), SEC-1 (HIGH), ARCH-1 (HIGH), ARCH-2 (MEDIUM), DEL-1 (HIGH), DEL-2 (MEDIUM), ARCH-3 (MEDIUM); FALSE-* entries labeled as false positive.

- [x] CHK002 Does T003 specify the planted mechanism for each of its four issues with enough detail that a writer can embed them without re-reading plan.md — i.e., are "missing admin persona," "P1/P2 priority reversal," "no authorization requirement / IDOR setup," and the narrow-scope FALSE-1 framing each described? [Completeness, tasks.md §T003] — **Verified**: T003 names all four mechanisms explicitly: PROD-1 (missing admin persona), PROD-2 (P1/P2 priority reversal), SEC-1 (no authorization requirement / IDOR setup), FALSE-1 (intentionally narrow scope that looks ambiguous). Each description is sufficient to embed the issue without consulting plan.md.

- [x] CHK003 Does T004 specify that SEC-2 is CRITICAL severity and that its planted mechanism is rate limiting planned but not wired to the preference-update endpoint — the precise detail an implementer needs to write a convincing fixture without accidentally making it trivially detectable? [Clarity, tasks.md §T004] — **Verified**: T004 states "SEC-2 (CRITICAL: rate limiting planned but not wired to preference-update endpoint)" — both severity and exact mechanism are present.

- [x] CHK004 Does T005 specify that DEL-2's planted mechanism is a write conflict on a *shared config file* (not just any shared resource) — the level of specificity required for the false-positive distinction between DEL-2 and FALSE-3 to hold? [Clarity, tasks.md §T005] — **Verified**: T005 states "DEL-2 (two [P]-marked tasks share a write to the same config file)" — the "config file" specificity is present, not just "shared resource."

- [x] CHK005 Are the authorship guidelines for false-positive traps (FALSE-1, FALSE-2, FALSE-3) — that they must look exactly like the issue they mimic — specified with enough detail in tasks.md that a writer can distinguish intentional ambiguity from planted real issues? [Clarity, plan.md §Authorship Guidelines, Gap] — **Resolved**: Inlined the authorship rule into each of T003, T004, T005: "false positives must look exactly like the issue they mimic — not merely ambiguous, but actively mimicking the structure of a real gap so an agent raising it cannot be faulted for the reasoning." Each task also specifies the per-issue mechanism the trap must mimic.

- [x] CHK006 Does any task specify the quality bar SC-005 requires: that agents must reason about content rather than pattern-match on keywords like "missing" or "undocumented"? Is this constraint visible to the fixture author from tasks.md alone? [Completeness, Spec §SC-005] — **Resolved**: Added SC-005 inline sentence to T004 and T005; T003 covered by T007 pilot gate.

---

## Requirement Completeness — Benchmark Key

- [x] CHK007 Does T006 enumerate all eight PlantedIssue fields from the data model (id, type, severity, artifact, description, expected_catcher, overlap_risk, applicable_gate) so an implementer can produce a schema-correct benchmark-key.md without reading data-model.md separately? [Completeness, data-model.md §PlantedIssue, tasks.md §T006] — **Verified**: T006 explicitly lists all eight fields: "(id, type, severity, artifact, description, expected_catcher, overlap_risk, applicable_gate)" — no data-model.md cross-reference needed to produce a schema-correct table.

- [x] CHK008 Does T006 state the constraint that exactly 12 rows are required with the 3-real-plus-1-false-positive distribution per artifact? [Completeness, data-model.md §PlantedIssue Constraints] — **Resolved**: Added "exactly 4 rows per artifact (3 real issues + 1 false positive each)" to T006.

- [x] CHK009 Does T006 specify that FALSE-* entries must have severity = "—" and expected_catcher = "none," and that all other entries must have non-null values for both fields? [Completeness, data-model.md §PlantedIssue Constraints] — **Resolved**: Added FALSE-* field constraints and non-null requirement to T006.

- [x] CHK010 Does T006 specify the applicable_gate mapping rule (spec.md issues → `spec`; plan.md → `plan`; tasks.md → `task`) explicitly enough that an implementer cannot assign the wrong gate? [Clarity, data-model.md §PlantedIssue, Spec §FR-003] — **Verified**: T006 states "`applicable_gate` must correctly map: spec.md issues → `spec`, plan.md issues → `plan`, tasks.md issues → `task`" — the mapping is explicit and unambiguous.

---

## Requirement Completeness — Command Interface

- [x] CHK011 Does T008 specify the finding-tag format per FR-004 — `[agent-name] | severity | category | location | finding` — so the tagging instruction injected into Phase A agents is unambiguous? [Completeness, Spec §FR-004, tasks.md §T008] — **Verified**: T008 includes the finding-tag instruction with the exact five-field pipe-separated format: "`[agent-name] | severity | category | location | finding`".

- [x] CHK012 Does T008 specify the synthesis judge's structured overlap output schema (four-column table: `| Finding Topic | Agents | Overlap Type | Verdict |`) and the fallback behavior when the schema is absent (log warning, skip overlap table, do not fail the run)? [Completeness, Spec §FR-005, contracts §Panel Efficiency Report] — **Resolved**: Added "skip overlap table — do not fail the run" to T008 fallback behavior.

- [x] CHK013 Does T008 specify the contamination check logic with enough precision: that the scan looks for *exact issue IDs* (e.g., `PROD-1`, `SEC-1`) and not prefixes (e.g., `SEC` alone), and that detection aborts scoring rather than proceeding? [Clarity, Spec §FR-003, plan.md §Risk Assessment] — **Resolved**: Added "full IDs only, not prefixes like `SEC` or `PROD` alone" to T008 contamination check.

- [x] CHK014 Does T008 specify the gate-scoped scoring filter — that benchmark-key.md must be filtered to `applicable_gate = current gate` before scoring begins, and that out-of-gate issues are excluded from the denominator (not counted as Missed)? [Completeness, data-model.md §PlantedIssue Constraints, plan.md §BLOCK-3] — **Resolved**: Added "out-of-gate issues are excluded from the denominator entirely, not counted as Missed" to T008 scoring pass step (b).

- [x] CHK015 Does T008 specify all three FR-006 scoring outcomes (Caught / Caught (partial) / Missed) with the distinguishing criterion for each — correct artifact section + core problem area for Caught; correct artifact but wrong framing or partial identification for Caught (partial)? [Completeness, Spec §FR-006] — **Resolved**: Inlined all three scoring criteria in T008 scoring pass step (c).

- [x] CHK016 Does T008 specify the run file naming convention (`YYYY-MM-DD-<gate>-<RIGOR>-run<N>.md`) and the run-number increment logic for same-day same-gate same-rigor collisions? [Completeness, Spec §FR-007] — **Verified**: T008 states "save to `specs/000-review-benchmark/runs/YYYY-MM-DD-<gate>-<RIGOR>-run<N>.md` (increment run N if same-day same-gate same-rigor file exists)" — naming format and collision-handling rule are both present.

- [x] CHK017 Does T008 specify that the Limitations header is required in the Panel Efficiency Report — and is its *content* specified (what the limitations are), or only its existence? [Clarity, plan.md §Validity Model, Ambiguity] — **Resolved**: Inlined required Limitations header content in T008: semantic judgment, unknown error margin, deltas-only interpretation.

- [x] CHK018 Does T010 specify the Coverage by Rigor Level table schema (`| Issue ID | Severity | FULL | STANDARD | LIGHTWEIGHT |`) so an implementer can produce the correct output format without consulting the contract separately? [Completeness, contracts §Coverage by Rigor Level, tasks.md §T010] — **Verified**: T010 specifies "build Coverage by Rigor Level table (`| Issue ID | Severity | FULL | STANDARD | LIGHTWEIGHT |`)" — all five columns are named inline.

- [x] CHK019 Does T010 specify all three error states for compare mode: (a) one run file missing, (b) all three missing, (c) fixture directory missing — with the exact error message format from the contract? [Coverage, contracts §Error States, tasks.md §T010] — **Resolved**: Added (c) fixture directory missing error state and reference to contracts §Error States for exact message formats.

- [x] CHK020 Does T010 specify that the PASS/FAIL verdict is based on CRITICAL-severity issues only (not HIGH), matching SC-003? [Clarity, Spec §SC-003, tasks.md §T010] — **Verified**: T010 states "compute PASS/FAIL verdict for STANDARD (PASS = zero CRITICAL issues missed)" — CRITICAL-only basis is explicit; HIGH is not included.

---

## Pilot Validation Gate Clarity

- [x] CHK021 Are the T007 pass criteria binary enough to make an unambiguous go/no-go determination — specifically, is the distinction between "agent quotes exact signal text" (fail) and "agent raises the issue through reasoning" (pass) defined precisely enough for a single evaluator to apply consistently? [Clarity, Measurability, tasks.md §T007] — **Resolved**: Replaced "genuine reasoning (not by quoting an exact phrase)" with an operational threshold: a finding fails if it reproduces ≥4 consecutive words from any single sentence in fixture/spec.md verbatim. A finding that paraphrases is a pass; a finding that quotes is a fail. This gives a single evaluator a mechanical check rather than a judgment call.

- [x] CHK022 Does T007 define what a FALSE-1 false-positive result looks like: is it "raised with confidence" vs. "not raised at all" vs. "raised with hedging"? Are all three outcomes defined and mapped to pass/fail? [Clarity, tasks.md §T007, Gap] — **Resolved**: Added explicit FALSE-1 warning case to T007: if raised as genuine HIGH/MEDIUM concern (not hedged), revise false-positive framing before proceeding.

- [x] CHK023 Does the tasks.md HARD GATE enforcement specify what happens to T008–T016 if T007 never passes — is there a stopping condition, or does the gate only delay (retry until pass)? [Completeness, tasks.md §T007, Gap] — **Resolved**: Added stopping condition to T007: after 3 consecutive failures for the same planted issue, stop retrying and revisit the planted issue design — the issue type may be inherently too detectable in this artifact format. Document the finding and decide whether to replace the issue before proceeding.

---

## Risk Mitigation Coverage

- [x] CHK024 **Risk: Fixture too obvious** — Is the mitigation (pilot validation + authorship guidelines) traceable from a specific task (T007) with pass criteria that would actually detect a "too obvious" fixture, rather than only detecting a "not found" failure? [Risk, plan.md §Risk Assessment] — **Resolved**: Added a too-obvious check to T007: after a passing run, if any planted issue finding was raised in ≤2 sentences with no cross-referencing of other artifact sections, the issue may be trivially obvious even without verbatim quoting — optionally add misleading context to increase reasoning depth. This catches implicit-but-obvious scenarios the verbatim threshold alone misses.

- [x] CHK025 **Risk: Contamination false positives** — Is the mitigation (check for full IDs only, not prefixes) specified in T008 with enough precision that an implementer cannot accidentally write a check that triggers on partial matches like `SEC` or `PROD` in normal finding text? [Risk, plan.md §Risk Assessment, Clarity] — **Verified**: T008 states "match full IDs only, not prefixes like `SEC` or `PROD` alone" — the boundary is explicit and the anti-pattern example is given, leaving no ambiguity for an implementer.

- [x] CHK026 **Risk: Scoring variance** — Is the mitigation (same model+prompt across all compared runs) documented in any task as a requirement the command must communicate to the user, or only in the plan's Limitations section? If only in the plan, is there a gap in the command's Limitations header requirements? [Risk, plan.md §Validity Model, Gap] — **Resolved**: Added a validity pre-condition output to T010's --compare branch: before displaying the comparison table, the command must output a warning that comparisons are only meaningful when all three runs used the same Claude model version and FR-006 scoring rule text. This surfaces the constraint at the point of use, not only post-hoc in the Limitations header.

- [x] CHK027 **Risk: Context window exceeded** — Is the mitigation (start with spec gate only; plan and tasks gates deferred) reflected in the task sequencing, and is there a task that validates context window fit before attempting multi-artifact gates? [Risk, plan.md §Risk Assessment, Gap] — **Resolved**: Added context window note to T007: confirm the spec-gate review completes without context-length errors before proceeding; if errors occur even at spec gate, reduce fixture length. Also notes that plan/task gate reviews (multi-artifact) are deferred — giving future maintainers explicit guidance that context window fit must be validated before extending to those gates.

- [x] CHK028 **Risk: Panel composition drift** — Is the mitigation (maintenance note in command file referencing speckit.review.md) specified as a required deliverable of T008, or only mentioned in the notes section of tasks.md? [Risk, plan.md §Risk Assessment, ADR-007] — **Verified**: T008 explicitly requires "include maintenance note that panel compositions must stay in sync with `.claude/commands/speckit.review.md`" as part of the Panel Efficiency Report deliverable — it is a required output of T008, not just a note in tasks.md.

---

## Scoring & Validity Model Requirements

- [x] CHK029 Is the validity condition "same scorer, same prompt across all runs being compared" specified as a requirement the command must state in its output — i.e., is there a task that ensures this condition is communicated to users at run time, not only documented in plan.md? [Completeness, plan.md §Validity Model, Gap] — **Verified**: T008 requires the Limitations header to state "only deltas between same-scorer same-model runs are reliably interpretable" — this is a required content element in every Panel Efficiency Report, ensuring the condition is communicated at run time. Note CHK026 flags the separate gap that `--compare` mode does not enforce this as a pre-condition check.

- [x] CHK030 Are the falsification criteria (≥95% catch rate across all HIGH/CRITICAL; or FULL and LIGHTWEIGHT produce identical Miss Rate tables across two consecutive runs) documented in any deliverable task, so a future maintainer knows when the benchmark needs refreshing? [Completeness, plan.md §Validity Model, Gap] — **Resolved**: Updated T014 to unconditionally require both falsification criteria in quickstart.md §Known Limitations.

- [x] CHK031 Is the scoring variance acknowledgement — that absolute detection rates have an unknown error margin and only deltas between same-scorer runs are reliably interpretable — required to appear in every Panel Efficiency Report's Limitations header, and is this stated in T008 as a content requirement rather than a format requirement? [Clarity, plan.md §Validity Model] — **Verified**: T008 states "Limitations header — header must state: scoring requires semantic judgment; absolute detection rates have unknown error margin; only deltas between same-scorer same-model runs are reliably interpretable" — the three required statements are content requirements (must state X), not structural placeholders.

---

## Task Dependency & Traceability

- [x] CHK032 Does each task in Phase 3 (T008–T009) trace to at least one FR or SC requirement from spec.md — are the traceability references present in the task descriptions, or must an implementer cross-reference the spec independently? [Traceability, Gap] — **Resolved**: Added FR-003, FR-005, FR-007, and data-model references to each T009 validation criterion.

- [x] CHK033 Are the dependencies between T010, T011, T012, and T013 made explicit — specifically, that T013 requires a FULL run file (from T009), a STANDARD run file (from T011), and a LIGHTWEIGHT run file (from T012) to be present simultaneously? [Completeness, Dependency, tasks.md §Dependencies] — **Verified**: tasks.md §Dependencies states "T013 depends on T009, T011, T012" — all three run-producing tasks are listed as co-dependencies, making the simultaneous requirement explicit.

- [x] CHK034 Are T003, T004, T005 safely parallelizable — do they write to different files with no shared state? Is there a risk that two parallel writers could produce inconsistent planted issue IDs across fixture files that only benchmark-key.md would reveal? [Consistency, tasks.md §T003–T005] — **Verified**: T003 writes `fixture/spec.md` (PROD-1/PROD-2/SEC-1/FALSE-1), T004 writes `fixture/plan.md` (ARCH-1/ARCH-2/SEC-2/FALSE-2), T005 writes `fixture/tasks.md` (DEL-1/DEL-2/ARCH-3/FALSE-3). Each task owns a disjoint set of planted issue IDs and a different output file — no shared state, no ID overlap risk. T006 (benchmark-key.md) is sequential and serves as the reconciliation point for any description inconsistencies.

- [x] CHK035 Is there a task for updating `CLAUDE.md` to document the new `/speckit.review-profile` command per the Definition of Done requirement ("CLAUDE.md reflects any new commands, dependencies, or structure changes")? [Coverage, conventions.md §Definition of Done, Gap] — **Resolved**: Added T017 to Phase 5 Polish to update CLAUDE.md §Recent Changes.

---

## Notes

- Check items off as completed: `[x]`
- Items marked `[Gap]` indicate a suspected missing requirement — verify against the source artifact before marking pass/fail
- Items with `[Ambiguity]` require a judgment call; document your interpretation inline if the requirement is borderline
- A failing item means the requirement in spec/plan/tasks needs to be clarified *before* implementation begins — not that the implementation is wrong
- Traceability references: `[Spec §X]` = spec.md requirement; `[plan.md §X]` = plan section; `[tasks.md §X]` = task ID; `[contracts §X]` = review-profile-command.md; `[data-model.md §X]` = entity field
