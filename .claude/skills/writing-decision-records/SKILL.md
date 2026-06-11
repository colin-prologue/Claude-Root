---
name: writing-decision-records
description: This skill should be used when the user asks to "write an ADR", "create an ADR", "record this decision", "document this choice", "create a LOG", "log this challenge", "raise an open question", "flag this as a decision", "name it as a decision", "write an AGDR", "record this judgment call", or when an architectural choice, technology selection, schema design, integration pattern, or accepted tradeoff is being committed to during planning, implementation, or review — including pivotal judgment calls the agent makes autonomously without the project owner in the loop. Also applies when any of /speckit.plan, /speckit.implement, /speckit.audit, or /speckit.review surface a decision or unresolved item that requires a cross-referenced memory file. Covers the ADR-vs-LOG-vs-AgDR rubric, NNN counter scan, template paths, and mandatory back-references (Principle VII — NON-NEGOTIABLE).
---

# Writing Decision Records

Enforce Principle VII (Decision Transparency, NON-NEGOTIABLE) by producing a cross-referenced memory file whenever a decision is made or a significant question is raised. Use this skill at the moment of authoring, not after the fact.

## Choose the record type

Decide ADR or LOG before opening a template.

| Situation | Record | Status at creation |
|---|---|---|
| Technology, library, or service chosen | ADR | Accepted |
| System structure, module boundary, integration pattern | ADR | Accepted |
| Data model, schema shape, serialization format | ADR | Accepted |
| Cross-cutting constraint accepted (latency budget, LOC cap override, etc.) | ADR | Accepted |
| Significant unknown surfaced during planning or research | LOG (QUESTION) | Open |
| Obstacle forcing reconsideration of a plan or spec | LOG (CHALLENGE) | Open |
| Revision to earlier understanding, spec section, or ADR | LOG (UPDATE) | Open or Resolved |
| Review finding accepted as risk without remediation | LOG (CHALLENGE) | Open, marked accepted-risk |
| Pivotal judgment call made autonomously, project owner not in the loop (forecloses alternatives / expensive to reverse / resolves spec-plan ambiguity by interpretation / commits money, scope, or schedule) | AGDR | pending-review |

**Ambiguity rule**: if a choice is being *made*, write an ADR. If something is being *raised but not resolved*, write a LOG. A LOG may later resolve into an ADR — both records persist; each references the other. If the agent is *choosing and proceeding without the project owner*, write an AGDR — it may be promoted to an ADR on ratification.

## Determine the NNN

NNN is a zero-padded three-digit counter **shared across ADR and LOG**. Scan `.specify/memory/` for the highest existing number across both prefixes and increment once.

```bash
ls .specify/memory/ADR_*.md .specify/memory/LOG_*.md 2>/dev/null \
  | grep -oE '(ADR|LOG)_[0-9]{3}' | sort -u | tail -5
```

Never reuse a number. `ADR_001`, `LOG_002`, `ADR_003` is valid; `ADR_004` + `LOG_004` is not.

**AGDR is the exception**: it uses its own independent counter. Scan `.specify/memory/AGDR_*.md` separately and increment within that sequence only.

**Worktree caveat**: unmerged feature branches may hold higher numbers than `main`. Scan ALL active worktrees' (and unmerged branches') `.specify/memory/` before choosing NNN, or collisions land at merge time. Verify a branch is genuinely unmerged first (`git branch --no-merged HEAD`) — stale merged or archive refs can point at retired numbers and inflate the counter.

## Author the file

**ADR**: copy `.specify/templates/adr-template.md` to `.specify/memory/ADR_NNN_short-title.md`. Fill:
- `Date` (today)
- `Status` — Accepted unless the decision is explicitly Proposed
- `Decision Made In` — exact path + section of the spec/plan/task where the decision was reached (e.g., `specs/008-auto-sync-staleness/plan.md § Technical Context`)
- `Related Logs` — LOG numbers that surfaced the concern, or `None`
- `Context`, `Decision`, `Alternatives Considered` (minimum two options), `Rationale`, `Consequences`
- `Amendment History` — initial row only

