# Memory Convention

Speckit skills integrate with the `memory` MCP server (from feature 002-vector-memory-mcp) via a recall-before / store-after convention.

## Memory is best-effort

**The memory server is optional infrastructure.** Skills MUST NOT block or fail if memory calls are unavailable, return errors, or time out. If `memory_recall` or `memory_store` is not in the available tool list, or returns an error, skip the step silently and continue. Memory improves context quality; it is never a prerequisite for skill correctness.

Signals that memory is unavailable:
- The tool is absent from the MCP tool list (server not registered or failed to start)
- The tool returns an error (server crashed, Ollama down with no index to fall back to)
- `degraded: true` in the recall response (BM25 fallback active — results are usable but lower quality)

## Recall-before

Skills that produce plans, reviews, or decisions SHOULD call `memory_recall` at the start to surface relevant prior decisions. Example queries:

- `/speckit.plan`: `memory_recall("technology choices architecture decisions")`
- `/speckit.review`: `memory_recall("prior review findings open risks")`
- `/speckit.tasks`: `memory_recall("implementation patterns task dependencies")`

## Store-after

Skills that produce durable artifacts SHOULD call `memory_store` at the end to persist a summary. Use this metadata shape:

```json
{
  "source_file": "synthetic",
  "section": "<skill name> summary",
  "type": "synthetic",
  "feature": "<feature number>",
  "date": "<ISO date>",
  "tags": ["<skill-name>", "<feature-name>"]
}
```

Content should be a 2-5 sentence summary of the key decisions or findings — dense enough to be useful in future recall, short enough to stay in budget.

## Which skills must recall / store

| Skill | Recall | Store |
|---|---|---|
| `/speckit.plan` | Yes — pull prior ADRs | Yes — store plan summary |
| `/speckit.review` | Yes — pull prior findings | Yes — store synthesis |
| `/speckit.tasks` | Optional | No |
| `/speckit.implement` | Optional | No |
| `/speckit.audit` | Yes — pull ADRs for compliance check | Yes — store audit findings |

## Synthetic chunk management

Chunks stored by skills have `synthetic: true`. Delete them by `id` (returned by `memory_store`), never by `source_file = "synthetic"` — that would delete all synthetic chunks project-wide.

Skills that re-run (e.g., `/speckit.plan` revised) should delete the prior summary chunk (by id, if stored) before storing the new one, to avoid accumulation.
