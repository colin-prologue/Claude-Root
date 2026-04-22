# LOG-058: FastMCP 2.x → 3.x Installed-Version Drift vs. Declared Range

**Date**: 2026-04-20
**Type**: CHALLENGE
**Status**: Resolved
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

Pin-up to `fastmcp>=3.2,<4`. FastMCP 3.0 release notes (PrefectHQ/fastmcp v3.0.0, 2026-02-18) explicitly state: *"The surface API is largely unchanged — `@mcp.tool()` still works exactly as before."* Our server.py uses only the stable surface: `FastMCP("speckit-memory")`, `@mcp.tool()`, and `from fastmcp.exceptions import ToolError`. None of the 3.x-only feature set (provider/transform architecture, component versioning, auth middleware, OpenTelemetry) is load-bearing in our code. Removed APIs (`WSTransport`, `FastMCP.as_proxy()`, `require_auth`) are not used. The 3.2.0 install was already passing all 119 non-integration tests at audit time; pin-up documents reality rather than downgrading a working env.

No new ADR required: ADR-009 still stands (FastMCP chosen as MCP runtime); no 3.x-specific behavior is relied on.

**Resolved By**: `memory-server/pyproject.toml` pin `fastmcp>=3.2,<4`; CLAUDE.md + 002/003/005/006/007/008 plan.md Technical Context lines updated to "FastMCP 3.2+"
**Resolved Date**: 2026-04-21

**Pin scope clarification (2026-04-22, post code-review)**: the `<4` upper bound is
**semver-conservative, not empirically validated**. Validation was performed against
FastMCP 3.2.0; 3.3+ release notes have not been reviewed. A future `uv lock --upgrade`
could pull an untested 3.x minor. Mitigations if confidence matters more than
ergonomics: (a) tighten to `>=3.2,<3.3` and bump explicitly on each minor, or
(b) add a scheduled `uv sync` CI job that installs from pyproject weekly and runs
the test suite. Current decision: accept the `<4` bound; treat any 3.x upgrade as a
separate review event rather than automatic.

## Impact

- [x] Pyproject updated: `memory-server/pyproject.toml:7` — `fastmcp>=3.2,<4`
- [x] CLAUDE.md updated: stack table row + Recent Changes + Active Technologies lines
- [x] Plan Technical Context lines in 003/005/006/007/008 plan.md files updated to "FastMCP 3.2+" (002 is the baseline and remains as shipped)
- [x] No new ADR — 3.x surface unchanged for our usage per release notes
