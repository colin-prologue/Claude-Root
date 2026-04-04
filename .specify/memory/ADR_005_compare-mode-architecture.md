# ADR-005: `--compare` Mode Architecture

**Date**: 2026-04-03
**Status**: Accepted
**Decision Made In**: specs/000-review-benchmark/plan.md § Phase 0 Research
**Related Logs**: None

---

## Context

FR-009 requires a `--compare` mode that reads three saved run files and produces a Coverage
by Rigor Level table + PASS/FAIL verdict for STANDARD. This is a fundamentally different
operation from running a review — it reads files and builds a comparison table, it does not
spawn agents. The question is whether this lives in the same command file as the review
profiling or in a separate command.

## Decision

Single command file (`.claude/commands/speckit.review-profile.md`) with explicit conditional
branching: if `$ARGUMENTS` contains `--compare`, execute the comparison workflow; otherwise
execute the review profiling workflow.

## Alternatives Considered

### Option A: Separate `speckit.review-profile-compare.md` command

Two separate command files, each focused on one operation.

**Pros**: Cleaner separation of concerns; each file is shorter.
**Cons**: Duplicates run-file format knowledge and benchmark-key.md lookup logic across
two files; two files to update when the format changes; increases discovery friction for
the maintainer.

### Option B: Single command with conditional branching *(chosen)*

**Pros**: One file to find; shared format knowledge; simpler maintenance; consistent with
Principle II (Simplicity). Claude Code command conditionals work naturally — the executing
Claude reads "if --compare is present, do X; else do Y" in markdown.
**Cons**: Longer file; two distinct workflows in one document.

## Rationale

Both modes share the same mental model (benchmark profiling), the same user (a maintainer
who just ran three reviews), and the same artifact knowledge (run-file format, benchmark-key
structure). Separating them into two files creates maintenance overhead with no user benefit.
The conditional is simple and well-scoped.

## Consequences

**Positive**: One command to discover; shared format logic; consistent maintenance target.
**Negative / Trade-offs**: The command file is longer than a single-purpose file.
**Risks**: If the branching logic is unclear, a user might inadvertently trigger the wrong
mode. Mitigated by explicit `--compare` flag detection at the top of the command.
**Follow-on decisions required**: None.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-03 | Initial record | speckit.plan |
