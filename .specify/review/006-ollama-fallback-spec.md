# Review in Progress: 006-ollama-fallback — spec gate
**Started**: 2026-04-13T00:00:00Z
**Phase**: complete — awaiting gate decision
**Panel**: product-strategist, devils-advocate

---

## Phase A: product-strategist

**Risk Assessment**: MEDIUM

| ID | Severity | Finding | Recommendation |
|----|----------|---------|----------------|
| F-001 | HIGH | US-2 (write ops) should be P1 — hanging `memory_sync` more impactful than semantic recall failure | Elevate US-2 to P1 |
| F-002 | MEDIUM | `recoverable` boolean undefined from caller's perspective | Define semantics or drop the field |
| F-003 | MEDIUM | US-1 Scenario 3 "mid-recall" framing is ambiguous/untestable | Rewrite as single-call failure scenario |
| F-004 | MEDIUM | Invalid `OLLAMA_BASE_URL` edge case has no FR | Add FR-009 with `EMBEDDING_CONFIG_ERROR` code |
| F-005 | LOW | Malformed embedding edge case has no FR | Add FR-010 |
| F-006 | LOW | SC-005 "consistent state" undefined | Tighten to specific manifest behavior |
| F-007 | LOW | `_api_unavailable` assumption belongs in plan.md | Move to plan; flag as ADR candidate |

---

## Phase A: devils-advocate

**Critical issues:**
1. **`summary_only` assumption WRONG** — `server.py` line 123 calls `_embed_text(query)` unconditionally before `summary_only` checked at line 146. Two Ollama paths fire before `summary_only` has effect. Confidence: 98% (code verified).
2. **Roadmap-spec divergence** — roadmap describes feature 006 as BM25/keyword fallback; spec delivers structured error messages. These are categorically different: structured errors = polite failure; keyword fallback = tool continues to function.

**Additional findings:**
- `_ensure_init` permanently sets `_first_call_done = True` even on failure — server never recovers
- `memory_delete` calls `_ensure_init()` but not mentioned in spec
- Exception type gap: `httpx.TimeoutException` not caught by `(ConnectionError, OSError)` — FR-004 unimplementable with current catch strategy
- `save_manifest` uses non-atomic `write_text` — FR-008 requires temp-file-rename
- Startup health check (P3/FR-007) may be unnecessary ceremony

---

## Phase B: Devil's Advocate Challenges

**Consensus challenge #1 (summary_only):** Correct empirically, but framing wrong — this is a production bug + checklist process failure, not just "needs verification." The checklist approved the spec while knowing FR-006 depends on an unverified code change.

**Consensus challenge #2 (edge case gaps):** Overstated. Edge cases section is the right place; not every edge case needs an FR. Plan phase addresses these. DA partially disagrees with consensus.

**Consensus challenge #3 (recoverable):** Shallow agreement. `recoverable` already exists in `_api_unavailable` helper (always `True`). Real question: does any caller read it? DA found no evidence any caller branches on it.

**New DA findings in Phase B:**
- `httpx.TimeoutException` (subclass of neither `ConnectionError` nor `OSError`) escapes all current catch clauses — FR-004 timeout-bounded calls unimplementable with current exception strategy
- BM25 scope reduction is strongest objection: Assumption #1 calls BM25 an "alternative embedding provider" but BM25 is a text search algorithm that needs no embedding — the exclusion is a straw man

---

## Phase B: product-strategist Response

**summary_only:** Maintained — strengthened. Risk is LOC budget and hidden code-change prerequisite. Spec should either scope FR-006 conditionally or call out code-change dependency explicitly.

**Edge case gaps:** Partially withdrawn. Only malformed-URL / FR-003 gap holds as spec-level issue (materially different corrective action).

**recoverable:** Maintained — strengthened by DA evidence. DA confirmed no caller branches on it. Spec extends unvalidated pattern; constitution says Simplicity is NON-NEGOTIABLE. Drop or define.

**BM25 scope reduction (new, confirmed):** Highest severity. Roadmap says "BM25 keyword fallback over chunk content." Spec dismisses BM25 as "alternative embedding provider" — that characterization is incorrect. Requires ADR or explicit rationale.

**FastMCP error channel (new, confirmed):** FR-001 doesn't specify whether structured error is returned via tool return value or protocol-level exception. Plan phase must resolve; spec should flag as decision point.

---
