# Feature Specification: BM25 Keyword Fallback for memory_recall

**Feature Branch**: `007-bm25-keyword-fallback`
**Created**: 2026-04-16
**Status**: Complete
**Input**: BM25 keyword fallback for memory_recall — graceful degradation when Ollama is unavailable

## Decision Records

| # | Type | File | Title | Status |
|---|---|---|---|---|
| ADR-032 | Decision | ADR_032_006-scope-errors-vs-bm25.md | Feature 006 Scope — Structured Errors Only, BM25 Deferred to 007 | Accepted |
| ADR-039 | Decision | ADR_039_config-error-no-fallback.md | EMBEDDING_CONFIG_ERROR Does Not Trigger BM25 Fallback | Accepted |
| ADR-040 | Decision | ADR_040_fallback-score-normalized.md | Fallback Results Include Normalized [0,1] Score Field | Accepted |
| ADR-041 | Decision | ADR_041_fallback-stderr-warning.md | BM25 Fallback Emits stderr Warning | Accepted |
| LOG-042 | Update | LOG_042_fallback-score-spec-replacement.md | Spec Statement Replacement — Fallback Score Exposure (Q2 — 2026-04-16) | Resolved |
| ADR-043 | Decision | ADR_043_in-process-tf-scoring.md | In-Process Term-Frequency Scoring for BM25 Fallback | Accepted |
| ADR-044 | Decision | ADR_044_response-error-no-fallback.md | ResponseError Does Not Trigger BM25 Fallback | Accepted |
| LOG-045 | Challenge | LOG_045_response-error-routing-challenge.md | ResponseError Routing Challenge — Hard Error vs Fallback at Task-Gate Review | Resolved |
| LOG-046 | Update | LOG_046_timeout-message-dead-in-recall.md | TimeoutException Message Unreachable in memory_recall | Accepted |
| LOG-047 | Update | LOG_047_silent-fallback-visibility.md | Silent Fallback Visibility Gap | Open |
| LOG-048 | Update | LOG_048_store-sync-fallback-asymmetry.md | Store/Sync Fallback Asymmetry | Open |

## Clarifications

### Session 2026-04-16

- Q: Should `EMBEDDING_CONFIG_ERROR` (bad OLLAMA_BASE_URL) trigger BM25 fallback or surface as a hard error? → A: Hard error — no fallback. Same treatment as `EMBEDDING_MODEL_ERROR`. But the error message MUST include the problematic value and an actionable hint so the user can fix the misconfiguration.
- Q: Should fallback results include a `score` field, and if so how is it expressed? → A: Yes — normalized [0,1] term-frequency score in the same `score` field as semantic results. Interface must be consistent regardless of path.
- Q: Should the fallback path emit a stderr warning in addition to `degraded: true`? → A: Yes — emit a `[speckit-memory] WARNING:` line to stderr, consistent with the existing `_ensure_init` warning pattern.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Recall Succeeds When Ollama Is Down (Priority: P1)

A skill (e.g., `/speckit.plan`, `/speckit.review`) calls `memory_recall` to surface relevant prior decisions before generating a plan. Ollama is not running. Today, the call returns a hard `ToolError` and the skill gets nothing. After this feature, the same call returns keyword-ranked results from the stored index, with a `degraded: true` flag indicating lower quality.

**Why this priority**: The primary value of this feature is that `memory_recall` continues to function when Ollama is down. Everything else is secondary.

**Independent Test**: Given a populated memory index with stored chunks and Ollama unavailable, when `memory_recall("technology choices architecture decisions")` is called, the response includes at least one result ranked by keyword relevance, and the envelope contains `degraded: true`. No `ToolError` is raised.

**Acceptance Scenarios**:

1. **Given** Ollama is unreachable (connection refused), **When** `memory_recall("architecture decisions")` is called, **Then** the response contains results ranked by keyword relevance and `degraded: true` in the envelope.
2. **Given** Ollama times out on the embed call, **When** `memory_recall("prior review findings")` is called, **Then** the response contains results ranked by keyword relevance and `degraded: true` in the envelope.
3. **Given** Ollama is unreachable and the index is empty, **When** `memory_recall("any query")` is called, **Then** the response returns `results: []`, `total: 0`, and `degraded: true` — no error raised.
4. **Given** Ollama is available and responds normally, **When** `memory_recall` is called, **Then** the semantic path is used and `degraded` is absent from the response envelope (no change to current behavior).

