# LOG-061: `MEMORY_REPO_ROOT` Auto-Derive Assumes Source-Tree Layout

**Date**: 2026-04-22
**Type**: CHALLENGE
**Status**: Open
**Raised In**: /speckit.codereview on branch `skill-plugin-optimization` (DA Uncovered U3, 2026-04-22)
**Related ADRs**: ADR-052 (three-component model)
**Related LOGs**: LOG-057 (`MEMORY_REPO_ROOT` documented)

---

## Description

`memory-server/speckit_memory/server.py` auto-derives the repo root by walking
three parents up from `__file__` when `MEMORY_REPO_ROOT` is unset. This assumes
the canonical source-tree layout: `<repo>/memory-server/speckit_memory/server.py`.
If the package is installed into site-packages (e.g., `pip install speckit-memory`),
`__file__` lives at `.../site-packages/speckit_memory/server.py` and `parent.parent.parent`
returns something like `.../lib/python3.x/`, which is not a speckit repo root.

## Context

Auto-derive was added in feature 006 as a pragmatic default for the monorepo
workflow (`uv run --directory memory-server speckit-memory`). `MEMORY_REPO_ROOT`
is the documented escape hatch. The server docstring mentions the out-of-tree
case; `CLAUDE.md`'s env-var table does not surface the layout constraint.

Feature 009 (`speckit init`) and ADR-052's three-component model anticipate the
server being installed into arbitrary host projects. At that point the
site-packages layout is the common case, not the edge case, and users who skip
setting `MEMORY_REPO_ROOT` will see the server connect to a phantom root.

## Discussion

### Pass 1 — Initial Analysis

Options:
1. Detect site-packages layout and refuse to auto-derive; log a fatal error that
   tells the user to set `MEMORY_REPO_ROOT`.
2. Add a more robust auto-derive: walk upward from `$PWD` looking for a
   `.specify/` marker, falling back to `__file__`-based derivation only for the
   source-tree case.
3. Document the constraint prominently in `CLAUDE.md` and leave the code
   unchanged until a published distribution forces the change.

### Pass 2 — Critical Review

Option 1 is strict but correct for published installs. Option 2 is ergonomic and
covers both the monorepo and published cases but introduces a filesystem scan at
server start. Option 3 defers the cost to the moment someone actually hits this
— appropriate while the server is not on PyPI.

## Resolution

Deferred. Decision revisit triggers: (a) the server is published to PyPI, (b)
feature 009 (`speckit init`) ships, or (c) a user reports phantom-root behavior.
At revisit, default to Option 2.

**Resolved By**: deferred
**Resolved Date**: N/A

## Impact

- [ ] Code updated: deferred
- [ ] Spec updated: N/A
- [ ] ADR created/updated: none required
