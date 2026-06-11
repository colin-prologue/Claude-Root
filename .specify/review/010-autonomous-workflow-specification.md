# Review in Progress: 010-autonomous-workflow — specification gate (re-review post-REVISE)
**Started**: 2026-04-26T01:26:00Z
**Phase**: REVISE applied 2026-04-26 — 11-item edit list executed with oracle Q2/Q3 sharpenings (ADR-016 canonical/derivative; sentinels relocated to `specs/[###]/.run/`)
**Panel**: product-strategist, devils-advocate, synthesis-judge
**Rigor**: STANDARD (gate default; no Principle VIII override; feature has no auth/PII/payments)
**Prior review**: User chose REVISE in response to 10 blockers; spec revised with FR-021..028, ADR-013/014/015, LOG-005..008, scope deferrals to V2, FR-026 completeness predicate, and orchestrator-reads-disk audit model (FR-017).

---

## Phase A: product-strategist

Risk: MEDIUM. 5 findings:

- **F-01 HIGH** (SC-001 vs FR-008): SC-001 promises ≤3 interventions but FR-008 forces BLOCKING at every gate including pre-plan/pre-tasks. A clean review-clarify-plan run already exceeds 3. Internally inconsistent. Confidence 80%.
- **F-02 HIGH** (non-code BLOCKING UX undefined): Spec defines BLOCKING for code gates (proceed/abort) but never specifies what happens at pre-plan/pre-tasks BLOCKING — what's presented, can the developer edit before proceeding, what abort does to written artifacts. Confidence 85%.
- **F-03 MEDIUM** (SC-004 circular): "Developer can reconstruct full reasoning path; verified by retrospective walkthrough" is non-measurable. Recommend reframe as "every transition has non-empty rationale + ≥1 decisions_made item." Confidence 90%.
- **F-04 MEDIUM** (temporal halt UX gap): FR-019 halts on temporal failures but no FR/AS describes the developer-facing message or how to retrigger. US-4 covers explicit resume but not the rate-limit-halt path. Confidence 75%.
- **F-05 MEDIUM** (stale lock recovery): FR-027/FR-028 say lock removed at "clean termination" — no recovery path for crash-leaves-stale-lock. No `--break-lock` flag specified. Confidence 85%.
- **F-06 LOW** (halt-directive dependency): FR-004 depends on review-subagent emitting schema-conformant halt directive; no traceability to verify the existing `/speckit.review` skill is amended.

Value-prop assessment: V1 holds, caveat on SC-001. Dissent note: spec frames BLOCKING-at-non-code-gates as trust-building value; it's actually a scope constraint, not value delivery. Confidence 65%.

## Phase A: devils-advocate (FULL rigor)

**Most dangerous assumption**: ADR-013 conflates "first-class disk artifact" with "verifiable artifact." Same LLM is doing the writing in both designs — moving the write location gives durability, not independent verification. The orchestrator still has no runtime ground truth. Confidence 85%.

**Risky assumptions**:
- Sandbox prohibition on CI/CD/hooks is unenforceable as stated; ADR-012 leaves enforcement mechanism (hook-based vs prompt-only) undecided.
- FR-026 completeness predicate is shape-only ("non-empty mandatory sections", "≥1 task block") — a hallucinated `plan.md` describing a different feature passes.
- Lock recovery on session crash is unspecified; first crash bricks the feature for that branch.
- Codereview-rubber-stamps-implement risk (LOG-007) is acknowledged but unresolved before V1 ships.
- TDD strategy unresolved (LOG-006) yet Principle III is NON-NEGOTIABLE.
- Cross-session lifetime: ADR-015 punts cross-session resume but doesn't say what V1 does when main session ends mid-run with lock held.

