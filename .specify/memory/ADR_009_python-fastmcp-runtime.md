# ADR-009: Python + FastMCP as the MCP Server Runtime

**Date**: 2026-04-06
**Status**: Accepted
**Decision Made In**: specs/002-vector-memory-mcp/plan.md § Phase 0 Research
**Related Logs**: None

---

## Context

The memory MCP server needs an implementation language and MCP framework. Two paths were considered: TypeScript/Node (aligned with the existing `@modelcontextprotocol/server-memory` reference implementation) and Python (aligned with the vector DB and embedding model ecosystem). The project has no prior language lock-in — it is a template repo of markdown and shell scripts.

## Decision

We will implement the MCP server in Python using FastMCP because the embedding model and vector DB ecosystems are Python-first, and FastMCP provides a decorator-based abstraction that eliminates boilerplate.

## Alternatives Considered

### Option A: Python + FastMCP *(chosen)*

FastMCP is a high-level Python wrapper over the MCP SDK that reduces server definition to annotated functions. Deployable via `uvx` with zero install friction.

**Pros**: LanceDB Python SDK is production-ready; all major embedding libraries (Ollama, sentence-transformers, OpenAI) are Python-first; FastMCP eliminates boilerplate; `uvx` deployment matches `npx` convenience
**Cons**: Python startup overhead (~100ms); requires Python 3.10+ on developer machine

### Option B: TypeScript + MCP SDK

The reference `@modelcontextprotocol/server-memory` is TypeScript. LanceDB has a JS SDK.

**Pros**: More MCP examples online; Node.js already common on dev machines; `npx` deployment
**Cons**: LanceDB JS SDK is less documented than Python; embedding model libraries (sentence-transformers, Ollama bindings) are weaker in JS; would require manual embedding plumbing

## Rationale

The core operations of this server — embedding text, storing vectors, querying by similarity — are all better supported in Python. FastMCP's decorator approach keeps the implementation small, consistent with Principle II (no speculative abstractions). The 100ms startup penalty is acceptable for a tool invoked by Claude Code sessions.

**Why MCP specifically, not a direct script call**: Two load-bearing properties make MCP necessary over `python3 memory.py recall "query"`:

1. **Session-scoped state**: ADR-011 specifies that sync runs on the first tool call per process lifetime, not on every call. This requires a persistent server process that knows whether it has already synced in the current session. A stateless script call would trigger full sync on every invocation (violating FR-011's <500ms no-change requirement) or require writing session state to a temp file (more complex than the MCP process model).

2. **Structured inputs and schema validation**: Skills call `memory_recall`, `memory_store`, etc. with typed, structured arguments (JSON objects). MCP provides schema validation for free. A CLI script equivalent requires argument parsing, escaping, and no schema enforcement — skills would be doing string-building rather than structured calls.

These two properties are what justify the MCP server architecture over a simpler script approach, and should be revisited only if either property ceases to be load-bearing.

## Consequences

**Positive**: Richer embedding ecosystem; cleaner integration with LanceDB; `uvx`-deployable
**Negative / Trade-offs**: Requires Python 3.10+ on developer machine; departs from the TypeScript MCP reference ecosystem
**Risks**: Developer may not have Python installed. Mitigated by clear setup docs in `quickstart.md` and `uvx` auto-install.
**Follow-on decisions required**: ADR-010 (embedding model choice, now constrained to Python-compatible options)

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-06 | Initial record | speckit.plan |
