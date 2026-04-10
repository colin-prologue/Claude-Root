# Data Model: Vector-Backed Semantic Memory

**Feature**: 002-vector-memory-mcp
**Date**: 2026-04-06

## Entities

### Chunk

The unit of storage and retrieval. One section of a markdown file, or a synthetic summary produced by a speckit command.

| Field | Type | Description | Constraints |
|---|---|---|---|
| `id` | string (UUID) | Stable identifier for dedup/delete | Auto-generated on insert |
| `content` | string | Raw text that was embedded | Non-empty |
| `vector` | float[] | Embedding vector | 768 dims (Ollama nomic-embed-text); must match manifest model and dimension |
| `source_file` | string | Repo-relative path to the source `.md` file | Non-empty; `"synthetic"` if not file-sourced |
| `section` | string | Heading under which the chunk appears | Filename if no headings present |
| `type` | enum | `adr` \| `log` \| `spec` \| `constitution` \| `synthetic` | Derived from source_file path or explicit on store |
| `feature` | string | Feature number/name (e.g., `"002-vector-memory-mcp"`) | Optional; derived from path when possible |
| `date` | string (ISO 8601) | File last-modified date or store timestamp | Required |
| `tags` | string[] | Optional freeform labels for filtered recall | May be empty |
| `synthetic` | boolean | True if chunk was stored by a command, not sourced from a file | Defaults false |

**Relationships**: A chunk belongs to one source_file (or is synthetic). Multiple chunks can share a source_file (one per heading section).

**State transitions**: Chunks are immutable once written. An update to a source file replaces all chunks for that file (delete-then-insert, keyed by `source_file`).

### Manifest

A local JSON file that tracks which files have been indexed and when, used by sync to detect stale chunks without scanning the full DB.

| Field | Type | Description |
|---|---|---|
| `version` | string | Manifest schema version (`"2"` — v1 used mtime, v2 uses content hash; v1 manifests trigger automatic full re-index on next sync) |
| `embedding_model` | string | Model identifier used to build this index (e.g., `"nomic-embed-text"`) |
| `embedding_dimension` | integer | Vector dimension of the embedding model (e.g., 768 for Ollama nomic-embed-text) |
| `similarity_metric` | string | Similarity metric used (`"cosine"` — all vectors are L2-normalised on write) |
| `entries` | map | `{ source_file: { hash: sha256hex, chunk_ids: string[] } }` — `hash` is a SHA-256 content hash of the file bytes (ADR-012) |

**Location**: `.specify/memory/.index/manifest.json` (gitignored)

**Key invariants**:
- If `manifest.embedding_model` does not match current config → `MODEL_MISMATCH` error; `memory_sync --full` required.
- If `manifest.embedding_dimension` does not match the model's declared output dimension → `MODEL_MISMATCH` error; full re-index required. This catches version changes where a model retains its name but changes dimension.
- `similarity_metric` is always `"cosine"` — vectors are L2-normalised at write time so cosine similarity = dot product at query time.

### Memory Index (LanceDB table)

The LanceDB table wrapping all Chunk records. Not directly queried by skills — accessed only through the MCP server.

| Detail | Value |
|---|---|
| Location | `.specify/memory/.index/chunks.lance/` |
| Table name | `chunks` |
| Gitignored | Yes (entire `.index/` directory) |
| Schema | Mirrors Chunk entity above |
| Index type | Brute-force for corpora <256 chunks; IVF-PQ ANN index created automatically above that threshold (ADR-013) |

## Chunking Algorithm

How `sync.py` splits a markdown file into chunks. This is a recall-quality-critical decision — chunk boundaries directly determine whether the right content is returned for a query.

### Splitting rules

1. **Heading levels**: Split on H1 (`#`) and H2 (`##`) headings. H3 and below are treated as part of the parent section (not split boundaries).
2. **Max chunk size**: 1 500 tokens (~6 000 characters). If a section exceeds this limit, split at the nearest paragraph boundary (`\n\n`) before the limit. Carry the parent heading as a prefix on the continuation chunk: `{heading} (continued)`.
3. **Min chunk size**: 50 characters. Sections below this threshold are merged with the following section. Empty sections (heading only, no body) are skipped.
4. **No headings**: The entire file is treated as a single chunk. `section` is set to the filename (without extension). Max chunk size still applies — oversized no-heading files split at paragraph boundaries with `{filename} (part N)` as the section label.
5. **Frontmatter**: YAML frontmatter (lines between `---` delimiters at the file start) is excluded from chunk content but its key-value pairs are available for tag extraction.

### Chunk identity

The combination of `(source_file, section)` uniquely identifies a chunk within an index. On re-index, all chunks for `source_file` are deleted and re-inserted — partial section updates are not supported.

### Calibration note

The `min_score` threshold for `memory_recall` (default 0.5) and the chunking boundaries above are starting points, not empirically validated values. A spike task should benchmark recall quality against the actual `.specify/memory/` corpus (ADRs, LOGs, constitution) before the feature is considered done.

**T040 calibration result (2026-04-07)**: This is a template repo with a sparse corpus (4 ADRs, no LOGs beyond planning artifacts). Calibration against this corpus is not meaningful — the repo lacks the query diversity needed for threshold validation. Recommendation: run T040 calibration in a real project repo after at least 10 ADRs and 5 LOGs are indexed. The default `min_score=0.5` remains unvalidated; `min_score=0.3` may be more appropriate for short decision-record corpora where nomic-embed-text scores tend to cluster in the 0.3–0.7 range for relevant matches.

## Validation Rules

- `source_file` must be a path under the repo root; absolute paths are rejected
- `type` must be one of the defined enum values; inferred from path prefix when not explicitly provided:
  - `ADR_*` → `adr`
  - `LOG_*` → `log`
  - `specs/*/spec.md`, `specs/*/plan.md` → `spec`
  - `constitution.md` → `constitution`
  - all others → `synthetic`
- Chunks from a deleted `source_file` are purged on next `memory_sync`
- A `synthetic` chunk with no `source_file` stores `"synthetic"` literally in that field

## Index Scope

Files indexed by default (configurable in project config):

```
.specify/memory/ADR_*.md
.specify/memory/LOG_*.md
.specify/memory/constitution.md
specs/*/spec.md
specs/*/plan.md
```

Files never indexed:
```
.specify/memory/.index/   (the index itself)
specs/*/tasks.md          (checklist state, not knowledge)
```