**Blind spots not covered by other reviewer**:
1. **FR-020 vs sentinel files contradiction**: `.run-lock` and `.abort` live in `specs/[###]/` which is git-tracked; FR-020 forbids modifying `.gitignore`. Either FR-020 needs an exception, sentinels need to live elsewhere, or spec ships with unresolvable contradiction. Confidence 90%.
2. **Decision-log concurrent-write semantics undefined**: Orchestrator and subagent both append. No locking, atomic-append, or write-ordering protocol. Interleaved/corrupted markdown is possible.
3. **ADR-013 partial-write mitigation** ("append-only with terminal sentinel, orchestrator detects truncation") is a non-trivial protocol invented in passing — needs its own ADR or will be reinvented worse at plan.
4. **Subagent self-classification trust unchanged**: FR-004 trusts `halt_directive: false` set by the same subagent whose findings would warrant halt — exact failure case Q4 was meant to prevent.

**Consensus challenges to prior review**:
- "ADR-013 closes the orchestrator-trust gap" is wrong — ADR-013 makes the trail durable for human after-the-fact review, not runtime ground truth. FR-017 phrasing ("does not trust returned strings as the source of truth") falsely implies disk content is the source of truth.
- "BLOCKING-everywhere is a safe V1 win" overgeneralizes — original argument was about *code* gate cost asymmetry; doesn't justify BLOCKING at pre-plan/pre-tasks where cost asymmetry doesn't apply.

**Strongest dissent**: Ship LOG-005 stage-pair runner as V1 instead. The current V1 spec produces typing-friction value of a stage-pair runner with the implementation surface of a multi-stage orchestrator. With BLOCKING at every gate and no cross-session resume, V1 may not get used long enough to produce V2-driving evidence; the feature gets abandoned. Confidence 65%.


## Phase B: Devil's Advocate Consensus Challenge

**Strongest reframe**: V1 unit should be "stage-pair" not "pipeline." Most of PS's findings (F-01, F-02, F-04) and most of DA's (FR-020 sentinel, lock lifetime, decision-log concurrent semantics, codereview rubber-stamp) collapse if unit is stage-pair. Confidence 75%.

**Genuine consensus**:
- C-1 BLOCKING semantics under-specified at non-code gates (PS F-02 + DA sentinel finding). Confidence 90%.
- C-2 Decision-log integrity hand-waved (PS F-03 + DA concurrent-write/partial-write). Confidence 85%.

**False consensus FC-1**: "FR-008 BLOCKING-everywhere is the problem" — DA argues real issue is BLOCKING-as-control-flow-primitive without defined developer role; PS's F-02 is a downstream symptom.

**Singletons kept**: ADR-013 partial-write protocol violates Principle VII (separate decision deserving own ADR). Codereview rubber-stamp risk (LOG-007). Temporal halt UX (PS only, validated).

**Uncovered surface**:
- U-1 Principle II Simplicity audit — V1 surface (6 new mechanisms) not audited against single-purpose principle.
- U-2 Feature-level success criterion absent — SC-001..007 are run-level; no rule for "V1 succeeded, build V2" vs "retire."
- U-3 Abort + immediate re-trigger interaction (FR-023 vs FR-027) undefined.

**Dissent preserved**: Ship LOG-005 stage-pair runner as V1.

## Phase B: Product-Strategist Response

**Stage-pair reframe REJECTED**. User-perceptible delta: pipeline = "one command, six stages, three pauses"; stage-pair = "six commands, two stages each." Inter-pair typing is exactly the friction this feature removes. If V1 is stage-pair, ADR-015's "V1 evidence" clause cannot test pipeline-mode value, so V2 is unjustified by construction. Confidence 85%. Pipeline-mode V1 stands; LOG-005 correctly classifies stage-pair as fallback, not replacement.

**FC-1 partially accepted**: DA's diagnosis (BLOCKING semantics undefined) is correct; DA's prescription (use stage-pair) is not. F-02 strengthened HIGH → CRITICAL — needs an acceptance scenario, not just UX note.

