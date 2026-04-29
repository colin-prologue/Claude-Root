# Feature Specification: Autonomous Pipeline Orchestration

**Feature Branch**: `010-autonomous-workflow`
**Created**: 2026-04-25
**Status**: Draft
**Input**: User description: "Now that we have more support from our oracle, I want to consider how we can empower a session to go through more intermediate steps of the specify workflow independently. I want to consider how to orchestrate decision making, progressing through checkpoints, managing context properly, and logging independent decisions so we can review at the end of a full specify->review->clarify->plan->review->task->review->analyze->implement->codereview->audit"

## Decision Records

| # | Type | File | Title | Status |
|---|---|---|---|---|
| ADR-008 | Decision | ADR_008_speckit-run-trigger.md | `/speckit.run` as orchestrator trigger | Accepted (Q1 — 2026-04-25) |
| ADR-009 | Decision | ADR_009_subagent-per-stage-execution.md | Subagent-per-stage execution model | Accepted (Q2 — 2026-04-25) |
| ADR-010 | Decision | ADR_010_decision-log-threshold.md | Stage-boundary threshold for decision log | Accepted (Q3 — 2026-04-25); amended by ADR-013 |
| ADR-011 | Decision | ADR_011_failure-handling-three-class.md | Three-class failure handling | Accepted (Q4 — 2026-04-25); temporal auto-resume scoped V1 → halt + explicit retrigger per ADR-015 |
| ADR-012 | Decision | ADR_012_branch-scoped-sandbox.md | Branch-scoped sandbox for autonomous code actions | Accepted (Q5 — 2026-04-25); amended 2026-04-26 (`specs/[###]/.run/` placement for runtime artifacts) |
| ADR-013 | Decision | ADR_013_subagent-writes-decision-log.md | Subagent writes decision-log entry directly to disk | Proposed (spec-review revision — 2026-04-26); amended 2026-04-26 (refined by ADR-016, partial-write recovery deferred to V2) |
| ADR-014 | Decision | ADR_014_blocking-by-default-code-gates.md | BLOCKING-by-default at code-action gates in V1 | Proposed (spec-review revision — 2026-04-26); amended 2026-04-26 (non-code BLOCKING UX semantics) |
| ADR-015 | Decision | ADR_015_v1-scope-boundary.md | V1 scope boundary — trust first, defer learning loop and temporal auto-resume | Proposed (spec-review revision — 2026-04-26); amended 2026-04-26 (SC-008 + 30-day usage floor) |
| ADR-016 | Decision | ADR_016_decision-log-canonical-derivative.md | Decision-log canonical/derivative model | Proposed (second-spec-review revision — 2026-04-26) |
| ADR-017 | Decision | ADR_017_tdd-strategy-hybrid.md | Hybrid test strategy for non-deterministic dispatcher | Proposed (plan-phase resolution — 2026-04-26); closes LOG-006 |
| ADR-018 | Decision | ADR_018_stale-lock-recovery-break-lock.md | Stale-lock recovery — `--break-lock` only in V1 | Proposed (plan-phase resolution — 2026-04-26); closes LOG-009 |
| LOG-004 | Question | LOG_004_per-stage-context-overhead-breakdown.md | Granular per-stage context overhead breakdown | Open (Q2 follow-up — 2026-04-25); deferred to V2 per ADR-015 |
| LOG-005 | Challenge | LOG_005_stage-pair-runner-fallback.md | Stage-pair runner as V1.5 fallback | Open (spec-review — 2026-04-26) |
| LOG-006 | Question | LOG_006_tdd-strategy-non-deterministic-dispatcher.md | TDD strategy for non-deterministic LLM dispatcher | Resolved by ADR-017 — 2026-04-26 |
| LOG-007 | Question | LOG_007_codereview-model-class-diversity.md | Codereview model-class diversity for autonomous pipeline | Open (V1 dogfooding measurement — 2026-04-26); measurement protocol defined |
| LOG-008 | Challenge | LOG_008_decision-log-unbounded-growth.md | Decision log unbounded growth across runs | Open (deferred to V2 — 2026-04-26) |
| LOG-009 | Question | LOG_009_stale-lock-recovery-policy.md | Stale-lock recovery policy | Resolved by ADR-018 — 2026-04-26 |

