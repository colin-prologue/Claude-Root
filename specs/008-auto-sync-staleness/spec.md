# Feature Specification: Auto-Sync Staleness Detection and Memory Opt-In Gate

**Feature Branch**: `008-auto-sync-staleness`
**Created**: 2026-04-17
**Status**: Draft
**Input**: 008-auto-sync-staleness: Automatic index staleness detection in _ensure_init (timestamp-based re-sync trigger when last_sync_ts is > 1hr old, configurable via MEMORY_STALENESS_THRESHOLD env var) plus a constitution opt-in gate (memory_enabled field in constitution.md that skills check before calling memory tools, making the server optional for installs without it). From LOG-049 recommended scope: Option A (simpler timestamp variant) + Option C. Option B (PostToolUse hook) is deferred.

## Decision Records

| # | Type | File | Title | Status |
|---|---|---|---|---|
| LOG-049 | Question | LOG_049_speckit-memory-coupling.md | Speckit Skills Implicitly Require Memory Server | Open — drives this feature |
| ADR-050 | Decision | ADR_050_timestamp-staleness-detection.md | Timestamp-Based Staleness Detection via `_check_staleness()` in `memory_recall` | Accepted |
| ADR-051 | Decision | ADR_051_constitution-memory-gate.md | Constitution Front-Matter as Memory Opt-In Gate | Accepted |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Index Stays Current Without Manual Intervention (Priority: P1)

A developer finishes a speckit feature, writes several new ADRs and LOGs, and then immediately runs `/speckit.plan` on the next feature. Without this feature, the memory recall step surfaces only the ADRs that existed before the previous sync — the new records are invisible. After this feature, the server detects that the index is older than the configured threshold and automatically re-syncs before returning results, so the new records are retrievable.

**Why this priority**: The primary motivation for this feature is eliminating silent knowledge drift. If skills recall stale context, review findings and plan decisions silently miss recent decisions. The staleness check fixes the core problem; the gate is a configuration concern layered on top.

**Independent Test**: Given a memory server running with a populated index, and given that new files have been added to the spec/ADR directories since the last sync, when `memory_recall` is called after the staleness threshold has elapsed, the newly added files appear in recall results — without any manual call to `memory_sync()` in between.

**Acceptance Scenarios**:

1. **Given** the index was last synced more than the configured threshold ago and new ADR files exist on disk, **When** any `memory_recall` call is made, **Then** the server re-syncs incrementally before returning results and the new ADRs are present in subsequent recall responses.
2. **Given** the index was last synced within the threshold window, **When** `memory_recall` is called, **Then** no re-sync is triggered and recall returns promptly with the existing index.
3. **Given** the manifest has no recorded sync timestamp (fresh install or pre-008 manifest), **When** `memory_recall` is called, **Then** the server treats the index as stale and re-syncs before returning results.
4. **Given** the staleness threshold is set to 0 (disabled), **When** `memory_recall` is called regardless of index age, **Then** no staleness check is performed and no automatic re-sync is triggered.
5. **Given** the index was last synced more than the threshold ago but no new files exist, **When** re-sync runs, **Then** the manifest's sync timestamp is updated, no chunks are added or deleted, and subsequent calls within the window skip re-sync.

---

### User Story 2 - Memory Server Is Optional for Installs Without It (Priority: P2)

A developer clones the speckit template into a new project that does not use the memory server. Today, speckit skills silently attempt `memory_recall` and `memory_store` on every run; whether this causes an error depends on whether the server happens to be registered. After this feature, the developer can set `memory_enabled: false` in the constitution and skills skip all memory calls entirely — no errors, no warnings, no hidden dependency.

**Why this priority**: Fixing the implicit coupling between skills and the memory server makes the template usable without the server. This is a configuration concern, not a correctness problem — the skills continue to work whether or not the gate is set. The staleness fix (P1) is strictly more valuable than the opt-in gate.

**Independent Test**: Given a project with `memory_enabled: false` in the constitution, when any speckit skill (`/speckit.plan`, `/speckit.review`, `/speckit.audit`) runs its recall-before and store-after steps, no `memory_recall` or `memory_store` call is issued — even if the memory server is registered and running — and the skill completes without errors.

**Acceptance Scenarios**:

1. **Given** `memory_enabled: false` in the constitution and the memory server is running, **When** `/speckit.plan` executes, **Then** no `memory_recall` or `memory_store` call is made and the skill completes normally.
2. **Given** `memory_enabled: true` in the constitution, **When** any skill runs, **Then** behavior is identical to current behavior — memory calls are made according to memory-convention.md.
3. **Given** the constitution has no `memory_enabled` field (pre-008 constitutions), **When** any skill runs, **Then** behavior defaults to `memory_enabled: true` — fully backward compatible.
4. **Given** `memory_enabled: false`, **When** the developer manually calls `memory_recall` or `memory_store` directly via the MCP tool (not through a skill), **Then** the calls proceed normally — the gate is a skill-layer convention, not a server enforcement.