---

### User Story 2 - Callers Can Distinguish Fallback from Semantic Results (Priority: P2)

A skill reads `memory_recall` results and decides whether to include a caveat ("Note: these results are keyword-ranked; Ollama was unavailable"). This is only possible if the response reliably signals which path was used.

**Why this priority**: Without the `degraded` flag, callers must detect degraded mode by absence or by parsing error codes — both fragile. The flag is a contract, not an implementation detail.

**Independent Test**: Given two consecutive calls — one with Ollama available and one with Ollama unavailable — the first response has no `degraded` key and the second has `degraded: true`. The caller can branch on this field without inspecting any other part of the response.

**Acceptance Scenarios**:

1. **Given** Ollama is available, **When** `memory_recall` returns results, **Then** the response envelope does NOT contain a `degraded` key.
2. **Given** Ollama is unavailable and fallback runs, **When** the response is returned, **Then** `response["degraded"]` is exactly `True` (boolean).
3. **Given** `summary_only=True` is passed, **When** the call completes (summary_only path is unaffected), **Then** `degraded` is absent from the response.

---

### User Story 3 - Filters and Budget Enforcement Apply in Fallback Mode (Priority: P3)

A skill calls `memory_recall` with `filters={"feature": "005"}` and `max_chars=2000` to scope results. Ollama is down. The fallback results must respect the same filter and budget constraints as the semantic path — otherwise, callers cannot trust that parameter semantics are consistent across modes.

**Why this priority**: Behavioral inconsistency between semantic and fallback modes would force callers to treat them as different interfaces. Consistency is a correctness property, not a nice-to-have.

**Independent Test**: Given an index with chunks from features 004, 005, and 006, Ollama unavailable, when `memory_recall("decisions", filters={"feature": "005"}, max_chars=500)` is called, the response contains only feature-005 chunks and the total content returned does not exceed 500 characters.

**Acceptance Scenarios**:

1. **Given** Ollama is unavailable and `filter_source_file="synthetic"` is passed, **When** fallback runs, **Then** only chunks with `source_file == "synthetic"` appear in results.
2. **Given** Ollama is unavailable and `max_chars=200` is passed, **When** fallback runs, **Then** the total content of returned chunks does not exceed 200 characters, and `budget_exhausted` is set correctly.
3. **Given** Ollama is unavailable and `filters={"type": "synthetic"}` is passed, **When** fallback runs, **Then** only chunks with `type == "synthetic"` appear in results.
4. **Given** Ollama is unavailable and `top_k=3` is passed, **When** fallback runs, **Then** at most 3 results are returned.

---

### Edge Cases

