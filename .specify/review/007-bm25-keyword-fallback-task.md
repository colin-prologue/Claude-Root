# Review in Progress: 007-bm25-keyword-fallback — task gate
**Started**: 2026-04-17T01:12:00Z
**Phase**: complete — awaiting gate decision
**Panel**: devils-advocate

---

## Phase A: Devil's Advocate

### Most Dangerous Assumption
"Unique query terms found in content+section / total unique query terms" is described as "TF scoring" but is binary set-intersection presence, not term frequency. A chunk mentioning "architecture" 20 times scores identically to one mentioning it once. FR-003 says "chunks with more query-term matches rank higher" — but "more matches" is satisfied only at the term-type level, not occurrence level. At 50–200 chunks with 2–5 word queries, there are only 3–4 distinct score values, producing massive tie bands. SC-003 ("contains 3 terms scores higher than 0 terms") is trivially satisfied; the discriminating case is not.

### Critical Findings

1. **Scoring algorithm mislabeled (CRITICAL)** — ADR-043 is titled "In-Process Term-Frequency Scoring" and FR-003 says "term frequency or equivalent scoring," but the formula is set-membership (binary presence), not TF. This is a decision-transparency violation (Principle VII): the ADR, FR, and tasks all describe different behavior than what will be implemented. Fix is cheap: change numerator to occurrence counts. But the artifacts must be corrected first. Confidence: 90%.

2. **HTTP 5xx ResponseError triggers fallback (HIGH)** — Plan.md's justification that "404 is the only MODEL_ERROR case; all other ResponseError are UNAVAILABLE" is asserted, not evidenced. Ollama can return 500 (model OOM), 400 (malformed input), 401/403 (auth). These would silently trigger fallback and paper over real infra problems. A tighter exception filter (network-layer exceptions only) would be safer. Confidence: 85%.

3. **No test for CONFIG_ERROR propagation through new handler (HIGH)** — T004 tests the error message content; it does not assert the ToolError is not caught by the new except clause. The ToolError is raised *inside* `_embed_text(query)` which is inside the try block. If the except is later widened (or coded incorrectly), T004 still passes (it presumably catches ToolError before the try in a different mock). No invariant test guards this. Confidence: 80%.

4. **No test for stderr warning (MEDIUM)** — FR-012 mandates a specific warning string. No task asserts it is emitted. Observable via capsys; regression risk.

5. **contracts/memory_recall.md not updated in tasks (MEDIUM)** — T013 updates CLAUDE.md; nothing in the task list updates the tool contract doc. New degraded field and fallback path are contract changes. Principle VI violation.

6. **min_score silently ignored in fallback (MEDIUM)** — A caller passing min_score=0.8 gets unfiltered TF results. No warning, no documentation in task list (only buried in tasks.md Notes). The contract doc should state this.

7. **Binary scoring produces unstable tie-ordering (LOW-MEDIUM)** — With 3–4 distinct score values, tie frequency is high. Sort is stable (Python), so order depends on LanceDB scan insertion order — LanceDB internal behavior. Tests that assert specific top-N results under ties will be flaky unless chunks are padded to guarantee unique scores.

8. **No test for rollback/kill switch (LOW)** — No env-var guard for disabling fallback. If fallback ranking is judged worse than erroring for skill callers, there is no escape valve. Cheap to add; arguable whether needed.

### Genuinely Sound
- TDD ordering in tasks is correct: T002–T007 (tests) explicitly gate before T009–T010 (implementations). T008 confirms red state. Principle III satisfied.
- [P] markers on T007, T013, T015 are legitimate — different files, no hidden dependencies.
- ADR coverage for major decisions is good: ADR-039 (config error), ADR-040 (score normalization), ADR-041 (stderr warning), ADR-043 (algorithm). LOG-042 (spec replacement) is resolved.
- The INVARIANT block in plan.md (must not catch ToolError) is correctly reasoned — CONFIG_ERROR is raised before any network call, inside _embed_text(), which is called inside the try block. The risk is real but the invariant is documented.
- No new dependencies, no new index files — Principle II compliance confirmed.
- ~141 LOC estimate is plausible.
- summary_only path correctly excluded from degraded flag (FR-010).