---

### Edge Cases

- What if the staleness threshold env var is set to a non-integer or negative value? Treat as disabled (same as 0) — no staleness check, no error surfaced to callers.
- What if re-sync triggered by staleness detection fails mid-run? The timestamp is only updated on successful sync completion — a failed sync leaves the stale flag active so the next call retries.
- What if `memory_enabled` is present in constitution but set to an unrecognized value (e.g., `"yes"`)? Treat as `true` (permissive default) — do not error, do not silently disable.
- What if the constitution file is missing or unparseable? Skills fall back to the existing best-effort behavior — skip memory calls silently and continue (consistent with memory-convention.md).
- What if a staleness-triggered re-sync takes longer than expected? The sync runs synchronously on the recall path in the first implementation (background deferral is explicitly deferred per LOG-049); slow Ollama will slow the first post-staleness recall. This is documented as a known tradeoff.

## Requirements *(mandatory)*

### Functional Requirements

**Staleness Detection (Option A)**

- **FR-001**: The memory index manifest MUST record the Unix timestamp of the most recent successful sync completion as a `last_sync_ts` field.
- **FR-002**: On every `memory_recall` call after initial sync, the server MUST compare the current time against `last_sync_ts`. If the elapsed time exceeds the staleness threshold, the server MUST trigger an incremental re-sync before returning results. **Exception**: when `summary_only=True`, the staleness flag is reset (priming re-sync for the next non-summary call) but the sync itself is deferred — running sync inline would require Ollama embedding, violating the Ollama-free guarantee of the summary_only path (ADR-037, LOG-053).
- **FR-003**: The staleness threshold MUST default to 3600 seconds (1 hour) and MUST be configurable via the `MEMORY_STALENESS_THRESHOLD` environment variable.
- **FR-004**: A threshold value of 0 MUST disable staleness checking entirely — no timestamp comparison is made and no automatic re-sync is triggered.
- **FR-005**: When `last_sync_ts` is absent from the manifest (pre-008 manifest or first-ever sync), the server MUST treat the index as stale and trigger a re-sync.
- **FR-006**: `last_sync_ts` MUST be written to the manifest only on successful sync completion, not on partial or failed syncs.
- **FR-007**: The staleness check adds no new network calls or file I/O beyond reading the manifest (which is already loaded during `_ensure_init`).

**Constitution Opt-In Gate (Option C)**

- **FR-008**: The constitution template MUST include an optional `memory_enabled` boolean field in its front-matter. When set to `false`, speckit skills MUST skip all `memory_recall` and `memory_store` calls.
- **FR-009**: When `memory_enabled` is absent from the constitution, skills MUST default to `true` — behavior is identical to current behavior.
- **FR-010**: The gate applies only at the skill layer (memory-convention.md adherence). The memory server itself is unaffected — direct MCP tool calls always pass through regardless of constitution settings.
- **FR-011**: Skills that check the gate MUST treat an unparseable or absent constitution as `memory_enabled: true` — no errors surfaced to the caller.

### Key Entities

- **Manifest**: The index metadata file. Gains one new field: `last_sync_ts` (Unix timestamp, float). Written on successful sync; absent on pre-008 manifests (treated as stale).
- **Staleness threshold**: The elapsed-time limit in seconds after which the index is considered stale. Defaults to 3600; overridable via `MEMORY_STALENESS_THRESHOLD`; value 0 disables.
- **Memory gate**: The `memory_enabled` field in constitution front-matter. A skill-layer convention flag — when false, skills bypass all memory calls without server interaction.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After creating new ADRs or LOGs, skills surface those records in recall results within one staleness window (default: 1 hour) without any manual sync step — 100% of new files indexed automatically in the window.
- **SC-002**: The staleness check adds no measurable latency to recall calls when the index is fresh (within the threshold window) — the overhead is a single integer comparison against a value already in memory.
- **SC-003**: A project with `memory_enabled: false` runs all speckit skills end-to-end with zero memory-related errors or warnings — the memory server dependency is fully optional.
- **SC-004**: Pre-008 projects (no `memory_enabled` field, no `last_sync_ts` in manifest) continue to work without modification — zero breaking changes to existing installations.

## Assumptions

- The existing `_ensure_init` sync mechanism (ADR-011) is the correct hook point for staleness detection. No new trigger point is introduced.
- Sync is synchronous on the first post-staleness recall in this implementation. Background/async sync is explicitly deferred (noted in LOG-049 as "adds complexity — defer to implementation").
- The constitution front-matter is YAML. Skills already read the constitution; reading a front-matter field is a minor extension of existing behavior.
- `memory-convention.md` already contains the best-effort skip guidance (added 2026-04-17 as part of LOG-049 immediate mitigation) — the gate formalizes this into an explicit, configuration-driven skip rather than an error-handling fallback.
- ADR-011 (self-init sync trigger) must be amended to document the new `last_sync_ts` write condition and staleness re-trigger logic. This is noted as a cross-reference requirement, not a blocking dependency.