## Goal Hierarchy

V1 of `/speckit.run` is calibrated for **trust-first, friction-second**. The clarification answers (Q3 audit-before-implement, Q4 halt-on-semantic-failure, Q5 sandbox) repeatedly chose the safer option. V1 honors that pattern:

1. **Build trust through legibility and observability** — decision-log entries written directly by subagents (ADR-013), BLOCKING checkpoints at every code-action gate (ADR-014), single-session lifecycle.
2. **Remove friction within trust constraints** — bundle multi-stage execution under one invocation, eliminate per-stage typing, but never trade away a human pause at a code-writing gate.

Features that expand the autonomy ceiling (OBSERVING mode, learning-loop checkpoint files, temporal auto-resume across developer-session boundaries) are deferred to V2 (ADR-015) and re-introduced with V1 evidence rather than speculation.

## Clarifications

### Session 2026-04-25

- Q: What form does the trigger mechanism take? → A: A new `/speckit.run` slash command — single entry point, takes target stages and checkpoint policy as arguments. Existing single-stage commands (`/speckit.specify`, `/speckit.plan`, etc.) remain unchanged and usable standalone. The execution context (main session vs. subagent) is a separate concern handled in Q2.
- Q: What execution context does each pipeline stage run in? → A: Every stage dispatches to a fresh subagent (Option B). The orchestrator runs in the main session as a thin coordinator that reads artifacts, decides routing, writes the decision log, and dispatches the next subagent. This matches the user's existing manual `/clear`-between-phases practice and prevents cross-phase decision-making pollution. Token overhead from per-stage cold starts is accepted as the cost of decision independence.
- Q: What threshold defines a "decision worth logging"? → A: Stage-boundary decisions only (Option B). The decision log records control transitions — start/skip/end of each stage, severity-based escalations, routing choices, abort triggers — plus the structured summary returned by each subagent. Per-stage internal reasoning is captured implicitly via the subagent's returned summary; it is not surfaced as separate log entries. This keeps the log readable at human speed and aligns with the subagent execution model.
- Q: How does the orchestrator handle subagent failures? → A: Hybrid of halt-on-semantic-failure with auto-resume on temporal failure (refinement of Options B + C). Three failure classes: (1) **Temporal** — rate-limit responses or context-window-refresh waits trigger pause-and-auto-resume, honoring any retry-after duration the API provides; long waits MUST survive developer session boundaries by leveraging the same on-disk state used for FR-007 resume. (2) **Semantic** — missing artifact, malformed subagent summary, contract violation: halt, write structured failure entry to decision log, require explicit developer re-trigger. (3) **Permission/exhaustion** — tool denial, subagent context exhausted, unrecoverable error: halt, log, require explicit re-trigger. No automatic retry on indeterminate errors.
- Q: What constraints apply to autonomous code-action subagents (implement, codereview, audit)? → A: Branch-scoped sandbox (Option C). Subagents MAY write, edit, delete files inside `specs/[###]/` and the project source tree, run tests, and commit to the feature branch. Subagents MUST NOT push to remote, modify `main`, perform any force operation, modify `.gitignore`, modify CI/CD files, or modify hooks/settings outside the feature scope. Excursions outside the allowlist trigger a permission failure halt per FR-019.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Single-Trigger Pipeline Execution (Priority: P1)

A developer starts a new feature and wants the session to handle the full speckit pipeline — from specifying requirements through planning and tasking — without requiring a prompt at every intermediate stage. They provide an initial description and a target pipeline depth, and the session works through each stage autonomously, pausing only at configured checkpoints.

**Why this priority**: The primary friction point in the current workflow is that each stage requires an explicit user command, even when the outputs of prior stages are sufficient to proceed. Removing this friction unlocks the core value of the feature.

**Independent Test**: Given a developer who invokes the pipeline orchestrator with a feature description and a target of `specify→review→clarify→plan→review→tasks`, the session completes all six stages, produces the corresponding artifacts in `specs/[###-feature-name]/`, and presents a summary of what was completed — without requiring the developer to issue six separate commands.

**Acceptance Scenarios**:

