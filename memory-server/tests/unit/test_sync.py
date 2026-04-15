"""Unit tests for cleanup-pass behavior in run_sync and find_deleted.

Uses fake_embedder fixture — no Ollama required.
"""
import pytest
from pathlib import Path
from unittest.mock import patch

from speckit_memory.sync import run_sync, find_deleted


def _write_multi_heading_file(path: Path) -> None:
    """Write a markdown file with 3 H2 headings, each with enough body text to produce a chunk."""
    path.write_text(
        "# Root Heading\n\n"
        "Preamble text that forms its own section with enough content to exceed the minimum chunk size threshold.\n\n"
        "## Section A\n\n"
        "This is the first section with enough content to form an independent chunk in the indexer. "
        "It contains meaningful prose about the system design and technical decisions.\n\n"
        "## Section B\n\n"
        "This is the second section with enough content to form an independent chunk in the indexer. "
        "It contains meaningful prose about implementation details and constraints.\n\n"
        "## Section C\n\n"
        "This is the third section with enough content to form an independent chunk in the indexer. "
        "It contains meaningful prose about testing strategy and acceptance criteria.\n"
    )


@pytest.fixture
def tmp_repo_two_files(tmp_path):
    """Repo with two indexable ADR files."""
    memory_dir = tmp_path / ".specify" / "memory"
    memory_dir.mkdir(parents=True)
    adr1 = memory_dir / "ADR_001_keep.md"
    adr2 = memory_dir / "ADR_002_delete.md"
    adr1.write_text(
        "# Keep This File\n\n"
        "This ADR documents a decision that should remain in the index after a scoped sync. "
        "It contains enough text to exceed the minimum chunk size threshold.\n"
    )
    adr2.write_text(
        "# Delete This File\n\n"
        "This ADR documents a decision for a file that will be deleted from disk. "
        "Its chunks must not be removed during a scoped sync targeting the other file.\n"
    )
    index_dir = tmp_path / ".index"
    index_dir.mkdir()
    return tmp_path, index_dir, adr1, adr2


def test_scoped_sync_skips_cleanup(fake_embedder, tmp_repo_two_files):
    """FR-001a: Scoped sync must not delete chunks from files outside the scope."""
    repo_root, index_dir, adr1, adr2 = tmp_repo_two_files

    # Initial full sync — both files indexed
    run_sync(index_dir, repo_root, fake_embedder, "nomic-embed-text")

    # Delete adr2 from disk
    adr2.unlink()

    # Scoped sync targeting only adr1 (the file that still exists)
    rel_adr1 = str(adr1.relative_to(repo_root))
    result = run_sync(
        index_dir, repo_root, fake_embedder, "nomic-embed-text",
        paths=[rel_adr1],
    )

    # Scoped sync must report deleted == 0
    assert result["deleted"] == 0, (
        f"Scoped sync should not delete anything, got deleted={result['deleted']}"
    )

    # adr2's chunks must still be in the table
    from speckit_memory.index import init_table
    table = init_table(index_dir)
    rows = table.to_pandas()
    rel_adr2 = str(adr2.relative_to(repo_root))
    remaining = rows[rows["source_file"] == rel_adr2]
    assert len(remaining) > 0, "Chunks for deleted file must survive a scoped sync"


def test_deleted_count_is_chunks_not_files(fake_embedder, tmp_path):
    """FR-008: deleted count must equal number of chunks removed, not number of files."""
    memory_dir = tmp_path / ".specify" / "memory"
    memory_dir.mkdir(parents=True)
    index_dir = tmp_path / ".index"
    index_dir.mkdir()

    adr = memory_dir / "ADR_001_multi.md"
    _write_multi_heading_file(adr)

    # Sync to index the multi-chunk file
    run_sync(index_dir, tmp_path, fake_embedder, "nomic-embed-text")

    # Count how many chunks were produced
    from speckit_memory.index import init_table
    table = init_table(index_dir)
    rows = table.to_pandas()
    rel = str(adr.relative_to(tmp_path))
    chunk_count = len(rows[rows["source_file"] == rel])
    assert chunk_count > 1, f"Expected >1 chunks from multi-heading file, got {chunk_count}"

    # Delete the file and sync again
    adr.unlink()
    result = run_sync(index_dir, tmp_path, fake_embedder, "nomic-embed-text")

    assert result["deleted"] == chunk_count, (
        f"Expected deleted={chunk_count} (chunks), got deleted={result['deleted']}"
    )


