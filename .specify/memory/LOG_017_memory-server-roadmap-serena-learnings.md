# LOG-017: Memory Server Roadmap — Serena Learnings & Open Gaps

**Date**: 2026-04-09
**Type**: OPEN QUESTION / FUTURE WORK
**Status**: Open
**Raised In**: Serena (github.com/oraios/serena) comparative analysis, post-002 implementation
**Related ADRs**: ADR-008 (LanceDB), ADR-010 (embedding model), ADR-011 (self-init sync)

---

## Context

After completing feature 002 (vector memory MCP server), we compared our approach against Serena — an LSP-backed MCP coding agent with a simpler file-based memory system. Serena's memory (named Markdown files, LLM-routed by filename) is architecturally different and not a replacement for our embedding approach. However, the comparison surfaced concrete gaps and design patterns worth addressing in future features.

---

## Known Gaps in 002 Implementation

### GAP-1: No fallback when Ollama is unavailable

`memory_recall` returns `API_UNAVAILABLE` (recoverable: true) when Ollama is unreachable. There is no degraded-mode fallback. A session without Ollama running gets a broken tool.

**Options**: BM25 keyword search over chunk content, or substring match on section/source_file. Either would be better than an error.

**Priority**: High — affects any environment where Ollama isn't pre-started.

---

### GAP-2: min_score=0.5 is empirically unvalidated

The 0.5 similarity threshold was chosen conservatively with no data. We don't know if it's excluding good results or passing noise. The right value likely depends on the corpus and query patterns speckit skills actually use.

**Action**: Run a calibration pass — issue 5-10 representative queries against a real indexed corpus, inspect scores at different thresholds, set a value based on actual distribution.

**Priority**: Medium — affects recall quality but not correctness.

---

### GAP-3: No token budget control in memory_recall

`memory_recall` returns up to `top_k * MAX_CHUNK_CHARS` characters (~30k chars at defaults) with no way for the caller to cap total output. Callers have no visibility into token cost.

**Options**:
- Add `max_chars` parameter to `memory_recall` — truncates results envelope to budget
- Add `token_count` field to response envelope (using tiktoken) so callers can observe cost
- Both

**Priority**: Medium — important for agentic callers that manage their own context budget.

---

## Serena Learnings Worth Adopting

### LEARN-1: Progressive degradation on large results

Serena's `shortened_result_factories` pattern: when results exceed a size limit, fall back through tiers — full content → section headings only → source file list only. We return all or nothing.

**Application**: `memory_recall` could add a `degradation` field in the response indicating whether results were truncated, plus a `summary_only` mode that returns `{source_file, section, score}` without full content — lets callers do two-pass retrieval (list → selective fetch).

---

### LEARN-2: Token observability per tool call

Serena uses `tiktoken` to record actual token cost per tool call as analytics. We have zero observability on what `memory_recall` actually costs downstream.

**Application**: Return a `token_estimate` in the response envelope. Cheap to add (tiktoken is fast), useful for callers tuning `top_k` and `max_chars`.

---

### LEARN-3: Session handoff convention

Serena's `PrepareForNewConversationTool` explicitly generates context handoff notes before ending a session. We have `memory_store` but no convention for when or how skills should summarize state before a session ends.

**Application**: Add a `/speckit.handoff` skill (or extend `/speckit.retro`) that writes a synthetic chunk summarizing the current session's key decisions and open questions — a durable "where we left off" record for async, multi-project workflows.

---

### LEARN-4: Read-only protection for real ADRs

Serena's `read_only_memory_patterns` prevents agent tools from overwriting protected files. Currently nothing prevents a skill from calling `memory_store` with `source_file=".specify/memory/ADR_010_..."` and overwriting a real ADR's chunk representation, or `memory_delete` removing it.

**Application**: In `memory_store`, reject writes where `source_file` matches an existing on-disk path (those files are managed by `memory_sync`, not by agents). Only allow writes where `source_file` is `"synthetic"` or a non-existent path. Add this as a validation rule in the contract spec.

---

### LEARN-5: Global vs. project-scoped memory (future)

Serena has a `global/` prefix for cross-project memories. All our memory is project-local. For speckit as a reusable template, cross-project learnings (review patterns that worked, useful calibration notes) could be valuable.

**Application**: Low priority — no multi-project use case yet. Worth revisiting if speckit is deployed across multiple repos.

---

## What We're NOT Adopting (and Why)

- **Serena's file-based memory**: Doesn't support semantic query-by-content. Degrades at 50+ docs due to filename list in system prompt. Our embedding approach is the right architecture for the recall-before convention in speckit skills.
- **LSP symbol tools**: Serena's core value. Different domain — code editing, not spec/ADR retrieval. Worth tracking as a future "code agent" feature if this project evolves in that direction.

---

## Suggested Feature Numbers

These learnings are candidates for future features or sub-tasks appended to 002:

| Item | Scope | Suggested slot |
|------|-------|----------------|
| GAP-1: Ollama fallback | memory-server | 002b or 003 |
| GAP-2: min_score calibration | ops/tuning | 002b |
| GAP-3: max_chars + token_estimate | memory-server | 003 |
| LEARN-1: Progressive degradation | memory-server | 003 |
| LEARN-2: Token observability | memory-server | 003 |
| LEARN-3: Session handoff skill | speckit skills | 004 |
| LEARN-4: Read-only ADR protection | memory-server | 003 |
| LEARN-5: Global memory scope | future | 005+ |
