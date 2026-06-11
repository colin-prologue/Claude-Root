# ADR-031: Adopt Agent Decision Records (AgDR) in the Template

**Date**: 2026-06-10
**Status**: Accepted
**Decision Made In**: Porting session 2026-06-10 (source of truth: mini-fax `ADR_043_agent-decision-records.md` @ `49c63e4`); consumers wired at `.claude/rules/conventions.md` § Decision Records, `.claude/skills/writing-decision-records/SKILL.md`, `.specify/scripts/bash/check-adr-crossrefs.sh`, `.claude/commands/speckit.codereview.md` § Operating Principles, and `constitution.md` § Development Workflow › Decision Records (v1.3.0)
**Related Logs**: None

---

## Context

mini-fax (bootstrapped from this template) designed and shipped the Agent
Decision Record in its ADR-043: a third record type for pivotal judgment
calls an agent makes autonomously, with the owner out of the loop. Its
motivating failure mode applies to every project this template spawns —
delegated and autonomous runs (here: `/speckit.run`, feature 010) accumulate
scope shifts, risk acceptances, and ambiguity interpretations with no
ratification trail. ADRs presume a ratified decision; LOGs capture
challenges and questions, not "I chose X and proceeded."

This repo is the template source: anything not ported here reaches no
consuming project, because `/speckit.init` distributes only what exists in
this tree.

## Decision

Port the portable subset of mini-fax's AgDR pattern into the template:

- `.specify/templates/agdr-template.md` — record template (steelman of the
  rejected option, revision conditions, and blast radius are mandatory).
- `.claude/rules/conventions.md` — AgDR type row; AGDR's own independent
  counter (`AGDR_001…`, separate from the shared ADR/LOG counter); two new
  Definition of Done items (zero `pending-review` AGDRs at merge; `/speckit.retro`
  run interactively with an owner-approved `roadmap.md` diff).
- `.claude/skills/writing-decision-records/SKILL.md` — AGDR rubric row,
  ambiguity-rule extension (choosing and proceeding without the owner → AGDR),
  own-counter note, scan-all-worktrees-before-numbering caveat, and an AGDR
  authoring block.
- `.specify/scripts/bash/check-adr-crossrefs.sh` — `AGDR_*.md` glob and
  `(ADR|LOG|AGDR)` key regex.
- `.claude/commands/speckit.codereview.md` — AGDRs loaded into doc context;
  an uncited diff-visible pivotal judgment is a HIGH finding; a
  `pending-review` AGDR in PR scope is a merge-blocking note, not a code defect.

Capture rules carried over unchanged: pivotal-only (forecloses alternatives /
expensive to reverse / resolves spec-plan ambiguity by interpretation /
commits money, scope, or schedule); fully async (write the record, cite it in
the implementing commit, keep working — no mid-run pause); binding owner
review at the PR-merge gate with verdicts ratified / ratified-promoted → ADR /
overturned-inline / overturned-deferred → LOG / superseded.

All distributed files use generic "project owner" phrasing and refer to "the
project's AgDR adoption ADR" rather than a hardcoded number — each adopting
project writes its own adoption record, as this one is Claude-Root's.

## Alternatives Considered

### Option A: Port the portable subset, generic phrasing in distributed files *(chosen)*

**Pros**: consuming projects inherit the full mechanism via `/speckit.init`
smart-merge with no dangling references; existing machinery (crossref check,
Principle VII, authoring skill) extends rather than forks; mini-fax remains
the proven reference implementation.
**Cons**: generic phrasing is one indirection removed — a consumer must write
its own adoption ADR for the criteria's full rationale to exist locally.

### Option B: Port mini-fax's wiring verbatim, including its ADR-043 references

**Pros**: zero translation effort; text already battle-tested in place.
**Cons**: distributed files would cite a record (`ADR-043`) that exists in no
consuming project, and "Colin" would leak into a template meant for arbitrary
owners; mini-fax-specific history (PR 4, LOG-024/025, the ADR_040/LOG_040
collision) is noise outside its repo.

### Option C: Do not adopt in the template; leave AgDR per-project

**Pros**: keeps the template smaller; projects without autonomous runs never
see the extra record type.
**Cons**: defeats the purpose of a template — every consumer doing delegated
work would re-derive the same governance from scratch, and the gap AgDR
closes (invisible pivotal calls) is precisely the kind that goes unnoticed
until it bites.

## Rationale

The pattern is already validated where it matters: mini-fax designed it
against concrete failures (stale roadmap, implicit ratification of
agent-drafted risk acceptances, prose-recommended steps never executing under
delegation). This template ships `/speckit.run` — the same autonomous-execution
surface — so the governance gap exists here and in every consumer. Porting
the portable subset (Option A) gets consumers the mechanism at bootstrap
time; generic phrasing is what makes the files safe to distribute wholesale,
which is exactly how `/speckit.init` merges rules and skills ("add missing,
don't overwrite"). The own-counter rule is kept because renumbering the
shared ADR/LOG sequence to interleave AGDRs would perturb every existing
cross-reference for no benefit.

## Consequences

**Positive**: every project bootstrapped or updated from this template gets
decision provenance for autonomous work; review happens at the PR-merge gate
while overturning is still a cheap on-branch replan; the steelman and
blast-radius fields counter self-justifying records.
**Negative / Trade-offs**: one more record type for sessions to load; the
Definition of Done gains two gates (pending-AGDR check, interactive retro);
`.specify/memory/` can now hold records in a pending state.
**Risks**: (1) The pivotal test is self-administered — an agent that
misjudges "routine" never writes the record. Mitigation: the codereview rule
flags diff-visible judgments lacking a citation; the owner's diff review is
the backstop. (2) This ADR itself has no inbound reference from `specs/`
(the crossref script's scan surface) — it is referenced from
`constitution.md` § Decision Records instead, joining the existing set of
infra records not tied to a feature spec. Accepted until a feature spec
consumes AGDRs. (3) Consumers updated via smart-merge get the new DoD items
appended to conventions they may have customized; `/speckit.init` reports
rather than overwrites, so divergence is visible.
**Follow-on decisions required**: None. (A consumer's first AGDR and its own
adoption ADR are applications of this decision.)

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-06-10 | Initial record | Claude (Fable 5) + Colin, porting session |