def test_clean_index_reports_zero_deleted(fake_embedder, tmp_path):
    """FR-006, SC-002: Syncing with all files present reports deleted == 0."""
    memory_dir = tmp_path / ".specify" / "memory"
    memory_dir.mkdir(parents=True)
    index_dir = tmp_path / ".index"
    index_dir.mkdir()

    adr = memory_dir / "ADR_001_stable.md"
    adr.write_text(
        "# Stable Decision\n\n"
        "This file remains on disk and must not be counted as deleted on clean sync. "
        "It contains enough text to form a real chunk in the indexer.\n"
    )

    run_sync(index_dir, tmp_path, fake_embedder, "nomic-embed-text")
    result = run_sync(index_dir, tmp_path, fake_embedder, "nomic-embed-text")

    assert result["deleted"] == 0, (
        f"Clean sync must report deleted=0, got deleted={result['deleted']}"
    )


def test_idempotent_cleanup(fake_embedder, tmp_path):
    """SC-003: Second sync after deletion reports deleted == 0 (idempotent)."""
    memory_dir = tmp_path / ".specify" / "memory"
    memory_dir.mkdir(parents=True)
    index_dir = tmp_path / ".index"
    index_dir.mkdir()

    adr = memory_dir / "ADR_001_gone.md"
    adr.write_text(
        "# Gone Decision\n\n"
        "This file will be deleted and cleaned up on the first sync. "
        "The second sync must report deleted=0 since the chunks are already gone.\n"
    )

    run_sync(index_dir, tmp_path, fake_embedder, "nomic-embed-text")
    adr.unlink()

    result1 = run_sync(index_dir, tmp_path, fake_embedder, "nomic-embed-text")
    assert result1["deleted"] >= 1, "First sync after deletion should report >= 1 deleted"

    result2 = run_sync(index_dir, tmp_path, fake_embedder, "nomic-embed-text")
    assert result2["deleted"] == 0, (
        f"Second sync must be idempotent (deleted=0), got deleted={result2['deleted']}"
    )


def test_malformed_manifest_entry_skipped(fake_embedder, tmp_path):
    """Spec edge case: empty-string key and 'synthetic' key in manifest must not crash or delete."""
    memory_dir = tmp_path / ".specify" / "memory"
    memory_dir.mkdir(parents=True)
    index_dir = tmp_path / ".index"
    index_dir.mkdir()

    adr = memory_dir / "ADR_001_real.md"
    adr.write_text(
        "# Real Decision\n\n"
        "This file is real and should survive the sync. "
        "It contains enough text to form a chunk in the indexer.\n"
    )

    run_sync(index_dir, tmp_path, fake_embedder, "nomic-embed-text")

    # Inject malformed entries into the manifest
    from speckit_memory.index import load_manifest, save_manifest
    manifest = load_manifest(index_dir)
    manifest["entries"][""] = {"hash": "badhash", "chunk_ids": []}
    manifest["entries"]["synthetic"] = {"hash": "synth", "chunk_ids": []}
    save_manifest(index_dir, manifest)

    # Sync must not crash and must not delete any real chunks
    result = run_sync(index_dir, tmp_path, fake_embedder, "nomic-embed-text")
    assert result["deleted"] == 0, (
        f"Malformed manifest entries must be skipped, got deleted={result['deleted']}"
    )