1. **Given** a feature description and a configured target pipeline of `specify→review→plan→tasks`, **When** the developer triggers the orchestrator, **Then** the session produces `spec.md`, a review summary, `plan.md`, and `tasks.md` in the correct spec directory, pausing only at the pre-configured checkpoint before tasks are written.
2. **Given** a review panel that surfaces blocking findings, **When** the orchestrator reaches the review stage, **Then** the session halts, surfaces the blocking findings clearly, and waits for developer input before proceeding — rather than silently continuing.
3. **Given** a target pipeline that includes `clarify`, **When** the spec contains unresolved ambiguities, **Then** the session runs clarification and resolves them before proceeding to `plan`, documenting each resolution in the decision log.
4. **Given** a pipeline run paused at a non-code BLOCKING gate (`pre-plan` or `pre-tasks`), **When** the orchestrator presents the checkpoint, **Then** the developer sees: (a) the previous stage's primary artifact path (`spec.md`, `plan.md`), (b) a one-line outcome summary drawn from the subagent's decision-log `status` field, and (c) the next stage's name. The developer may edit the artifact in their editor before issuing `proceed`; the orchestrator dispatches the next stage against whatever is on disk at proceed-time. Issuing `abort` writes an `abort` entry to the decision log, atomically removes the run-lock and abort sentinel (FR-027), and retains all artifacts written by completed stages on disk (per ADR-014 amendment).

---

### User Story 2 - Decision Log Review (Priority: P2)

At the end of an autonomous pipeline run, a developer wants to see a consolidated, chronological record of every significant decision the session made autonomously — what it decided, why, and what alternatives it considered — so they can audit the run before implementation begins.

**Why this priority**: Autonomous decisions made without visibility create trust problems. The log is the audit trail that lets developers ratify or override what happened before code is written.

**Independent Test**: Given a completed pipeline run through `specify→review→clarify→plan→review→tasks`, when the developer requests the decision log, a structured document exists at `specs/[###-feature-name]/decisions-log.md` listing every autonomous decision with its rationale and any alternatives considered.

**Acceptance Scenarios**:

1. **Given** a pipeline run where the orchestrator autonomously chose to skip `clarify` because no ambiguities were found, **When** the developer reviews the decision log, **Then** the log explicitly records the decision to skip, the criterion used to make that call, and a timestamp.
2. **Given** a pipeline run where review findings caused the orchestrator to route back to `specify` for a revision, **When** the developer reviews the decision log, **Then** the log records the finding that triggered the revision, what was changed, and what the re-review found.
3. **Given** a decision log, **When** the developer opens it, **Then** entries are ordered chronologically, each entry identifies the pipeline stage, the decision made, the rationale, and any alternatives that were considered and rejected.

---

### User Story 3 - Checkpoint Files for Learning (Priority: V2 — DEFERRED)

> **DEFERRED to V2** per ADR-015. V1 ships with BLOCKING checkpoints only (ADR-014); checkpoint-decision files and the OBSERVING/learning loop are re-introduced in V2 alongside this user story, informed by V1 dogfooding evidence. Original story preserved below for V2 reference.

A developer running a fully autonomous pipeline wants every significant decision gate to produce a structured file capturing what was decided and why — not to block the pipeline, but to review afterward and identify where the session's judgment was wrong. Over time, these files become the evidence base for adding targeted guardrails that improve autonomy without sacrificing correctness.

---

### User Story 4 - Pipeline Resume After Interruption (Priority: P2)

A developer whose pipeline session was interrupted — by a manual abort, a semantic failure, or a temporal failure (rate limit) — wants to resume from the last completed stage without re-running earlier stages or losing artifacts already produced. **V1 scope: explicit developer-triggered resume only.** Cross-session auto-resume on temporal failures is V2 (ADR-015).

**Why this priority**: Long pipelines risk interruption. Without resume capability, any interruption forces a full restart, which undermines the value of automation. Promoted from P3 to P2 — without resume, developers self-limit to short pipelines and the core value never gets exercised.

**Independent Test**: Given a pipeline run that completed `specify→review→clarify` before being interrupted, when the developer restarts and requests resume, the orchestrator picks up at `plan` without re-running the first three stages, and the existing `spec.md` and decision log are preserved.

