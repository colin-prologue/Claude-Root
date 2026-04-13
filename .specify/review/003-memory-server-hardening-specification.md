# Review in Progress: 003-memory-server-hardening — specification gate
**Started**: 2026-04-09T02:00:00Z
**Phase**: A (independent analysis)
**Panel**: product-strategist, devils-advocate

---

## Phase A: Product Strategist

**Overall Risk**: MEDIUM

| ID | Severity | Finding |
|----|----------|---------|
| F-01 | MEDIUM | Pre-existing synthetic chunks stored with non-synthetic `source_file` (pre-003) are irrecoverable via agent tools after delete guard ships — no escape hatch. Should be an explicit assumption. |
| F-02 | MEDIUM | `token_estimate` semantics under `summary_only: true` are unspecified — what does `chars/4` apply to when there's no content? |
| F-03 | LOW | Greedy packing boundary case (budget exactly equals chunk) not covered by acceptance scenarios. |
| F-04 | LOW | FR-010 (`filter_source_file`) described as US3's filter, but it stands alone as generically useful. Should be decoupled to avoid being deprioritized with US3. |
| F-05 | LOW | US1 independent test covers `memory_store` rejection but not `memory_delete` rejection — no definition-of-done test for the delete guard. |

---

## Phase A: Devils Advocate

**Most Dangerous Assumption**: Delete guard path resolution undefined — `os.path.exists(source_file)` (CWD-relative) vs `os.path.exists(repo_root / source_file)` (repo-relative). Existing `memory_store` code uses repo-root resolution but spec never mandates this for FR-009.

| Finding | Severity |
|---------|----------|
| Delete guard uses filesystem check instead of `synthetic` field — orphaned chunks (file deleted from disk) become unprotectable | HIGH |
| Delete guard path resolution undefined (CWD vs repo root) | HIGH |
| FR-007 `summary_only` + `max_chars` composability is Principle II violation — no caller needs budget control on 500-char summary responses | MEDIUM |
| FR-010 `filter_source_file` as standalone param creates API inconsistency with existing `filters: dict` pattern | MEDIUM |
| Write guard lives in server.py only, not data layer — no defense in depth if second write path is ever added | MEDIUM |
| `truncated: true` flag location unspecified — envelope level or per-chunk? | LOW |

---

**Phase**: B (cross-examination)


## Phase B: Devil's Advocate Challenges

- **Delete guard consensus**: Partially groupthink. Write guard (whitelist) and delete guard (filesystem check) use incompatible models — structurally different operations, but path resolution in FR-009 is genuinely undefined (CWD vs repo-root) and inconsistent with how `memory_store` resolves paths.
- **`token_estimate` under summary_only consensus**: Validated as genuine. "Returned content" is ambiguous when content is absent — trivial to fix.
- **FR-007 composability**: Principle II violation — `max_chars` has two behaviors (content chars in full mode, serialized entry size in summary mode). Summaries are 10x smaller already; no caller has demonstrated need for budget control on them. Proposes dropping FR-007 or using `top_k` instead.
- **filter_source_file API shape**: Design decision hiding as implementation detail — should be an ADR. MCP flat-param requirements may justify it, but the rationale is unstated.
- **Budget observability gap**: `truncated: true` fires only for edge case. Normal budget packing (chunks dropped) has no caller signal. Proposes `budget_exhausted` indicator.

## Phase B: Product Strategist Response

- **F-1 (path resolution)**: Strengthened. Two incompatible models is not inherently wrong (different operations), but path resolution unspecified is a genuine gap — FR-009 must state anchor (repo root). Confidence: 85%.
- **F-2 (token_estimate)**: Unchanged. FR-005 should say "serialized response payload."
- **F-3 (FR-007)**: Doesn't accept "drop it." Counter-proposal: spec should explicitly document the behavioral divergence and define "serialized entry size." `top_k` conflates retrieval count with response budget — two separate concerns.
- **F-4 (filter_source_file)**: Agrees with DA — warrants ADR; inconsistency has user-facing cost. 90% confidence this needs stated rationale.
- **F-5 (budget observability)**: Strengthened to MEDIUM. Caller can't distinguish "partial picture due to budget" from "full picture." Without a `budget_exhausted` signal, two-pass pattern is undermined. Recommend adding acceptance scenario to US2.

---

**Phase**: C (synthesis)


## Phase C: Synthesis

### Executive Summary

Revision closed the first-round findings. Three genuine gaps remain: FR-009 delete guard path resolution undefined (HIGH), `token_estimate` semantics under `summary_only` unspecified (MEDIUM), budget exhaustion unobservable (MEDIUM). All are one-sentence or one-field fixes.

### Consensus Findings

| ID | Severity | Finding | Action |
|----|----------|---------|--------|
| S-1 | HIGH | FR-009 path resolution undefined — will cause false matches or bypasses depending on CWD vs repo-root | Add one sentence anchoring to `_repo_root()`, matching `memory_store` behavior |
| S-2 | MEDIUM | `token_estimate` under `summary_only: true` unspecified — "returned content" has no content field | FR-005: define token_estimate as serialized response payload, not chunk content |
| S-3 | MEDIUM | Budget exhaustion invisible — caller can't tell if results are partial | Add `budget_exhausted: bool` to recall response envelope |

### Notable Minority

- M-1 MEDIUM: FR-007 `max_chars` has two behaviors (content chars vs serialized entry size) — document divergence; don't split params at this scale
- M-2 MEDIUM: `filter_source_file` top-level param breaks `filters: dict` pattern — add rationale note in spec

### Decisions

- PS position favored over DA on FR-007 (document divergence, don't redesign API)
- PS position favored on delete guard model (path-based is correct; spec must note behavior for deleted-from-disk source files)

---

**Phase**: complete — awaiting gate decision

