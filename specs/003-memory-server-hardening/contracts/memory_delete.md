# Contract: `memory_delete` Tool (Feature 003)

**Tool**: `memory_delete`
**Server**: `speckit-memory` (FastMCP)
**Changed by**: Feature 003 (003-memory-server-hardening)

---

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `source_file` | `str \| None` | `None` | Delete all chunks for this source_file |
| `id` | `str \| None` | `None` | Delete exactly one chunk by UUID |

Exactly one of `source_file` or `id` must be provided.

---

## Delete Guard (NEW — Feature 003)

When `source_file` is provided, `memory_delete` validates it against the local filesystem
**before** executing the delete:

**Rule**: If `Path(_repo_root() / source_file).exists()` is True, reject the delete.

```json
{
  "error": {
    "code": "PROTECTED_SOURCE_FILE",
    "message": "source_file '.specify/memory/ADR_008_lancedb-vector-backend.md' is present on disk and managed by memory_sync. Use memory_sync to re-index, or delete by chunk id.",
    "recoverable": true
  }
}
```

### Guard scope

| Scenario | Guard fires? |
|---|---|
| `source_file` resolves to an existing on-disk path | Yes → reject |
| `source_file` is an orphaned path (file deleted from disk) | No → delete proceeds |
| `source_file` is `"synthetic"` | No → `"synthetic"` does not exist on disk |
| `id` is provided (id-based delete) | No → id-based deletes are not affected |

### Path resolution

Uses `_repo_root() / source_file` — the same anchor used by `memory_store` (ADR-023). Consistent
path resolution ensures the same `source_file` string maps identically in both guards.

---

## Success Responses (unchanged)

**Source-file delete**:
```json
{"deleted_chunks": 3, "source_file": ".specify/memory/ADR_008_lancedb-vector-backend.md"}
```

**Id delete**:
```json
{"deleted_chunks": 1, "id": "uuid-string"}
```

---

## Error Responses

| Code | When | Recoverable |
|---|---|---|
| `INVALID_INPUT` | Both or neither of `source_file`/`id` provided | Yes |
| `INVALID_INPUT` | `id` is not a valid UUID | Yes |
| `PROTECTED_SOURCE_FILE` | `source_file` resolves to an existing on-disk path | Yes — use id-based delete for synthetic chunks; use `memory_sync` for file-synced chunks |
