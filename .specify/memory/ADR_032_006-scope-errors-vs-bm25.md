# ADR-032: Feature 006 Scope — Structured Errors Only, BM25 Deferred to 007

**Date**: 2026-04-14
**Status**: Accepted
**Decision Made In**: specs/006-ollama-fallback/spec.md (post-review revision)
**Related Logs**: None

---

## Context

The roadmap entry for feature 006 described "a BM25/keyword fallback over chunk content" — meaning `memory_recall` would fall back to full-text keyword search when Ollama is unavailable, so the tool continues returning results (at reduced precision) rather than failing.

The initial spec for 006 was written to deliver structured error responses instead: when Ollama is down, tool calls return `{ code, message, hint }` rather than crashing. The spec's Assumption #1 excluded BM25 by characterizing it as "an alternative embedding provider," which is incorrect — BM25 is a text search algorithm that requires no embeddings at all. This was identified during adversarial spec review as a straw-man exclusion.

The distinction matters because the two approaches have different user outcomes:
- **Structured errors**: the tool fails politely with a helpful message
- **BM25 fallback**: the tool continues functioning at reduced quality

## Decision

Feature 006 delivers structured errors, timeouts, and graceful degradation for operations that don't need embedding. BM25/keyword search fallback is deferred to feature 007. This is a deliberate scope reduction from the original roadmap intent.

## Alternatives Considered

### Option A: Structured errors only (006), BM25 in 007 *(chosen)*

Feature 006 fixes the crash/hang failure mode. Feature 007 adds keyword search so recall actually works offline.

**Pros**: Smaller, independently deliverable; error handling is a prerequisite for BM25 anyway; stays under 300 LOC PR limit
**Cons**: Roadmap promise of "tool works offline" delayed by one feature; recall still returns nothing when Ollama is down

### Option B: Include BM25 in 006

**Pros**: Delivers the original roadmap promise in one feature; tool works offline after 006 ships
**Cons**: Significantly larger scope (~150+ additional LOC estimate); couples two independent problems (error handling + search strategy); likely exceeds 300 LOC PR limit

### Option C: Structured errors only, close 006, never build BM25

**Pros**: Simplest
**Cons**: Roadmap promise never delivered; recall still fails when Ollama is down

## Rationale

Option A was chosen because error handling (timeouts, structured responses, manifest atomicity) is a prerequisite for BM25 fallback anyway — BM25 needs a clean error path to fall back *to*. Splitting the work keeps each PR under the 300 LOC limit and makes each feature independently testable. Option C was rejected because the roadmap intent (tool works offline) is worth preserving.

## Consequences

**Positive**: 006 is scoped to a single concern; ships faster; each feature independently mergeable
**Negative / Trade-offs**: `memory_recall` in semantic mode still returns nothing useful when Ollama is down until 007 ships
**Risks**: 007 may get deprioritized and BM25 never ships — in which case this was Option C by another name
**Follow-on decisions required**: ADR-033 (MCP error channel); feature 007 scoping

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-14 | Initial record | Claude (post-review revision) |
