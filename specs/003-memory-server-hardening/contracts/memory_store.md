# Contract: `memory_store` Tool (Feature 003)

**Tool**: `memory_store`
**Server**: `speckit-memory` (FastMCP)
**Changed by**: Feature 003 (003-memory-server-hardening)

---

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `content` | `str` | *(required)* | Text content to embed and store |
| `metadata` | `dict` | *(required)* | Chunk metadata |

### `metadata` fields

| Key | Type | Required | Description |
|---|---|---|---|
| `source_file` | `str` | Yes | **MUST be `"synthetic"`** — write guard enforced |
| `section` | `str` | No | Document section label |
| `type` | `str` | No | Content type tag |
| `feature` | `str` | No | Feature branch |
| `date` | `str` | No | ISO date string |
| `tags` | `list[str]` | No | Search tags |

---

## Write Guard (NEW — Feature 003)

Before embedding or writing, `memory_store` validates `metadata.source_file`:

**Rule**: `source_file` MUST equal exactly `"synthetic"`.

Any other value → reject:

```json
{
  "error": {
    "code": "INVALID_SOURCE_FILE",
    "message": "source_file must be 'synthetic'. Real file chunks are managed by memory_sync only.",
    "recoverable": true
  }
}
```

### What changed from Feature 002

Feature 002 implemented a filesystem-existence check: if `source_file` did not exist on disk,
the chunk was silently marked `synthetic=True` and stored. Feature 003 replaces this with a
strict whitelist: **only `"synthetic"` is accepted, regardless of whether the path exists on disk**.

This closes the bypass vector where a future path (not yet on disk) could be passed as
`source_file`, creating a chunk that would collide with a real file after the next `memory_sync`.

---

## Success Response (unchanged)

```json
{
  "id": "uuid-string",
  "status": "stored"
}
```

---

## Error Responses

| Code | When | Recoverable |
|---|---|---|
| `INVALID_SOURCE_FILE` | `source_file != "synthetic"` | Yes — caller should set `source_file: "synthetic"` |
| `API_UNAVAILABLE` | Ollama embedding service unreachable | Yes — retry after Ollama is running |