- What happens when the query is empty or whitespace? All chunks score 0.0 (empty query produces no term matches); they are returned in table order up to `top_k` with `degraded: true`, not an error.
- What happens when `EMBEDDING_MODEL_ERROR` (model not found) or `EMBEDDING_CONFIG_ERROR` (bad URL) is raised? Neither triggers fallback — both are misconfigurations. `CONFIG_ERROR` surfaces as a hard ToolError with the bad URL value and an actionable hint naming the environment variable to fix.
- What happens when the index has chunks but none match the query keywords? The fallback returns `results: []`, `degraded: true`, `total: 0` — not an error.
- What happens when all chunks exceed `max_chars`? Existing truncation-of-last-resort behavior applies: the first result is truncated to `max_chars` and `truncated: true` is set in the envelope.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When `memory_recall` is called in semantic mode and the embedding service is unreachable or times out, the system MUST fall back to keyword-ranked search over stored chunks rather than raising an error.
- **FR-002**: The BM25/keyword fallback MUST match query terms against both the `content` and `section` fields of stored chunks.
- **FR-003**: Fallback results MUST be ranked by relevance to the query using occurrence-count TF scoring — chunks where query terms appear more times rank higher than chunks where they appear fewer times or not at all.
- **FR-004**: The response envelope MUST contain `degraded: true` when the fallback path was used, and MUST NOT contain a `degraded` key when the semantic path was used.
- **FR-005**: The fallback path MUST NOT require building or maintaining a separate search index beyond what is already stored.
- **FR-006**: All existing filter parameters (`filters`, `filter_source_file`, `top_k`) MUST apply in the fallback path with the same semantics as the semantic path.
- **FR-007**: The `max_chars` budget enforcement and `budget_exhausted` flag MUST apply in the fallback path, consistent with the semantic path.
- **FR-008**: Fallback results MUST include the same fields as semantic results: `id`, `content`, `score`, `source_file`, `section`, `type`, `feature`, `date`, `tags`, `synthetic`. The `score` field MUST be a normalized [0,1] occurrence-count TF value: raw score is the sum of occurrences of each query term in `content + section`; normalized by dividing by the maximum raw score across all candidate chunks (best match = 1.0; no-match = 0.0).
- **FR-009**: `EMBEDDING_MODEL_ERROR` (model not found), `EMBEDDING_CONFIG_ERROR` (bad OLLAMA_BASE_URL), and all `ollama_sdk.ResponseError` instances MUST NOT trigger the BM25 fallback — these are server-side or configuration errors that keyword results cannot fix. Only true network-layer failures (`ConnectionError`, `OSError`, `httpx.TransportError`) trigger fallback. (ADR-039, ADR-044)
- **FR-011**: When `EMBEDDING_CONFIG_ERROR` is raised, the error message MUST include the actual misconfigured value (the bad URL) and an actionable hint naming the environment variable the user must correct (e.g., `OLLAMA_BASE_URL`).
- **FR-010**: The `summary_only` path is unaffected by this feature — it already bypasses embedding and MUST NOT receive a `degraded` flag.
- **FR-012**: When the BM25 fallback path activates, the server MUST emit a warning to stderr using the format `[speckit-memory] WARNING: embedding unavailable — falling back to keyword search`. This is consistent with the existing server warning pattern.

### Key Entities

- **Recall response envelope**: The structured object returned by `memory_recall`. Gains one new optional field: `degraded` (boolean, present only when fallback was used).
- **Fallback score**: A normalized [0,1] occurrence-count TF score, included in the `score` field of each fallback result. Raw score = sum of occurrences of each query term in `content + section`; normalized to [0,1] by dividing by the maximum raw score across all candidate chunks. Best-matching chunk = 1.0; no-match = 0.0. (Q2 — 2026-04-16, amended 2026-04-17)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: When Ollama is unavailable, `memory_recall` returns results rather than an error in 100% of calls (assuming a non-empty index).
- **SC-002**: Callers can determine which path was used by inspecting a single boolean field in the response envelope — no string parsing, no error inspection required.
- **SC-003**: Fallback results correctly rank chunks — a chunk whose content contains query terms more times scores higher than a chunk containing those terms fewer times or not at all (e.g., a chunk with "architecture" 5 times ranks above one with "architecture" once, which ranks above one with 0 occurrences).
- **SC-004**: All existing filter parameters produce the same narrowing behavior in fallback mode as in semantic mode — no filter is silently ignored.
- **SC-005**: Fallback mode adds no new external dependencies beyond what is already in the index (no new index files, no new services, no network calls).

## Assumptions

- The existing error infrastructure (`_embed_error`, `EMBEDDING_UNAVAILABLE` code, `ToolError`) from feature 006 is the trigger boundary — no changes to error categorization are needed.
- `scan_chunks` (added in 006) performs a full table scan; the BM25 fallback extends this pattern by adding term-frequency scoring over results, rather than introducing a new scan mechanism.
- `EMBEDDING_MODEL_ERROR` and `EMBEDDING_CONFIG_ERROR` are both misconfiguration signals, not transient failures, and are therefore intentionally excluded from the fallback trigger. (Q1 — 2026-04-16)
- Ranking quality in fallback mode is explicitly acknowledged as lower than semantic search — this is acceptable and communicated via `degraded: true`.
- LanceDB native FTS was evaluated and rejected (adds `tantivy` dependency, violates FR-005/SC-005). In-process occurrence-count TF scoring was chosen — see ADR-043.