def test_oserror_on_exists_skips_entry(fake_embedder, tmp_path):
    """ADR-030: if Path.exists() raises OSError during cleanup, treat file as present (skip deletion)."""
    memory_dir = tmp_path / ".specify" / "memory"
    memory_dir.mkdir(parents=True)
    index_dir = tmp_path / ".index"
    index_dir.mkdir()

    adr = memory_dir / "ADR_001_perm.md"
    adr.write_text(
        "# Permission Error\n\n"
        "This file's existence check will raise PermissionError during cleanup. "
        "Its chunks must survive — conservative rule: treat unavailable as present.\n"
    )

    run_sync(index_dir, tmp_path, fake_embedder, "nomic-embed-text")

    # Remove the file from disk so it appears as a deletion candidate
    adr.unlink()

    # Patch Path.exists to raise PermissionError when called from the cleanup loop
    original_exists = Path.exists

    def patched_exists(self):
        if self.name == "ADR_001_perm.md":
            raise PermissionError("simulated permission error")
        return original_exists(self)

    with patch.object(Path, "exists", patched_exists):
        result = run_sync(index_dir, tmp_path, fake_embedder, "nomic-embed-text")

    assert result["deleted"] == 0, (
        f"OSError during exists check must skip the entry (conservative), got deleted={result['deleted']}"
    )

    from speckit_memory.index import init_table
    table = init_table(index_dir)
    rows = table.to_pandas()
    rel = str(adr.relative_to(tmp_path))
    surviving = rows[rows["source_file"] == rel]
    assert len(surviving) > 0, "Chunks must survive when exists() raises OSError"


def test_full_and_paths_raises(fake_embedder, tmp_path):
    """S-001: full=True and paths together must raise ValueError."""
    memory_dir = tmp_path / ".specify" / "memory"
    memory_dir.mkdir(parents=True)
    index_dir = tmp_path / ".index"
    index_dir.mkdir()

    with pytest.raises(ValueError, match="full=True and paths cannot be used together"):
        run_sync(index_dir, tmp_path, fake_embedder, "nomic-embed-text",
                 full=True, paths=["some/file.md"])


class TestOllamaEmbedTimeout:
    """T002: _ollama_embed must pass the timeout value to ollama.Client."""

    def test_timeout_passed_to_client(self):
        """_ollama_embed constructs ollama.Client with the passed timeout value."""
        from unittest.mock import patch, MagicMock
        from speckit_memory.sync import _ollama_embed

        mock_client = MagicMock()
        mock_client.embed.return_value = {"embeddings": [[0.1] * 768]}

        with patch("ollama.Client", return_value=mock_client) as mock_cls:
            _ollama_embed("text", "http://localhost:11434", "nomic-embed-text", timeout=5.0)

        mock_cls.assert_called_once_with(host="http://localhost:11434", timeout=5.0)

    def test_default_timeout_is_ten(self):
        """_ollama_embed uses 10.0 as the default timeout when not specified."""
        from unittest.mock import patch, MagicMock
        from speckit_memory.sync import _ollama_embed

        mock_client = MagicMock()
        mock_client.embed.return_value = {"embeddings": [[0.1] * 768]}

        with patch("ollama.Client", return_value=mock_client) as mock_cls:
            _ollama_embed("text", "http://localhost:11434", "nomic-embed-text")

        _, kwargs = mock_cls.call_args
        assert kwargs.get("timeout") == 10.0


def test_find_deleted_filters_synthetic_entries():
    """FR-007: find_deleted must exclude 'synthetic' keys from deletion candidates."""
    manifest = {
        "entries": {
            "synthetic": {"hash": "abc", "chunk_ids": []},
            ".specify/memory/ADR_001_real.md": {"hash": "def", "chunk_ids": []},
        }
    }
    # files list contains the real file — only "synthetic" is "absent"
    repo_root = Path("/fake/root")
    files = [Path("/fake/root/.specify/memory/ADR_001_real.md")]

    result = find_deleted(manifest, files, repo_root)

    assert "synthetic" not in result, (
        f"'synthetic' key must be filtered out of deletion candidates, got: {result}"
    )
    assert result == [], f"Expected empty list, got: {result}"
