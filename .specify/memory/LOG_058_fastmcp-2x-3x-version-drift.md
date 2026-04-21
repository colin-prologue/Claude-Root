# LOG-058: FastMCP 2.x → 3.x Installed-Version Drift vs. Declared Range

**Date**: 2026-04-20
**Type**: CHALLENGE
**Status**: Open
**Raised In**: speckit.audit full-repo findings (2026-04-20) § MEDIUM M3
**Related ADRs**: ADR-009 (Python + FastMCP runtime)

---

## Description

`memory-server/pyproject.toml:7` declares `"fastmcp>=2.0"`. The currently-installed
version (per `uv pip list` in the active venv) is `fastmcp==3.2.0`. `CLAUDE.md:19`
documents the framework as "FastMCP 2.0+", and every feature plan.md Technical
Context section repeats that line. FastMCP has moved into a major-version 3.x series
with unknown backwards-compat guarantees, but no record exists of which 3.x APIs the
server now relies on or when the crossover happened.

## Context

ADR-009 chose FastMCP based on the 2.x API surface (decorator-based tool
registration, env-based transport selection). A 2.0→3.0 major bump typically signals
breaking changes. The server's code continues to work, but that's empirical —
there's no documented validation that the decorator semantics used in
`speckit_memory/server.py` survive 3.x unchanged. If a user installs fresh from
pyproject today, pip may resolve either 2.x or 3.x depending on release timing;
there's no pin preventing divergence between dev and user envs.

## Discussion

### Pass 1 — Initial Analysis

Options:
1. Pin to `fastmcp>=2.0,<3` and keep the 2.x baseline. Requires checking current
   code still works on 2.x and downgrading the dev env.
2. Bump the declared baseline to `fastmcp>=3.0` and update CLAUDE.md + plan.md docs
   to "3.0+". Requires reading FastMCP 3.x release notes and validating our usage.
3. Pin tightly (`fastmcp>=3.2,<4`) and move on — accept 3.x as the new baseline.

### Pass 2 — Critical Review

Option 1 is safest-rollback but implies a dev-env downgrade. Option 2 locks us into
3.x without a formal validation step. Option 3 is pragmatic and reflects reality:
the installed version works in tests; pin to what runs.

The missing artifact is the 3.x release-notes check. Without that, any option is
semi-blind. Recommended path: read FastMCP 3.0 and 3.1 release notes for breaking
changes affecting our decorator usage, then choose Option 3 (or Option 1 if the
notes surface a regression).

## Resolution

Pending release-notes review. No code change yet.

**Resolved By**: ADR-NNN (to be written after release-notes check)
**Resolved Date**: N/A

## Impact

- [ ] Pyproject updated: `memory-server/pyproject.toml:7` — replace `>=2.0` with
      validated pin
- [ ] CLAUDE.md updated: line 19 framework version
- [ ] Plan Technical Context lines in 002/003/005/006/007/008 plan.md files
      updated to reflect validated version
- [ ] ADR created/updated: possible new ADR if the 3.x bump adds behavior that
      warrants a formal decision
