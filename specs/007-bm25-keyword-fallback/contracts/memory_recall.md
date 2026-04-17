# Contract: memory_recall Tool

**Feature**: 007-bm25-keyword-fallback
**Date**: 2026-04-16
**Change type**: Additive (new optional response fields; existing behavior unchanged when Ollama is available)

## Tool Signature (unchanged)

```python
memory_recall(
    query: str,
    top_k: int = 5,
    min_score: float = 0.5,
    filters: dict | None = None,
    max_chars: int | None = None,
    filter_source_file: str | None = None,
    summary_only: bool = False,
) -> dict[str, Any]
```

## Response Envelope

### Semantic path (Ollama available) — unchanged

```json
{
  "results": [...],
  "total": <int>,
  "token_estimate": <int>,
  "budget_exhausted": <bool>   // only when max_chars provided
}
```

### BM25 fallback path (EMBEDDING_UNAVAILABLE) — 007 addition

```json
{
  "results": [...],
  "total": <int>,
  "token_estimate": <int>,
  "degraded": true,            // NEW: present iff fallback was used
  "budget_exhausted": <bool>   // only when max_chars provided
}
```

**Contract rules**:
- `degraded` key is ABSENT when semantic path ran (not `false`, absent)
- `degraded: true` is present whenever BM25 fallback ran
- `summary_only` path: `degraded` is ALWAYS absent (unaffected by this feature)

## Result Object

### Semantic path (unchanged)

```json
{
  "id": "<uuid>",
  "content": "<string>",
  "score": <float 0.0–1.0>,    // cosine similarity
  "source_file": "<string>",
  "section": "<string>",
  "type": "<string>",
  "feature": "<string>",
  "date": "<string>",
  "tags": ["<string>", ...],
  "synthetic": <bool>
}
```

### BM25 fallback path

Same fields as semantic path. `score` is a normalized [0,1] occurrence-count TF value: raw score = sum of occurrences of each query term in `content + section` (case-folded); normalized so the best-matching chunk = 1.0 and no-match = 0.0. Score is NOT comparable to semantic cosine similarity scores.

```json
{
  "id": "<uuid>",
  "content": "<string>",
  "score": <float 0.0–1.0>,    // keyword TF score — NOT cosine similarity
  "source_file": "<string>",
  "section": "<string>",
  "type": "<string>",
  "feature": "<string>",
  "date": "<string>",
  "tags": ["<string>", ...],
  "synthetic": <bool>
}
```

## Error Cases (unchanged)

| Condition | Response |
|-----------|----------|
| `max_chars <= 0` | `{"error": {"code": "INVALID_INPUT", ...}}` |
| `EMBEDDING_CONFIG_ERROR` (bad URL) | `ToolError("EMBEDDING_CONFIG_ERROR: ... got: <url> ...")` — **no fallback** |
| `EMBEDDING_MODEL_ERROR` (404 ResponseError) | `ToolError("EMBEDDING_MODEL_ERROR: ...")` — **no fallback** |
| `ResponseError` (non-404: 500, 400, 401, 403, etc.) | `ToolError("EMBEDDING_UNAVAILABLE: ...")` — **no fallback** (ADR-044) |
| `EMBEDDING_UNAVAILABLE` (network/timeout: `ConnectionError`, `OSError`, `httpx.TransportError`) | BM25 fallback — **returns results with `degraded: true`** |

## Behavioral Invariants

- Filters (`filters`, `filter_source_file`, `top_k`) behave identically in both paths
- `min_score` is intentionally NOT applied in fallback mode — TF scores are not comparable to cosine similarity. The `degraded: true` flag already signals reduced quality; callers should not rely on `min_score` as a noise filter in fallback mode (ADR-040)
- `max_chars` enforcement and `budget_exhausted` flag behave identically in both paths
- Truncation-of-last-resort (first result truncated when all exceed `max_chars`) applies in fallback mode
- Results in both paths are ordered by `score` descending (highest relevance first)
- Fallback emits `[speckit-memory] WARNING: embedding unavailable — falling back to keyword search` to stderr (ADR-041)
