# ADR-055: Metadata Filter Predicate — Shared Helper vs. Accepted Duplication

**Date**: 2026-04-20
**Status**: Proposed
**Decision Made In**: speckit.audit full-repo findings (2026-04-20) § HIGH H3
**Related Logs**: None yet

---

## Context

`memory-server/speckit_memory/index.py` implements the same metadata-filter predicate
(`filter_type`, `filter_feature`, `filter_tags`, `filter_source_file`) in three
functions:

- `scan_chunks` (lines 149–156) — Python list-comprehension filter
- `vector_search` (lines 179–188) — SQL WHERE-clause construction
- `keyword_search` (lines 243–250) — Python list-comprehension filter (byte-identical
  to `scan_chunks`)

Rule-of-Three threshold (per `.claude/rules/conventions.md`) reached. Two of the three
are literal duplicates; the third differs only because it builds SQL instead of a
Python closure. A change to one filter surface (e.g., add `filter_date_range`) must
be replicated in three places.

## Decision

Proposed (pending user confirmation): extract a single filter-spec data structure
consumed by both a Python predicate builder and a SQL WHERE-clause builder. Both
`scan_chunks` and `keyword_search` call the Python builder directly; `vector_search`
calls the SQL builder. The four currently-supported filter fields become a
declarative spec dict; new fields add one helper entry.

## Alternatives Considered

### Option A: Shared predicate builder (two variants) *(chosen)*

Extract `_build_filter_predicate(spec) -> Callable[[row], bool]` for Python paths and
`_build_filter_sql(spec) -> str` for the LanceDB search. Call sites reduce to one
line.

**Pros**: Single source of truth; new filter field added in one place; Python and
SQL variants share the spec schema so drift is impossible by construction.
**Cons**: Two functions instead of one; SQL vs. Python path still has minor
duplication in the spec consumption.

### Option B: Single Python predicate for all three, discard SQL

Have `vector_search` pull all candidate rows and filter in Python.

**Pros**: Truly one implementation.
**Cons**: Destroys the LanceDB WHERE-push-down optimization. On a 10k-chunk index,
SQL push-down avoids materializing rows that would be filtered out. Measurable
regression; not acceptable.

### Option C: Accept the duplication (demote to LOG)

Record the rule-of-three hit as a LOG (CHALLENGE) and leave the code as-is.

**Pros**: Zero code change; preserves current clarity (each function is
self-contained).
**Cons**: Next filter field added triggers three edits. History shows this happens
(filter_source_file was added in feature 003 after the initial two filters).

## Rationale

Option A preserves the performance benefit of SQL push-down in `vector_search` while
eliminating the two literal duplicates. The spec-dict intermediate ensures any new
filter field is added once and flows to both variants. Option B's regression is
disqualifying; Option C defers the cost without eliminating it.

## Consequences

**Positive**: New filter fields are single-site edits; `scan_chunks` and
`keyword_search` become trivial wrappers around the shared predicate.
**Negative / Trade-offs**: Two helpers instead of one; reviewers must understand the
Python/SQL split.
**Risks**: Python predicate and SQL WHERE could drift in subtle cases (e.g., `NULL`
vs. `None` comparison, empty-tag semantics). Mitigation: shared unit tests exercising
the same spec against both variants.
**Follow-on decisions required**: None — if the refactor lands, this ADR flips to
Accepted and the Amendment History records the implementation commit.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-20 | Initial record — surfaced by /speckit.audit (full-repo, H3) | Claude (speckit.audit) |