**U-2 accepted, criterion proposed**:
- **SC-008 (feature-level)**: After ≥5 full pipeline runs in V1, developer reports (a) at least one run where autonomous progression saved verifiable effort vs manual stage-by-stage (completed without more commands than stage-pairs would have required), AND (b) zero runs where autonomous progression produced an artifact the developer would have caught and corrected by manual review. (a) never met across 5 runs ⇒ retire. (b) violated ⇒ re-evaluate before V2.

**U-1 partial agreement**: decisions-log.md, FR-026, FR-027/028 pay rent in V1. **ADR-013's partial-write recovery protocol does NOT pay rent in V1** — single-session lifecycle means partial write = visible crash to developer. Recommend deferring partial-write protocol to V2 alongside cross-session resume.

**S-3 temporal halt UX, concrete scenario added**:
> Given a pipeline run halts on rate-limit during `plan` dispatch, when the halt is written to log and presented to developer, then: (a) message names the failed stage, (b) names the failure class ("rate-limit — temporal"), (c) provides the exact re-trigger command, (d) decisions-log.md contains structured `halt` entry with `entry_type=stage-end`, `status=halt`, and rationale populated with API error reason.

**Withdrawals/strengthenings**:
- F-01 STRENGTHENED — SC-001 ≤3 cap is arithmetically violated by FR-008 BLOCKING-everywhere; needs revised SC-001 or explicit acknowledgment.
- F-02 STRENGTHENED to CRITICAL.
- F-03, F-04, F-05 MAINTAINED.
- F-06 WITHDRAWN conditionally pending plan-phase confirmation that review-skill amendment is tracked as prerequisite task.
- **F-07 NEW (MEDIUM)**: ADR-013 partial-write recovery protocol should be deferred to V2.


## Phase C: Synthesis

**Gate Recommendation: REVISE (small, inline)**. Spec is structurally sound; V1 scope justified. 6 inline-closeable gaps + 1 minority dissent rejected on construct-validity grounds.

**Majority Findings**:
- C-1 CRITICAL: BLOCKING semantics at non-code gates undefined (PS F-02 escalated + DA)
- C-2 HIGH: Decision-log integrity hand-waved — two writers, no locking/atomic-append/terminal-sentinel format (PS F-03 + DA)
- C-3 HIGH: FR-020 vs sentinel-files contradiction (.run-lock/.abort under git-tracked specs/, FR-020 forbids .gitignore mod)
- C-4 HIGH: SC-001 ≤3 cap arithmetically violated by FR-008 BLOCKING-everywhere
- C-5 MEDIUM: Stale-lock recovery undefined (no --break-lock or TTL)
- C-6 MEDIUM: Temporal halt UX absent from acceptance scenarios

**Minority Dissent (preserved)**: DA holds 65% confidence "ship LOG-005 stage-pair as V1." Rejected — PS's 85% counter on construct validity wins (stage-pair invalidates the V1 evidence test ADR-015 depends on). Tilt 70% toward PS. DA's grain ("won't get used → no evidence") closeable by SC-008 + 30-day usage floor, not by reframe.