**Acceptance Scenarios**:

1. **Given** a partially completed pipeline with `spec.md` and `plan.md` already written and complete (per FR-026 completeness predicate), **When** the developer requests resume, **Then** the orchestrator detects the existing complete artifacts, identifies the next uncompleted stage, and continues from there.
2. **Given** a pipeline interrupted mid-stage (e.g., review panel launched but not completed), **When** the developer requests resume, **Then** the orchestrator re-runs the incomplete stage from the beginning rather than attempting to reconstruct partial output.
3. **Given** a pipeline run halts on a temporal failure (rate-limit) during `plan` dispatch, **When** the halt is written to the decision log and presented to the developer, **Then**: (a) the message names the failed stage, (b) names the failure class as `rate-limit — temporal`, (c) provides the exact re-trigger command for the developer to copy-paste, and (d) the decision-log entry has `entry_type=stage-end`, `status=halt`, and `rationale` populated with the API error reason. Cross-session auto-resume on temporal failures is V2 (ADR-015); V1 always halts and waits for explicit retrigger.

---

### Edge Cases (resolved as FRs)

The following control-flow questions surfaced during /speckit.review and are answered as FRs below — see FR-021 through FR-025. Edge Cases section retained as a pointer to the relevant FRs:

- Multiple-blocker collection vs halt-on-first → FR-021
- Simultaneous-clarification serialization → FR-022
- `spec.md`-already-exists semantics on invocation → FR-023
- Empty-stage-output logging → FR-024
- All-WARNING (no BLOCKER) escalation behavior → FR-025

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST allow a developer to trigger a multi-stage pipeline with a single invocation, specifying any contiguous sequence from the full pipeline.
- **FR-002**: The system MUST progress through each configured pipeline stage without requiring a new user prompt, unless a checkpoint or blocker is encountered.
- **FR-003**: The system MUST pause at every configured checkpoint and present a summary of completed stages before requesting developer approval to continue.
- **FR-004**: The system MUST halt and escalate to the developer when a review-stage subagent emits a halt directive in its decision-log entry. The subagent self-classifies findings (no fixed BLOCKER/WARNING/INFO taxonomy required at the orchestrator level) and is responsible for setting the halt directive when its findings warrant developer attention. The orchestrator routes on the directive, not on its own severity parsing.
- **FR-005**: The system MUST produce a `decisions-log.md` file in the feature's spec directory. Per ADR-013 (refined by ADR-016), the **subagent is the canonical writer** of `decisions-log.md`: each dispatched subagent appends its own per-stage record (per FR-006 schema) directly to disk before exiting, and that record is the irreplaceable audit trail. The **orchestrator does not append directly to `decisions-log.md` during stage execution**; instead, it records its control-flow events (stage-start, stage-skip, route, abort) to a regenerable sidecar at `specs/[###]/.run/control-flow.log`. On clean termination of the run, the orchestrator MAY append a single coalesced control-flow summary to `decisions-log.md` consolidating its sidecar events. This protocol is locking-free: only one writer holds `decisions-log.md` at any moment.
- **FR-006**: Each decision-log entry MUST conform to a defined schema. Required fields: `stage` (canonical pipeline stage name), `entry_type` (one of: stage-start, stage-end, stage-skip, escalate, route, abort, subagent-record), `timestamp` (ISO-8601), `author` (`orchestrator` or `subagent:[stage]`), `status` (success | halt | error), `rationale` (free-text). Subagent-record entries additionally require: `artifacts_written` (list of paths), `decisions_made` (list of structured items each with rationale and alternatives), `halt_directive` (boolean + reason if true). The schema is the contract subagents must conform to (S-6 / ADR-013).
- **FR-007**: The system MUST detect existing complete stage artifacts (per FR-026 completeness predicate) and support resuming from the last incomplete stage when the developer explicitly requests resume.
- **FR-008**: The system MUST support a configurable checkpoint policy — a named list of gates where the pipeline always pauses for human review. In V1 all code-action gates (`pre-implement`, `pre-codereview`, `pre-audit`) are forced BLOCKING regardless of policy (ADR-014); the policy controls only non-code gates.
- **FR-009**: The system MUST support a configurable target pipeline — the developer specifies *which subset* of stages to run as a contiguous subsequence of the canonical pipeline order (M-1: selection, not sequence). Reordering stages is not supported; the orchestrator rejects target arguments that imply non-canonical order.
- **FR-010**: The system MUST produce all standard speckit artifacts (`spec.md`, `plan.md`, `tasks.md`, etc.) in the correct locations when those stages are included in the target pipeline.
- **FR-011**: The system MUST log autonomous routing decisions (e.g., "skipped clarify — no ambiguities detected") via orchestrator-authored entries with the same schema as content decisions (FR-006).
- **FR-012**: The system MUST support full-pipeline autonomous execution including `implement`, `codereview`, and `audit` stages, subject to the V1 BLOCKING-by-default constraint at code gates (ADR-014). The session writes code and makes commits, but pauses for explicit developer `proceed` or `abort` at every code-action gate before continuing.
- **FR-013**: *DEFERRED to V2 (ADR-014, ADR-015). V1 ships single-mode (BLOCKING).*
- **FR-014**: *DEFERRED to V2 (ADR-014, ADR-015). V1 ships single-mode (BLOCKING).*
- **FR-015**: *DEFERRED to V2 (ADR-015). Checkpoint-decision files for the learning loop are V2.*
- **FR-016**: The system MUST be triggered via a single new `/speckit.run` slash command. Existing single-stage speckit commands (`/speckit.specify`, `/speckit.plan`, etc.) MUST continue to work standalone and remain unchanged.
- **FR-017**: The system MUST execute every pipeline stage in a fresh subagent dispatched from the main-session orchestrator. The orchestrator MUST NOT carry stage-internal context across stages — it reads decision-log entries written by each subagent (FR-005, ADR-013) and the artifacts each subagent writes; it does not trust returned strings as the source of truth for routing decisions.
- **FR-018**: *DEFERRED to V2 (ADR-015). Token-usage telemetry in the decision log is V2; LOG-004 follow-up moves to V2.*
- **FR-019**: The system MUST classify subagent failures into three classes and handle each distinctly. **Temporal failures** (rate-limit, context-refresh waits): in V1, halt and require explicit developer retrigger; cross-session auto-resume is V2 (ADR-015). **Semantic failures** (missing artifact, malformed summary or log entry, contract violation, schema violation per FR-006): halt, write structured failure entry to decision log, require explicit developer re-trigger. **Permission and exhaustion failures** (tool denial, subagent context exhausted, unrecoverable error, sandbox violation per FR-020): halt, log, require explicit re-trigger. Failures that cannot be classified into one of the three buckets MUST halt as a semantic failure (default fallthrough). No automatic retry on indeterminate errors.
- **FR-020**: Code-action subagents MUST operate inside a branch-scoped sandbox. ALLOWED: writing/editing/deleting files inside `specs/[###]/` and the project source tree, running tests, and committing to the feature branch. DISALLOWED: pushing to remote, modifying `main` directly, force operations of any kind, modifying `.gitignore`, modifying CI/CD configuration, modifying hooks or settings outside the feature scope, creating or committing files matching `.env*` or other secrets-bearing patterns. Any disallowed action MUST halt the pipeline as a permission failure per FR-019.
- **FR-021**: When a review stage produces multiple findings, the orchestrator MUST collect ALL findings before deciding whether to halt — not halt on first match. The review subagent emits a single halt directive per stage based on the aggregate finding set, not per-finding.
- **FR-022**: When two adjacent stages both require clarification input, the orchestrator MUST serialize them — present the first stage's clarifications, await response, then present the second stage's clarifications. Parallel clarification prompts are forbidden.
- **FR-023**: When `/speckit.run` is invoked on a feature directory where `spec.md` already exists: presence of `decisions-log.md` written by a prior orchestrator run ⇒ treat as resume (FR-007); absence of `decisions-log.md` ⇒ require an explicit `--force` flag to overwrite, otherwise halt with a clear message. **Resume scan MUST filter out the three orchestrator-authored canonical-exception entry types (`verdict-mismatch`, `verdict-omitted`, `pipeline-incomplete` per ADR-016) when locating the latest stage record**, because those entries are violation/bookkeeping records and would otherwise become an invalid resume anchor (a `pipeline-incomplete` at the tail of a prior crashed run would be read as the latest stage). Resume anchors are subagent-authored stage records (`stage-start`/`stage-end`/`halt` written by a subagent during stage execution) OR orchestrator-authored control-flow records (`stage-start`/`stage-skip`/`route`/`abort`/`break-lock`/`halt` written by the orchestrator); the unified set MUST match `helper-contracts.md` §`run-decide-next.sh` Resume-scan filter — `entry_type ∈ {stage-start, stage-end, halt, abort, stage-skip, route, break-lock}`. Never anchor on canonical-exception records (`verdict-mismatch`/`verdict-omitted`/`pipeline-incomplete`).
- **FR-024**: When a pipeline stage produces empty output (e.g., `clarify` finds no ambiguities), the orchestrator MUST log it as an explicit `stage-skip` entry per FR-006 with the criterion that produced the empty output. Silent skips are forbidden.
- **FR-025**: When a review-stage subagent does not emit a halt directive (i.e., its findings are below its halt threshold), the pipeline continues autonomously to the next stage. The subagent's findings are recorded in its decision-log entry regardless of whether they triggered a halt.
- **FR-026**: The system MUST define a completeness predicate per stage artifact and use it (not file existence alone) when detecting resumable state per FR-007. V1 predicates: `spec.md` complete = all mandatory sections non-empty AND zero `[NEEDS CLARIFICATION]` markers; `plan.md` complete = all mandatory sections non-empty; `tasks.md` complete = at least one task block present; review summaries complete = decision-log entry with `entry_type=stage-end` and matching stage exists. A file that exists but fails the predicate is treated as incomplete and the stage re-runs from the beginning.
- **FR-027**: The system MUST provide an abort mechanism. The orchestrator checks for a sentinel file `specs/[###]/.run/abort` between every stage dispatch; presence halts the pipeline immediately, writes an `abort` entry to the decision log (subagent writes the per-stage `abort` record if a subagent was active; orchestrator coalesces the abort event into its sidecar otherwise), and atomically removes the sentinel **and** the run-lock (FR-028) in a single operation so a partial cleanup cannot leave a lock without a matching live process. The mechanism is documented in the user-facing `/speckit.run` command help.
- **FR-028**: Concurrent invocation of `/speckit.run` against the same feature directory is unsupported in V1. The orchestrator writes a lock file `specs/[###]/.run/run-lock` containing its session identifier and a creation timestamp at the start of each dispatch; presence of a lock from a different session halts the new invocation as a permission failure per FR-019. The lock is removed at clean termination (completion, abort, or developer-acknowledged halt). **Stale-lock recovery** (lock left orphaned by a crashed orchestrator session) is an open plan-phase decision tracked in LOG-009; until LOG-009 resolves, V1 surfaces the orphaned lock contents to the developer and refuses to proceed without an explicit `/speckit.run --break-lock` invocation. The runtime artifacts directory `specs/[###]/.run/` is declared in the template `.gitignore` once at template-setup time (per ADR-012 amendment); the orchestrator MUST NOT modify `.gitignore` at runtime (FR-020).

