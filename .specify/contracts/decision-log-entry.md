# Contract — Decision-Log Entry (Canonical Markdown)

**File**: `specs/[###]/decisions-log.md`
**Format**: Markdown, append-only within a run, single writer at a time (per ADR-013/ADR-016).
**Schema source of truth**: FR-006.

---

## Section template

Every entry is a level-2 markdown section. The heading and key-value block carry the FR-006 fields; subagent-record entries have additional named sub-blocks.

```markdown
## <entry_type>:<stage> · <timestamp>

- author: <orchestrator | subagent:<stage>>
- status: <success | halt | error>
- run_id: <run-...>

<rationale — free-text markdown, one or more paragraphs>
```

Heading parsing: the `## ` prefix, followed by `<entry_type>:<stage>`, then `· <ISO-8601>` separator. The ` · ` (U+00B7 middle dot, single-spaced) is the canonical separator; readers MUST treat any whitespace-bracketed `·` or `-` between heading components as the separator for forward compatibility.

## Subagent-record extension

When `entry_type=subagent-record`, three named sub-blocks MUST follow the rationale:

```markdown
### artifacts_written

- specs/010-autonomous-workflow/plan.md
- specs/010-autonomous-workflow/research.md

### decisions_made

- decision: <one-line summary>
  rationale: <one-line summary>
  alternatives: <one-line summary, comma-separated>

- decision: ...
  rationale: ...
  alternatives: ...

### halt_directive

- halt: <true | false>
- reason: <required if halt=true; omitted if false>
- failure_class: <required if halt=true; one of `temporal`, `semantic`, `permission` per FR-019; omitted if false>
```

`decisions_made` is a list of YAML-style nested entries. Empty `decisions_made` is permitted (e.g., a stage that produced no architectural decisions); the heading and an empty list (`-`) MUST still appear so readers can distinguish "stage produced no decisions" from "stage failed to record decisions."

## Validation contract (`run-validate-entry.sh`)

Input: path to `decisions-log.md` and the byte offset of the entry to validate (typically the last entry).

Exit codes:
- `0` — entry passes schema. stdout empty.
- `1` — schema violation. stdout: one diagnostic per line (`field: <name>; problem: <description>`).
- `2` — usage error (file not found, offset invalid).

Validation MUST check:
1. Heading matches `^## (stage-start|stage-end|stage-skip|escalate|route|abort|subagent-record):(<canonical-stage>) [·-] <ISO-8601-UTC>$`.
2. Required key-value fields (`author`, `status`, `run_id`) present and well-formed. *(`run_id` format is currently checked for presence only — see LOG-024 for the open question on whether to enforce `^run-<ISO-8601-UTC>-[a-f0-9]{6}$`.)*
3. `status` ∈ {`success`, `halt`, `error`}.
4. `author` matches `^orchestrator$` or `^subagent:<canonical-stage>$`.
5. If `entry_type=subagent-record`: all three sub-blocks (`artifacts_written`, `decisions_made`, `halt_directive`) present.
6. If `halt_directive.halt=true`: a non-empty `reason` follows AND `failure_class` ∈ {`temporal`, `semantic`, `permission`} (FR-019 three-class taxonomy). Missing or unrecognized `failure_class` is a schema violation.

Validation MUST NOT check:
- Rationale content (free text by design).
- Path existence in `artifacts_written` (orchestrator's sandbox audit covers this separately).

## Example entry

```markdown
## subagent-record:plan · 2026-04-26T20:14:12Z

- author: subagent:plan
- status: success
- run_id: run-2026-04-26T20:00:00Z-a1b2c3

Plan-phase questions all resolved. Three new ADRs (019/020/021) and supporting
research artifacts written. Constitution gates pass; PR split documented.

### artifacts_written

- specs/010-autonomous-workflow/plan.md
- specs/010-autonomous-workflow/research.md
- specs/010-autonomous-workflow/data-model.md
- .specify/memory/ADR_019_deterministic-orchestrator-core.md
- .specify/memory/ADR_020_sidecar-format-jsonl.md
- .specify/memory/ADR_021_smoke-tier-fixture-budget.md

### decisions_made

- decision: Bash-helper-driven deterministic orchestrator core
  rationale: Locates ADR-017's deterministic surface concretely; enables Tier 1 testing of routing logic
  alternatives: LLM-resident routing, Python helpers

- decision: JSONL for `.run/control-flow.log`
  rationale: Append-friendly, parse-friendly, truncation-tolerant; sidecar consumer is code not humans
  alternatives: Structured markdown, TSV

- decision: Single fixture + 50K/100K budget for V1 smoke tier
  rationale: Contract verification not behavioral coverage; Tier 1 covers routing variations
  alternatives: Two fixtures, full-pipeline fixture, no smoke tier

### halt_directive

- halt: false
```
