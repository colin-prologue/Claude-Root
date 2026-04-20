---
name: adr-crossref-check
description: This skill should be used when the user asks to "check ADR cross-references", "audit decision record links", "verify Principle VII compliance", "find orphan ADRs", or wants to confirm every ADR/LOG in .specify/memory/ is referenced from at least one spec/plan/tasks artifact under specs/. Use proactively before closing a feature (alongside /speckit.audit) or after bulk-adding decision records. Does not fix gaps — it only reports them.
---

# ADR Cross-Reference Check

Surface decision records with no inbound references from `specs/**/*.md`. Principle VII (Decision Transparency, NON-NEGOTIABLE) requires every ADR and LOG to be cross-referenced with the spec/plan artifacts it governs. This skill reports one direction only: memory → specs. Reverse-direction checks (specs with no ADR refs) are out of scope.

## When to run

- Before merging a feature branch, after `/speckit.implement` and before `/speckit.audit`.
- After bulk-adding ADRs or LOGs (e.g., retroactive documentation sweeps).
- When `/speckit.audit` surfaces drift and you want a focused second pass.

## How it works

Runs `.specify/scripts/bash/check-adr-crossrefs.sh`, which:

1. Enumerates `.specify/memory/ADR_*.md` and `.specify/memory/LOG_*.md`.
2. Extracts the `(ADR|LOG)_NNN` key from each filename.
3. Greps `specs/` for either `ADR_NNN`/`LOG_NNN` or `ADR-NNN`/`LOG-NNN` (both formats appear in prose).
4. Prints records with zero matches.

Exit codes:
- `0` — all records referenced.
- `2` — one or more records missing references. The skill treats `2` as "report and surface to user," not a failure.

## Usage

```bash
.specify/scripts/bash/check-adr-crossrefs.sh
```

Read the output. For each missing record:
- If the record is obsolete, propose archiving or marking superseded via a LOG (UPDATE).
- If the record is current, identify the spec/plan/tasks file it should link from and propose the cross-reference edit — but do not apply it without user confirmation. Cross-references often belong in multiple places; let the user decide.

## Scope and non-goals

- **In scope:** memory → specs direction, all ADR and LOG files regardless of status.
- **Out of scope:** specs → memory reverse check, content-quality review, superseded-status validation, auto-fixing gaps.
- **Related:** `/speckit.audit` performs broader bidirectional consistency auditing; run this skill as a pre-flight for that command.
