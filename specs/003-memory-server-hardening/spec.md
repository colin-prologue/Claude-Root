# Feature Specification: Memory Server Hardening

**Feature Branch**: `003-memory-server-hardening`
**Created**: 2026-04-09
**Status**: Draft
**Input**: User description: "Memory server hardening: add token budget control to memory_recall (max_chars parameter to cap total output size, token_estimate field in the response envelope), progressive result degradation with a summary_only mode returning {source_file, section, score} without full chunk content for two-pass retrieval, and read-only protection in memory_store that rejects writes where source_file matches an existing on-disk path — real ADRs and LOGs are managed by memory_sync only, not by agent tool calls."

## Decision Records

| # | Type | File | Title | Status |
|---|---|---|---|---|
| LOG-018 | Question | [LOG_018_index-cleanup-agent.md](../../.specify/memory/LOG_018_index-cleanup-agent.md) | Index cleanup agent deferred to feature 004 | Deferred |
| ADR-019 | Decision | [ADR_019_whitelist-write-guard.md](../../.specify/memory/ADR_019_whitelist-write-guard.md) | Whitelist write guard (`source_file="synthetic"` only) | Pending |
| LOG-020 | Challenge | [LOG_020_filter-source-file-gap.md](../../.specify/memory/LOG_020_filter-source-file-gap.md) | `filter_source_file` absent from `vector_search()` — added as FR-010 | Open |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Mutation Protection for Source-Managed Files (Priority: P1)

A speckit skill calls `memory_store` to persist a summary. It mistakenly sets `source_file` to something other than `"synthetic"`. The call is rejected with a structured error instructing the caller to use `source_file: "synthetic"` for all agent-generated content. The existing ADR chunks in the index remain untouched.

Separately, a skill calls `memory_delete` with a `source_file` path matching a real on-disk file. The call is rejected — real file chunks are managed by `memory_sync` only, not by agent tool calls.

**Why this priority**: Without this guard, a single misbehaving skill call silently corrupts or destroys the chunk representation of a real ADR, causing `memory_recall` to return stale, fabricated, or missing content. This is a data integrity issue that compounds silently over time.

**Independent Test**: Given a project with `.specify/memory/ADR_008_lancedb-vector-backend.md` present on disk and indexed, when `memory_store` is called with `source_file=".specify/memory/ADR_008_lancedb-vector-backend.md"`, then the response contains a structured error instructing use of `source_file: "synthetic"`, and a subsequent `memory_recall("LanceDB")` still returns the original ADR content unchanged.

**Acceptance Scenarios**:

1. **Given** `source_file` is any value other than `"synthetic"`, **When** `memory_store` is called, **Then** the call is rejected with a structured MCP error containing a machine-readable code (e.g., `INVALID_SOURCE_FILE`) and a message instructing use of `source_file: "synthetic"`
2. **Given** `source_file` is `"synthetic"`, **When** `memory_store` is called, **Then** the write succeeds — no regression on the intended path
3. **Given** a `source_file` path that matches a file present on disk, **When** `memory_delete` is called with that path, **Then** the call is rejected with a structured MCP error stating the file is managed by `memory_sync`
4. **Given** a chunk id for a synthetic chunk, **When** `memory_delete` is called with that id, **Then** the deletion succeeds — id-based deletes for synthetic chunks are not affected
5. **Given** a write or delete is rejected, **When** the caller checks the index for that file's chunks, **Then** the original chunks from `memory_sync` are intact and queryable

---

### User Story 2 - Caller-Controlled Token Budget (Priority: P2)

A speckit skill calls `memory_recall` in a session where context budget is tight. The skill passes `max_chars=8000` to cap the total character count across all returned chunks. The response fits within that ceiling. Every `memory_recall` response also includes a `token_estimate` field so the skill can observe what the call actually cost and tune `top_k` or `max_chars` on future calls.

**Why this priority**: Without budget control, a `memory_recall` call can return up to 30,000 characters (~7,500 tokens) regardless of the caller's context window state. Skills calling recall multiple times per session compound this cost invisibly. Token observability lets callers make informed decisions.

**Independent Test**: Given a project with at least 10 indexed chunks whose combined content exceeds 10,000 characters, when `memory_recall("architecture decisions")` is called with `max_chars=4000`, then the total character count of all chunk content in the response does not exceed 4,000 characters, and the response includes a `token_estimate` field with a positive integer value.

**Acceptance Scenarios**:

