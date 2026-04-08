# ADR-010: Ollama nomic-embed-text as the Embedding Model

**Date**: 2026-04-06
**Status**: Accepted (amended 2026-04-06 — see Amendment History)
**Decision Made In**: specs/002-vector-memory-mcp/plan.md § Phase 0 Research
**Related Logs**: None

---

## Context

The memory server must convert markdown text to embedding vectors. The spec requires the embedding model to be configurable (FR-010) and the system to be usable without cloud API accounts. The project is used by a solo developer who already has a Claude subscription — adding separate API accounts for embedding services increases friction and cost without a clear benefit.

During plan review, Voyage AI was the original default (Anthropic-invested, free tier). This was amended when it became clear that Voyage AI is a separate external service requiring a separate account, contradicting the goal of "no setup beyond what the developer already has."

## Decision

We will use Ollama `nomic-embed-text` as the single embedding backend. No cloud embedding API is used. Voyage AI is removed from scope.

## Alternatives Considered

### Option A: Ollama `nomic-embed-text` *(chosen)*

Local model run via Ollama. 768 dimensions. Free, offline-capable, global system install (once per machine).

**Pros**: No API account; fully offline; no per-repo install; `~/.ollama/` model cache is global; no Python package bloat (only a small `ollama` HTTP client package needed); nomic-embed-text is purpose-built for retrieval tasks
**Cons**: Requires `brew install ollama` + `ollama pull nomic-embed-text` (~300MB, one-time per machine); MCP server calls Ollama HTTP API, so `ollama serve` must be running when Claude Code is open

### Option B: sentence-transformers (local Python)

Pure Python library, models cached in `~/.cache/huggingface/`. In-process — no server required.

**Pros**: Always available once installed; no external server process
**Cons**: Adds `torch` + `transformers` as Python dependencies (~1GB install); lower embedding quality than nomic-embed-text for retrieval tasks; heavier than Ollama from a package perspective

### Option C: Voyage AI `voyage-3` (original default)

API-based, Anthropic-invested. Rejected because it requires a separate account and API key outside the developer's existing Claude subscription.

### Option D: BM25 keyword search

Zero setup, pure Python. Rejected for the core use case — BM25 misses cross-vocabulary queries ("what decisions affect error handling?" when the ADR uses different terminology). The core value of semantic memory is precisely the cross-vocabulary case.

## Rationale

A solo developer with a Claude subscription should not need to create additional accounts to use a memory feature built on top of Claude Code. Ollama is a global machine-level install — the same `ollama serve` process serves all repos. The ~300MB model download is a one-time cost. nomic-embed-text produces 768-dimension vectors well-suited for retrieval over technical markdown text.

The shift to a single backend removes the dual-detection logic, the dimension-mismatch complexity, and the `embedders/` abstraction layer entirely. With one concrete embedding implementation, the factory function is unnecessary (Principle II: no abstraction for a single caller with a single implementation). Embedding calls live directly in `sync.py`.

## Score Semantics and Similarity Threshold

nomic-embed-text vectors are L2-normalised before storage. Similarity is measured as cosine similarity (range 0–1). The `memory_recall` tool's `min_score` parameter (default 0.5) filters results below threshold. The 0.5 default is a starting point — empirical calibration against the `.specify/memory/` corpus is required as a spike task before the feature is considered production-ready.

## Consequences

**Positive**: No cloud API accounts; fully offline; simpler codebase (no embedder abstraction, no detection logic); only one vector dimension (768) simplifies schema and manifest validation
**Negative / Trade-offs**: Developer must have Ollama running when using Claude Code with memory tools; first-time setup requires model download
**Risks**: If `ollama serve` is not running when `memory_recall` is called, the tool returns `API_UNAVAILABLE` with `recoverable: true` (index intact; start Ollama and retry). This is the primary failure mode and must be documented in `memory-convention.md`.
**Follow-on decisions required**: None

## Amendment History

| Date | Change | Author |
|---|---|---|
| 2026-04-06 | Initial record: Voyage AI (default) + Ollama (fallback) | speckit.plan |
| 2026-04-06 | Replaced OpenAI with Voyage AI — OpenAI inconsistent with Claude-native stack | speckit.plan (user correction) |
| 2026-04-06 | Dropped Voyage AI entirely; Ollama is now the sole backend. Reason: Voyage AI requires a separate external account outside the developer's existing Claude subscription. Simplifies architecture: removes dual-embedder detection, dimension-mismatch complexity, and `embedders/` abstraction layer. | plan review (user decision) |