**Decision Records to Create**:
1. ADR-016: Decision-log write protocol (atomic-append, terminal sentinel, two-writer ordering)
2. Amend ADR-014: non-code BLOCKING UX paragraph
3. Amend ADR-012: sentinel-files exception OR relocate to specs/[###]/.run/
4. LOG-009 (QUESTION): Stale-lock recovery policy
5. Amend ADR-015: SC-008 + 30-day usage floor
6. Tighten FR-027 (atomic sentinel/lock removal)

**11-item edit list**:
- [ ] Edit SC-001 to remove ≤3 cap or parameterize by gate count
- [ ] Add acceptance scenario for non-code BLOCKING UX (US-1)
- [ ] Add temporal-halt acceptance scenario to US-4
- [ ] Add SC-008 (feature-level criterion) + 30-day usage floor
- [ ] Resolve sentinel/.gitignore contradiction (move sentinels OR carve exception in FR-020)
- [ ] Add stale-lock recovery flag or TTL to FR-028
- [ ] Tighten FR-027 (atomic sentinel + lock removal on abort)
- [ ] Write ADR-016 (decision-log write protocol); amend ADR-013 to point to it
- [ ] Amend ADR-012 (sentinels) and ADR-014 (non-code BLOCKING UX) inline
- [ ] Defer ADR-013's partial-write recovery to V2 (note in ADR-013 + ADR-015)
- [ ] Open LOG-009 (stale-lock recovery policy) as plan-phase question

**Net judgment**: Prior REVISE round stuck. 10 blockers resolved or converted into FRs/ADRs. Remaining gaps are detail, not direction. Closeout pass, not structural redo.


---

## REVISE Application Log (2026-04-26)

11-item edit list executed with oracle sharpenings baked in:

- [x] Edit SC-001 to remove ≤3 cap (parameterized by gate count instead) — `specs/010-autonomous-workflow/spec.md` SC-001
- [x] Add acceptance scenario for non-code BLOCKING UX — US-1 scenario 4
- [x] Add temporal-halt acceptance scenario — US-4 scenario 3
- [x] Add SC-008 (feature-level criterion) + 30-day usage floor — SC-008 + ADR-015 amendment
- [x] Resolve sentinel/.gitignore contradiction → relocated sentinels to `specs/[###]/.run/`; declared `specs/*/.run/` in `.gitignore` once at template-setup time (oracle Q3 picked relocate)
- [x] Add stale-lock recovery flag/TTL → FR-028 references LOG-009 + interim `--break-lock` posture
- [x] Tighten FR-027 (atomic sentinel + lock removal on abort)
- [x] Write ADR-016 *Decision-log canonical/derivative model* (oracle Q2 reframe: subagent canonical, orchestrator derivative; locking-free)
- [x] Amend ADR-013 (declared subagent canonical writer per ADR-016; deferred partial-write protocol to V2)
- [x] Amend ADR-012 (declared `specs/[###]/.run/` placement; preserved runtime `.gitignore` prohibition)
- [x] Amend ADR-014 (added non-code BLOCKING UX semantics paragraph)
- [x] Amend ADR-015 (added SC-008 + 30-day usage floor; deferred ADR-013 partial-write to V2)
- [x] Open LOG-009 (stale-lock recovery policy) as plan-phase question

**Files modified**:
- `specs/010-autonomous-workflow/spec.md` — Decision Records table, US-1 scenario 4, US-4 scenario 3, FR-005, FR-027, FR-028, SC-001, SC-007, SC-008, Key Entities (Sentinel Files, Decision Log, Control-flow Sidecar), Open Questions for Plan Phase
- `.specify/memory/ADR_012_branch-scoped-sandbox.md` — `.run/` placement amendment
- `.specify/memory/ADR_013_subagent-writes-decision-log.md` — canonical-writer declaration; partial-write deferral
- `.specify/memory/ADR_014_blocking-by-default-code-gates.md` — non-code BLOCKING UX paragraph
- `.specify/memory/ADR_015_v1-scope-boundary.md` — SC-008 + partial-write deferral
- `.specify/memory/ADR_016_decision-log-canonical-derivative.md` — NEW
- `.specify/memory/LOG_009_stale-lock-recovery-policy.md` — NEW
- `.gitignore` — `specs/*/.run/` entry

**Oracle consultation findings applied**:
- Q1 (stage-pair vs pipeline): synthesis stands — pipeline V1 is correct construct validity, not sunk-cost.
- Q2 (two-writer durability): synthesis sharpened — ADR-016 written as canonical/derivative model rather than locking protocol; locking-free.
- Q3 (sentinel placement): synthesis decided — relocate to `specs/[###]/.run/` (consistent with PHI-006 placement principle for process-lifecycle artifacts); template-time gitignore declaration preserves FR-020.

**Next gate**: spec is ready for plan phase. Plan author must resolve LOG-006 (TDD strategy) and LOG-009 (stale-lock recovery policy) before task ordering is committed; both are explicitly listed in spec.md "Open Questions for Plan Phase".