1. **Given** `max_chars` is set and full results would exceed it, **When** `memory_recall` is called, **Then** chunks are returned in ranked order (greedy top-down packing) until adding the next complete chunk would exceed the budget — that chunk is dropped, not partially included; `max_chars` applies to content characters only, not metadata or response framing
2. **Given** `max_chars` is set smaller than the highest-ranked single chunk, **When** `memory_recall` is called, **Then** that single chunk is returned with content truncated at `max_chars` characters, and `truncated: true` is set in the response — this truncation-of-last-resort only applies when no complete chunk fits
3. **Given** `max_chars` is not set, **When** `memory_recall` is called, **Then** behavior is unchanged from feature 002 — all top-k results returned with no budget enforcement
4. **Given** any `memory_recall` call (with or without `max_chars`), **When** the response is received, **Then** it includes a `token_estimate` field reflecting the approximate token cost of the serialized response payload
5. **Given** `max_chars` is set and at least one ranked chunk was dropped because it would exceed the budget, **When** the response is received, **Then** it includes `budget_exhausted: true`; if all ranked chunks fit within budget, `budget_exhausted: false`

---

### User Story 3 - Summary-Only Recall for Two-Pass Retrieval (Priority: P3)

A speckit skill needs to decide which chunks to read in full before committing to a large context fetch. It calls `memory_recall` with `summary_only: true` and receives a ranked list of `{source_file, section, score}` entries — no chunk content. The skill reviews the list, selects the most relevant entries, and makes a second targeted `memory_recall` with `filters: {source_file: "..."}` to fetch their full content.

**Why this priority**: Two-pass retrieval is an efficiency optimization for sessions with tight context budgets. P2 already provides budget control; this is an additional tool for power callers who want to inspect the candidate list before committing to a full fetch.

**Independent Test**: Given a project with at least 5 indexed chunks, when `memory_recall("technology decisions")` is called with `summary_only: true`, then each result in the response contains `source_file`, `section`, and `score` fields, contains no chunk content, and the total response character count is under 500 characters for a 5-result set.

**Acceptance Scenarios**:

1. **Given** `summary_only: true`, **When** `memory_recall` is called, **Then** results contain `source_file`, `section`, and `score` but no `content` field
2. **Given** `summary_only: true` and `max_chars` are both set, **When** `memory_recall` is called, **Then** `max_chars` limits the number of summary entries returned (counted by serialized entry size)
3. **Given** `summary_only: true`, **When** the response is received, **Then** it still includes `token_estimate` reflecting the cost of the summary response itself
4. **Given** `summary_only: true` returns 0 results, **When** the response is received, **Then** the result list is empty and `token_estimate` is 0 — same shape as a full-content empty result

---

### Edge Cases

