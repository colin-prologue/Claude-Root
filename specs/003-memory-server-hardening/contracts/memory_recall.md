# Contract: `memory_recall` Tool (Feature 003)

**Tool**: `memory_recall`
**Server**: `speckit-memory` (FastMCP)
**Changed by**: Feature 003 (003-memory-server-hardening)

---

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `query` | `str` | *(required)* | Natural language search query |
| `top_k` | `int` | `5` | Maximum results before budget enforcement |
| `min_score` | `float` | `0.5` | Minimum cosine similarity threshold [0, 1] |
| `filters` | `dict \| None` | `None` | Metadata pre-filters: `type`, `feature`, `tags` |
| `max_chars` | `int \| None` | `None` | **NEW** — Cap on total content characters across all results |
| `summary_only` | `bool` | `False` | **NEW** — Return metadata only (no chunk content) |
| `filter_source_file` | `str \| None` | `None` | **NEW** — Restrict results to this source_file value |

### Validation

- `max_chars`: must be a positive integer when set. Zero or negative → structured error
  `{"error": {"code": "INVALID_INPUT", "message": "max_chars must be a positive integer"}}`
- All other parameters: unchanged validation from feature 002.

---

## Response: Full-Content Mode (default)

```json
{
  "results": [
    {
      "id": "uuid-string",
      "content": "chunk text",
      "score": 0.87,
      "source_file": ".specify/memory/ADR_008_lancedb-vector-backend.md",
      "section": "Decision",
      "type": "adr",
      "feature": "002",
      "date": "2026-04-08",
      "tags": [],
      "synthetic": false
    }
  ],
  "total": 1,
  "token_estimate": 42,
  "budget_exhausted": false
}
```

### Response: Full-Content Mode — Truncation Edge Case

When `max_chars` is set and the single highest-ranked chunk exceeds the budget:

```json
{
  "results": [
    {
      "id": "uuid-string",
      "content": "first 4000 characters of chunk...",
      "score": 0.91,
      "source_file": "...",
      "section": "...",
      "type": "adr",
      "feature": "001",
      "date": "2026-04-07",
      "tags": [],
      "synthetic": false
    }
  ],
  "total": 1,
  "token_estimate": 1000,
  "budget_exhausted": true,
  "truncated": true
}
```

---

## Response: Summary-Only Mode (`summary_only: true`)

```json
{
  "results": [
    {
      "source_file": ".specify/memory/ADR_008_lancedb-vector-backend.md",
      "section": "Decision",
      "score": 0.87
    },
    {
      "source_file": "specs/002-vector-memory-mcp/plan.md",
      "section": "Summary",
      "score": 0.74
    }
  ],
  "total": 2,
  "token_estimate": 12
}
```

Note: `budget_exhausted` is omitted when `max_chars` is not set.

---

## Behavior Rules

### Budget Enforcement (`max_chars`)

1. Compute `chars_remaining = max_chars`
2. Iterate chunks in score-descending order:
   - If `len(chunk.content) <= chars_remaining`: include chunk; subtract `len(chunk.content)` from remaining
   - Else: drop chunk; set `budget_exhausted = True`
3. If no chunk was included and `results` is empty:
   - Include the highest-ranked chunk with content truncated to `max_chars`; set `truncated = True`; set `budget_exhausted = True`
4. Set `budget_exhausted` in response (only when `max_chars` is set)

### Token Estimate

`token_estimate = ceil(total_content_chars / 4)`

- Full mode: `total_content_chars` = sum of `len(r["content"])` for all returned results
- Summary mode: `total_content_chars` = sum of `len(r["source_file"] + r["section"] + str(r["score"]))` for all returned summary entries
- Empty results: `token_estimate = 0`

### `filter_source_file`

Applied as a LanceDB WHERE clause pre-filter before vector search (same as `filter_type`).
Combined with any `filters` dict conditions using AND.

### Composability

`summary_only` and `max_chars` compose:
- `max_chars` in summary mode counts serialized entry size (source_file + section + score as JSON string)
- The packing algorithm is the same greedy approach, applied to summary entries instead of full chunks

---

## Backward Compatibility

All new parameters (`max_chars`, `summary_only`, `filter_source_file`) are optional with defaults
that reproduce feature-002 behavior:
- No `max_chars`: all top-k results returned, no budget enforcement, no `budget_exhausted` field
- `summary_only: false`: full content returned (identical to feature 002)
- No `filter_source_file`: no source-file pre-filter (identical to feature 002)
- `token_estimate` is always present (additive; does not alter existing field semantics)