### Key Entities

- **Pipeline Run**: A named execution of a configured contiguous subsequence of speckit stages for a specific feature. Tracks current stage, completed stages, lock state, and a reference to the decision log.
- **Pipeline Stage**: A named, ordered unit of work (`specify`, `review`, `clarify`, `plan`, `tasks`, `analyze`, `implement`, `codereview`, `audit`). Each stage executes in a fresh subagent dispatched by the orchestrator. Inputs (prior artifacts and prior decision-log entries) are read from disk by the subagent at startup; outputs are a new artifact written to disk plus a decision-log entry the subagent writes directly (FR-005, ADR-013).
- **Checkpoint (V1)**: A gate between stages where the pipeline always pauses for explicit developer approval. All code-action gates (`pre-implement`, `pre-codereview`, `pre-audit`) are BLOCKING (ADR-014); non-code gates (`pre-plan`, `pre-tasks`) are also BLOCKING in V1 because V1 has no OBSERVING mode. OBSERVING mode and checkpoint-decision files return in V2.
- **Decision Log**: A structured artifact (`decisions-log.md`) appended to during pipeline execution. Per ADR-016, the **subagent is canonical writer** during stage execution — only one writer holds the file at a time. Each subagent appends its own per-stage record (FR-006 schema) before exiting. The orchestrator records its control-flow events (stage-start/stage-skip/route/abort) to a regenerable sidecar at `specs/[###]/.run/control-flow.log` during the run, and at clean termination MAY append a single coalesced summary to `decisions-log.md`. Ordered chronologically; append-only within a run; locking-free.

  **Canonical-log read mode** (Re-Review #2 RC-1): `decisions-log.md` is read in two distinct modes by different consumers, and consumers MUST declare which mode they are in. **Event-tape mode**: full-file scan from top — the audit substrate; used by reviewers, `check-adr-crossrefs.sh`, and any human reading the durable history. Every entry (including the three orchestrator-authored canonical-exception types `verdict-mismatch`/`verdict-omitted`/`pipeline-incomplete`) is in scope. **Status-surface mode**: filtered scan for the latest stage record — used by `run-decide-next.sh` for routing-from-resume (FR-023), by FR-026 completeness predicates, and by any orchestrator code that reads "the current state of the run." Status-surface mode MUST skip the three canonical-exception types (which are violation/bookkeeping records, not state records). The single artifact serves both modes; the filter rule (per FR-023 / helper-contracts.md run-decide-next.sh §Resume-scan filter) is what disambiguates them. The `pipeline-incomplete` + coalesced-summary tail produced by an interrupted-then-finalized run is therefore a non-contradiction in event-tape mode (both entries are durable evidence) and unambiguous in status-surface mode (only the coalesced summary is the state record). V2 may collapse the two modes via a 3-section file restructure (header / body / footer) tracked as a candidate ADR; V1 ships the dual-mode read with the filter as the disambiguator.
- **Decision-Log Entry**: A structured record per FR-006 schema. Required fields vary by `entry_type`. Subagent-record entries are the per-stage audit trail and the source of truth the orchestrator reads to make routing decisions (ADR-013).
- **Autonomous Decision**: Any significant choice the session makes without explicit developer input — stage routing, ambiguity resolution, halt-directive policy interpretation, artifact conflict resolution.
- **Sentinel Files**: `specs/[###]/.run/abort` (developer-set, triggers FR-027 abort) and `specs/[###]/.run/run-lock` (orchestrator-set, prevents FR-028 concurrent invocations). The `.run/` subdirectory is gitignored at template-setup time (ADR-012) so runtime processes never need to modify `.gitignore`.
- **Control-flow Sidecar**: `specs/[###]/.run/control-flow.log` (orchestrator-set, regenerable cache of stage-start, stage-skip, route, abort events per ADR-016). Read alongside `decisions-log.md` for a complete picture of the run; rebuildable from artifact state and the canonical `decisions-log.md` if corrupted.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can complete a `specify→review→clarify→plan→review→tasks` pipeline run for a well-defined feature (definition: see Assumptions) with **zero unscheduled interventions** — every developer interaction is either (a) a configured BLOCKING checkpoint acknowledgement or (b) a halt directly raised by a subagent's halt directive, schema violation, or postcheck failure. The system MUST NOT prompt the developer for clarification, re-confirmation, or progress acknowledgement outside those two channels; spurious halts from validator noise (e.g., transient lock contention not caused by a concurrent run, helper crashes the orchestrator could retry deterministically) are SC-001 violations. (V1 BLOCKING-everywhere posture per ADR-014 means scheduled intervention count tracks the gate count of the configured target pipeline; the original ≤3 cap was arithmetically incompatible with FR-008's BLOCKING-everywhere policy.)
- **SC-002**: Every stage transition (start, end, skip, escalate, route, abort) appears in `decisions-log.md` — verified by comparing the orchestrator's emitted transition events against log entries with `author=orchestrator`; zero discrepancies. (Within-stage subagent decisions are covered by FR-006's subagent-record schema, not by this success criterion.)
- **SC-003**: Resuming an interrupted pipeline never re-runs stages whose artifacts already exist and pass the FR-026 completeness predicate, confirmed by artifact timestamps remaining unchanged after resume.
- **SC-004**: A developer reviewing the decision log can reconstruct the full reasoning path of the pipeline run — what was decided, why, and what triggered each stage transition. Verified by retrospective walkthrough of a completed run's log.
- **SC-005**: *DEFERRED to V2 (ADR-015) alongside US-3 and the checkpoint-decision-file infrastructure that this criterion depends on.*
- **SC-006**: When a code-action gate is reached (`pre-implement`, `pre-codereview`, `pre-audit`), the orchestrator pauses and waits for explicit `proceed` or `abort` 100% of the time in V1 — verified by zero subagent dispatches at code-action stages without a preceding developer-approval log entry.
- **SC-007**: When the developer creates `specs/[###]/.run/abort`, the orchestrator halts before the next stage dispatch within one stage-boundary check — verified by abort-log entry timestamp ≤ next-stage-dispatch timestamp in test runs.
- **SC-008** *(feature-level, V1-ship-or-retire)*: After ≥5 full pipeline runs in V1 over a usage period of at least 30 days, the developer reports: **(a)** at least one run where autonomous progression saved verifiable effort vs. manual stage-by-stage execution (completed without requiring more `proceed` interventions than a stage-pair runner would have demanded), AND **(b)** zero runs where autonomous progression produced an artifact the developer would have caught and corrected by manual review. (a) never met across ≥5 runs over 30 days ⇒ retire `/speckit.run` (LOG-005 stage-pair runner becomes the V1.5 path). (b) violated even once ⇒ re-evaluate the BLOCKING-everywhere posture and trust-first hierarchy before any V2 expansion. The 30-day floor ensures the runs reflect genuine feature-development cadence, not benchmark theatre. (Defined in ADR-015 amendment.)