**LOG**: copy `.specify/templates/log-template.md` to `.specify/memory/LOG_NNN_short-title.md`. Fill:
- `Type` — CHALLENGE, QUESTION, or UPDATE
- `Status` — Open at creation; update to Resolved when an ADR answers it
- `Raised In` — path + section where the issue surfaced
- `Related ADRs` — `None yet` is valid for open questions
- `Description`, `Context`, `Discussion` (at least Pass 1)
- `Resolution` — leave blank for Open logs

Short titles are kebab-case and descriptive: `ADR_042_bm25-keyword-fallback.md`, not `ADR_042_fallback.md`.

**AGDR**: copy `.specify/templates/agdr-template.md` to `.specify/memory/AGDR_NNN_short-title.md`. Fill every section — `Trigger` (at least one pivotal criterion checked), `Options Considered` (the rejected option steelmanned — its strongest honest case), `Revision Conditions`, `Blast Radius` (what builds on this + unwind cost). Status is `pending-review` at creation; **only the project owner moves it** (verdicts: ratified / ratified-promoted → ADR / overturned-inline / overturned-deferred → LOG / superseded). Cite the AGDR in the implementing commit message (`… per AGDR-NNN`). Do not pause work for review — AGDRs resolve at the PR-merge gate; no PR merges with `pending-review` AGDRs in its scope.

## Write the back-reference

A record without a back-reference is incomplete. Both ends of the link must exist.

**In the consuming artifact** (spec.md, plan.md, tasks.md, or constitution.md), update the `## Decision Records` table:

```markdown
| Record | Title | Type | Status | Link |
|---|---|---|---|---|
| ADR-042 | BM25 keyword fallback | Architecture | Accepted | [ADR_042](.specify/memory/ADR_042_bm25-keyword-fallback.md) |
```

If the consuming artifact lacks a Decision Records table, add one under the highest-level heading that makes sense (plan.md typically has it; specs may not).

**In the record**, the `Decision Made In` or `Raised In` field already points back. Verify the path is correct (relative paths resolve from the record's location; using repo-root paths avoids ambiguity).

## Gate rule: no implementation without ADRs

Before `/speckit.implement` (or any hand-written code commit against an unrecorded technology/pattern choice), verify every decision in `research.md`, `plan.md`, or `tasks.md` has a corresponding ADR file. Missing ADRs are a hard stop:

```
🚨 Decision Record Gate Failed (Principle VII)
Missing ADRs for:
  - [decision] — referenced in [path]

Create the missing ADR files (use .specify/templates/adr-template.md) and
add back-references before proceeding.
```

This gate is already wired into `/speckit.plan` and `/speckit.implement`. Run it again from this skill whenever a decision is being authored outside those commands.

## Mid-implementation discoveries

If implementing a task reveals an unplanned architectural decision — choosing between two libraries not in research.md, adopting a design pattern, changing a data contract — **stop the task**, create the ADR or LOG immediately, update cross-references in plan.md or spec.md, then resume. Do not defer.

## Common anti-patterns

- **Deferring the record until "later"**: Principle VII is NON-NEGOTIABLE. The cost of writing the record now is lower than the cost of reconstructing the rationale months later.
- **Writing an ADR for a non-decision**: if there was no alternative considered, no tradeoff accepted, it is not architectural. Skip the record or write it as a LOG (UPDATE) noting what changed.
- **Omitting Alternatives Considered**: an ADR with one option is a memo, not a decision record. Force at least one rejected alternative with stated cons.
- **Broken back-references**: creating the record file without updating the Decision Records table in the consuming artifact leaves the link one-directional. Do both.
- **Re-using NNN across ADR and LOG**: the counter is shared. Check both prefixes before choosing a number.
- **Using memory_store as a substitute**: the memory server indexes the file; it does not replace it. ADRs/LOGs are durable markdown in `.specify/memory/`, not synthetic chunks.

## Resources

- **Templates**: `.specify/templates/adr-template.md`, `.specify/templates/log-template.md`, `.specify/templates/agdr-template.md`
- **Principle VII**: `.specify/memory/constitution.md` § VII (Decision Transparency)
- **Naming conventions**: `.specify/memory/constitution.md` § Development Workflow › Decision Records
- **Memory convention for synthetic summaries**: `.claude/rules/memory-convention.md` (different from ADR/LOG authoring — synthetic chunks summarize, ADRs/LOGs are source-of-truth)
- **Related skill**: `adr-crossref-check` reports ADR/LOG records missing inbound references — run it before closing a feature
