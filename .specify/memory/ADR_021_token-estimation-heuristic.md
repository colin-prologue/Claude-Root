# ADR-021: Token Estimation Heuristic (chars / 4)

**Date**: 2026-04-09
**Status**: Accepted
**Decision Made In**: specs/003-memory-server-hardening/plan.md § Phase 0 Research
**Related Logs**: None

---

## Context

Feature 003 adds a `token_estimate` field to every `memory_recall` response. The field is intended
to let callers observe the approximate token cost of the recall payload so they can tune `top_k`
or `max_chars` on future calls. The question is how to compute this estimate — which approximation
method to use without adding new dependencies or network calls.

The downstream consumer is a Claude model session. The exact tokenizer is Anthropic's internal BPE;
it is not publicly distributed. SC-003 accepts ≤20% error relative to the actual serialized token
count, framed as a budget-planning signal rather than a billing measurement.

## Decision

Use `len(content) / 4` (integer division rounding up) as the token count approximation. Apply this
to the total character count of all chunk content fields (full mode) or serialized entry strings
(summary mode) in the response. No external tokenizer, no network call.

## Alternatives Considered

### Option A: `chars / 4` heuristic *(chosen)*

Count characters across all returned chunk content fields; divide by 4.

**Pros**: Zero-dependency, zero-latency, consistent with the widely-accepted "~4 chars per token"
rule-of-thumb for English prose. SC-003's ≤20% tolerance is satisfied for typical ADR/spec text.
No model-specific coupling.
**Cons**: Exact error varies by content language and structure. JSON framing and metadata fields
are excluded from the count by design (FR-005 scopes the estimate to content characters only).

### Option B: tiktoken (OpenAI BPE tokenizer)

Use the `cl100k_base` or `o200k_base` tokenizer from the `tiktoken` PyPI package.

**Pros**: More accurate for GPT-family models.
**Cons**: Adds a PyPI dependency. OpenAI-specific — not the tokenizer used by Claude. Adds latency
for the tokenization step. Precision beyond the ≤20% tolerance has no practical value for a
budget-planning signal.

### Option C: Anthropic public tokenizer (if available)

**Pros**: Would match exactly.
**Cons**: Anthropic does not publish a standalone tokenizer package for Claude. Not viable.

## Rationale

No caller needs billing-exact token counts — they need a cheap planning signal. The `chars / 4`
heuristic is well within the ≤20% tolerance for English prose (typical ADR and spec text) and
eliminates any risk of external dependency drift or API tokenizer version mismatch. Consistent
with how most LLM tooling approaches rough context budgeting.

## Consequences

**Positive**: No new dependencies. Zero additional latency. Easy to understand and test.
**Negative / Trade-offs**: Accuracy degrades for non-English content and dense code blocks
(ratio closer to 2-3 chars/token). Accepted per spec Assumptions ("within 20% using chars/4
heuristic is sufficient").
**Risks**: Low. The estimate is advisory only; callers should treat it as a rough signal.
**Follow-on decisions required**: None.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-09 | Initial record | /speckit.plan |