## Assumptions

- The pipeline stages are the existing speckit skills in their current form; this feature orchestrates them rather than modifying them. Review subagents are amended (or wrapped) to emit a halt directive in their decision-log entry per FR-004 and FR-006 — that is the only stage-skill change this feature requires.
- `decisions-log.md` is a new artifact type alongside `spec.md`, `plan.md`, and `tasks.md` — written jointly by orchestrator (control entries) and subagents (per-stage records) per ADR-013.
- A "well-defined feature" for SC-001 means one where the initial description is sufficient for `specify` to produce a complete spec (passes FR-026 predicate) with no unresolved `[NEEDS CLARIFICATION]` markers.
- The pipeline configuration (target stages subset, checkpoint policy) is provided at invocation time — not stored as a persistent project setting.

## Open Questions for Plan Phase

- **TDD strategy** (LOG-006): ✅ Resolved by ADR-017 — Hybrid two-tier: unit (TDD-strict, pre-commit) + smoke (real subagents, pre-merge, cost-capped).
- **Stale-lock recovery policy** (LOG-009): ✅ Resolved by ADR-018 — `--break-lock` only in V1; developer-in-the-loop recovery.
- **Severity-taxonomy retrofit** (S-2 alternative): FR-004 currently delegates classification to the subagent's halt directive (no fixed BLOCKER/WARNING/INFO contract). If plan author determines a structured severity manifest is needed instead, the prerequisite is amending `/speckit.review`'s output format — that is a separate spec, not part of 010.
- **Codereview model-class diversity** (LOG-007): Empirical question for V1 dogfooding — measurement protocol defined in LOG-007 (capture template + interpretation thresholds). Resolution lands after ≥5 runs over 30 days; affects V2 OBSERVING re-introduction.
- **Sidecar format** (ADR-016 follow-up): ✅ Resolved by ADR-020 — JSONL chosen over structured markdown. Per-event line-grep + jq filter usability and append-write atomicity outweigh the markdown-idiom consistency argument; canonical `decisions-log.md` remains markdown, sidecar is JSONL.
- **Smoke-tier fixture selection and cost cap** (ADR-017 follow-up): Plan author picks 1–2 fixture features that exercise the most contract surface per dollar, and sets per-run + per-merge token budgets.
