# ADR-024: Summary-Mode Character Counting Uses JSON Serialization

**Date**: 2026-04-12
**Status**: Accepted
**Decision Made In**: `memory-server/speckit_memory/server.py:159,183` (implicit implementation decision during feature 003)
**Related Logs**: LOG-025

---

## Context

Feature 003 added `summary_only` mode to `memory_recall`, which returns lightweight `{source_file, section, score}` entries instead of full chunk content. When `summary_only` is combined with `max_chars`, the budget enforcement loop needs a consistent way to measure each summary entry's size.

Two measurement approaches are possible:
1. Raw field concatenation: `len(r["source_file"] + r["section"] + str(r["score"]))`
2. JSON serialization: `len(json.dumps(r))`

The difference is ~50 chars per entry — JSON framing adds key names, quotes, braces, and colons.

## Decision

We measure summary entry size using `json.dumps(r)` (JSON serialization), because the entries are consumed by callers as JSON and the caller's actual token/character budget is spent on the serialized form, not raw field values.

## Alternatives Considered

### Option A: `json.dumps(r)` *(chosen)*

Measure using `len(json.dumps({"source_file": ..., "section": ..., "score": ...}))`.

**Pros**: Matches what the caller actually receives over the wire; consistent with how the caller would count characters; token_estimate reflects real caller cost.
**Cons**: Slightly more computation per entry.

### Option B: Raw field concatenation

Measure using `len(r["source_file"] + r["section"] + str(r["score"]))`.

**Pros**: Simpler; matches the logical content size.
**Cons**: Underestimates caller-visible size by ~50 chars per entry; misrepresents the actual budget impact; token_estimate would be systematically low.

## Rationale

`max_chars` is a caller-controlled budget. Its purpose is to let callers limit how many characters land in their context window. The serialized JSON form is what actually lands there, so measuring the serialized form is the more honest interpretation of the budget constraint.

Test T015b (`test_recall_summary_only_with_max_chars_budget`) validates the json.dumps approach explicitly — seeds 3 chunks with 300-char content, sets max_chars=150, and asserts 2 summary entries fit (each ~67 serialized chars) rather than 0 (which raw content measurement would produce).

## Consequences

**Positive**: Caller budget control is accurate; token_estimate reflects wire cost.
**Negative / Trade-offs**: Contract documentation must specify json.dumps, not field concatenation — easy to get wrong if updating the contract without reading the code.
**Risks**: If the summary entry shape changes (e.g., new fields added), the per-entry size changes silently. Not a risk unless the summary schema is extended.
**Follow-on decisions required**: None.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-12 | Initial record (surfaced by /speckit.audit post-implementation) | consistency-auditor |
