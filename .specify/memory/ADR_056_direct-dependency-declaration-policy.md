# ADR-056: Declare Direct Imports in `pyproject.toml`

**Date**: 2026-04-20
**Status**: Accepted
**Decision Made In**: speckit.audit full-repo findings (2026-04-20) § MEDIUM M4
**Related Logs**: None yet

---

## Context

`memory-server/speckit_memory/` directly imports two packages that are not declared
in `memory-server/pyproject.toml`:

- `httpx` — imported in `server.py:15` for the Ollama HTTP health probe
- `pyarrow as pa` — imported in `index.py:10` for LanceDB schema construction

Both packages are currently resolved transitively: `httpx` via `ollama` and
`fastmcp`; `pyarrow` via `lancedb`. If either upstream drops the transitive, the
server breaks at import with no signal in the dependency graph — the failure surface
is a silently-reduced version-compatibility window.

Principle II (Lean over Elaborate) does not excuse undeclared direct imports. The
rule is Python-ecosystem-standard: if you import it, you depend on it.

## Decision

Proposed: declare any package imported by `speckit_memory/*.py` in
`[project.dependencies]` of `pyproject.toml`, with a minimum version matching the
currently-used API surface. For the present gap, add `httpx>=0.27` and
`pyarrow>=15.0` (versions pulled from the current lockfile).

## Alternatives Considered

### Option A: Declare every direct import *(chosen)*

Add `httpx` and `pyarrow` to `[project.dependencies]`; audit periodically with
`deptry` or equivalent.

**Pros**: Explicit dep graph; upstream version changes don't surprise us;
standard Python packaging practice.
**Cons**: One-time effort to audit + two more lines in pyproject.

### Option B: Accept transitive deps

Document in pyproject that we rely on ollama/fastmcp/lancedb to continue providing
httpx/pyarrow.

**Pros**: Zero code change.
**Cons**: Fragile — one upstream minor release away from runtime breakage; contrary
to Python community practice; invisible to dependency scanners.

### Option C: Vendor or pin transitively

Pin the upstream providers (ollama, lancedb) tightly so we control which transitive
versions arrive.

**Pros**: Controlled env.
**Cons**: Multiplies the upgrade burden; hides the direct dep; still undeclared.

## Rationale

Option A is the only one that aligns with Python packaging norms and produces an
accurate dep graph. The cost is trivial (two lines + one lockfile refresh). Option B
leaves a latent failure mode; Option C trades clarity for control in a solo-dev
project that doesn't need it.

## Consequences

**Positive**: Accurate dep graph; `pip install speckit-memory` reliably pulls
everything needed; dependency scanners (Dependabot, etc.) can see the real surface.
**Negative / Trade-offs**: Minor — two additional versions to keep aligned on
upgrades; offset by the visibility this buys.
**Risks**: None material — versions are pinned to what's already in the lockfile.
**Follow-on decisions required**: Add a one-line note to `CLAUDE.md` or the project
README describing the declare-what-you-import rule.

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-20 | Initial record — surfaced by /speckit.audit (full-repo, M4) | Claude (speckit.audit) |
| 2026-04-21 | Accepted + implemented: `httpx>=0.27` and `pyarrow>=15.0` added to `memory-server/pyproject.toml` dependencies; `uv lock` refreshed | Claude |