- What happens when `max_chars` is zero or negative? The call is rejected with a validation error.
- What happens when `memory_delete` is called with a `source_file` path that exists on disk but is not indexed? The call is rejected — the delete guard checks filesystem presence, not index presence.
- What happens when `source_file` is an empty string in `memory_store`? Rejected by FR-001 — only `"synthetic"` is accepted.
- What happens when `summary_only: true` is combined with metadata filters? Filters apply first (same as full-content mode), then summary projection is applied to the filtered results.
- What happens when the single highest-ranked chunk is truncated by `max_chars`? The `truncated: true` flag in the response signals this; no other chunks are included.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `memory_store` MUST reject any call where `source_file` is not `"synthetic"`, returning a structured MCP error with a machine-readable code (e.g., `INVALID_SOURCE_FILE`) and a message instructing use of `source_file: "synthetic"`
- **FR-002**: `memory_store` MUST continue to accept writes where `source_file` is `"synthetic"` — no regression on the intended path
- **FR-003**: `memory_recall` MUST accept an optional `max_chars` positive integer parameter; when set, the total character count across all returned chunk content MUST NOT exceed this value
- **FR-004**: When `max_chars` is set and no complete chunk fits within the budget, `memory_recall` MUST return the highest-ranked chunk with its content truncated at `max_chars` and MUST set `truncated: true` in the response envelope
- **FR-005**: Every `memory_recall` response MUST include a `token_estimate` field containing a positive integer approximating the token cost of the serialized response payload (chunk content in full mode; metadata fields in summary mode), computed using a `chars / 4` heuristic
- **FR-006**: `memory_recall` MUST accept an optional `summary_only` boolean parameter; when `true`, each result MUST contain `source_file`, `section`, and `score` and MUST NOT contain chunk content
- **FR-007**: `summary_only` and `max_chars` MUST be composable: when both are set, `max_chars` limits the number of summary entries returned (each entry counted by its serialized character size — the concatenated length of `source_file + section + score` as a JSON string). Note: `max_chars` has two distinct behaviors — in full mode it counts content characters only; in summary mode it counts serialized entry size. This divergence is intentional.
- **FR-008**: All new parameters (`max_chars`, `summary_only`, `filter_source_file`) MUST be optional with backward-compatible defaults — no change in behavior when omitted
- **FR-011**: Every `memory_recall` response where `max_chars` is set MUST include a `budget_exhausted` boolean: `true` if at least one ranked result was dropped due to budget, `false` otherwise; when `max_chars` is not set, `budget_exhausted` is omitted
- **FR-009**: `memory_delete` MUST reject any call where the provided `source_file` matches a path present on the local filesystem, returning a structured MCP error stating the file is managed by `memory_sync`; id-based deletes are not affected by this guard. Path comparison MUST resolve paths relative to the repository root using the same `_repo_root()` anchor as `memory_store`, ensuring consistent behavior across both guards. If the source file no longer exists on disk, the delete guard does not fire (orphaned chunks may be deleted by agent tool calls).
- **FR-010**: `memory_recall` MUST accept an optional `filter_source_file` string parameter; when set, only chunks whose `source_file` matches the provided value are returned. This is exposed as a top-level MCP tool parameter rather than a key in the existing `filters` dict because MCP tool schemas require flat parameter declarations for discoverability — `source_file` cannot be a runtime key inside an opaque dict and remain visible in the tool schema.

### Key Entities

- **Write Guard**: The whitelist validation in `memory_store` that rejects any `source_file` value other than `"synthetic"`. Only `"synthetic"` is accepted; all other values are rejected regardless of whether they exist on disk.
- **Delete Guard**: The validation in `memory_delete` that rejects path-based deletes where `source_file` matches a path present on the local filesystem. Id-based deletes for synthetic chunks are not affected.
- **Token Estimate**: An integer field in every `memory_recall` response approximating the token cost of the returned content. Computed locally without a network call.
- **Budget**: The caller-specified ceiling (`max_chars`) on total character count across all chunk content in a `memory_recall` response. When budget is binding, `budget_exhausted: true` is set in the response so callers can distinguish a partial result set from a complete one.
- **Summary Result**: A lightweight recall result containing `source_file`, `section`, and `score` with no chunk content. Returned when `summary_only: true`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `memory_store` calls with any `source_file` value other than `"synthetic"` are rejected 100% of the time — zero successful non-synthetic writes across all test cases
- **SC-002**: `memory_recall` with `max_chars=N` returns responses whose total chunk content character count does not exceed N in any test case
- **SC-003**: `token_estimate` in every `memory_recall` response is within 20% of the actual token count of the serialized response payload, approximated using a `chars / 4` heuristic
- **SC-004**: `memory_recall` with `summary_only: true` returns responses at least 10x smaller in character count than an equivalent full-content recall for the same query and corpus
- **SC-005**: All existing callers that omit the new parameters observe no change in existing response fields or behavior — additive fields (e.g., `token_estimate`) are always present but do not alter existing field semantics

## Assumptions

- Token estimation is approximate; exact tokenizer parity with the downstream LLM is not required — within 20% using the `chars / 4` heuristic is sufficient for budget-planning purposes
- **Threat model for mutation guard**: callers are speckit skills running in the same session, not untrusted external clients. The guard targets accidental misuse (a skill passes the wrong `source_file`), not adversarial path traversal. The `memory_delete` filesystem check uses the path as provided; symlink/relative-path normalization is not in scope — this is an accepted consequence of the accidental-misuse threat model.
- Two-pass retrieval is a caller-side pattern — this feature provides `summary_only` and `filter_source_file` but does not enforce or document a retrieval protocol on skills
- `max_chars` applies to content characters only — metadata fields and response framing are not counted against the budget
- Chunk content is never partially returned mid-sentence except in the single-chunk truncation edge case (FR-004); clean character-boundary truncation is acceptable
- Cleanup of existing index corruption (de-duplication, stale synthetic chunk purge, health audit) is deferred to feature 004 (LOG-018); the mutation guard closes the hole going forward but does not repair prior state
