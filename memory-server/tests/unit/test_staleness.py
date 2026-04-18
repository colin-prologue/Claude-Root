"""TDD tests for staleness detection and constitution gate (feature 008).

Covers:
  T002  — _check_staleness resets _first_call_done when stale
  T003  — _check_staleness does not reset when fresh
  T004  — _check_staleness disabled when threshold is 0
  T005  — absent last_sync_ts treated as stale (pre-008 manifest)
  T006  — _check_staleness logs WARNING on exception, does not re-raise
  T007  — run_sync writes last_sync_ts float to manifest on success
  T008  — stale check + ensure_init two-call sequence
  T009  — _check_staleness called on summary_only=True path
  T010  — non-numeric MEMORY_STALENESS_THRESHOLD treated as 0 at import
  T015  — memory-convention.md contains required constitution gate documentation
"""
from __future__ import annotations

import importlib
import os
import time
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest


# ---------------------------------------------------------------------------
# T002: _check_staleness resets _first_call_done when stale
# ---------------------------------------------------------------------------

def test_check_staleness_resets_when_stale():
    """_check_staleness resets _first_call_done when index is older than threshold."""
    import speckit_memory.server as s

    stale_ts = time.time() - 7200  # 2 hours ago; threshold is 3600s
    manifest = {"version": "2", "entries": {}, "last_sync_ts": stale_ts}

    with patch("speckit_memory.server._MEMORY_STALENESS_THRESHOLD", 3600.0), \
         patch("speckit_memory.server._first_call_done", True), \
         patch("speckit_memory.server.load_manifest", return_value=manifest), \
         patch("speckit_memory.server._index_dir", return_value=MagicMock()):
        s._check_staleness()
        assert s._first_call_done is False


# ---------------------------------------------------------------------------
# T003: _check_staleness does not reset when fresh
# ---------------------------------------------------------------------------

def test_check_staleness_does_not_reset_when_fresh():
    """_check_staleness leaves _first_call_done unchanged when index is fresh."""
    import speckit_memory.server as s

    fresh_ts = time.time() - 1800  # 30 minutes ago; threshold is 3600s
    manifest = {"version": "2", "entries": {}, "last_sync_ts": fresh_ts}

    with patch("speckit_memory.server._MEMORY_STALENESS_THRESHOLD", 3600.0), \
         patch("speckit_memory.server._first_call_done", True), \
         patch("speckit_memory.server.load_manifest", return_value=manifest), \
         patch("speckit_memory.server._index_dir", return_value=MagicMock()):
        s._check_staleness()
        assert s._first_call_done is True


# ---------------------------------------------------------------------------
# T004: _check_staleness disabled when threshold is 0
# ---------------------------------------------------------------------------

def test_check_staleness_disabled_when_threshold_zero():
    """_check_staleness is a no-op when MEMORY_STALENESS_THRESHOLD is 0 (disabled)."""
    import speckit_memory.server as s

    stale_ts = time.time() - 7200  # would be stale under a non-zero threshold
    manifest = {"version": "2", "entries": {}, "last_sync_ts": stale_ts}

    with patch("speckit_memory.server._MEMORY_STALENESS_THRESHOLD", 0.0), \
         patch("speckit_memory.server._first_call_done", True), \
         patch("speckit_memory.server.load_manifest", return_value=manifest), \
         patch("speckit_memory.server._index_dir", return_value=MagicMock()):
        s._check_staleness()
        assert s._first_call_done is True


# ---------------------------------------------------------------------------
# T005: absent last_sync_ts treated as stale
# ---------------------------------------------------------------------------

def test_check_staleness_absent_ts_treated_as_stale():
    """Absent last_sync_ts (pre-008 manifest) is treated as stale — resets _first_call_done."""
    import speckit_memory.server as s

    manifest = {"version": "2", "entries": {}}  # no last_sync_ts field

    with patch("speckit_memory.server._MEMORY_STALENESS_THRESHOLD", 3600.0), \
         patch("speckit_memory.server._first_call_done", True), \
         patch("speckit_memory.server.load_manifest", return_value=manifest), \
         patch("speckit_memory.server._index_dir", return_value=MagicMock()):
        s._check_staleness()
        assert s._first_call_done is False


# ---------------------------------------------------------------------------
# T006: _check_staleness logs WARNING on exception, does not re-raise
# ---------------------------------------------------------------------------

def test_check_staleness_logs_warning_on_exception(capsys):
    """_check_staleness logs WARNING to stderr and returns without re-raising on exception."""
    import speckit_memory.server as s

    with patch("speckit_memory.server._MEMORY_STALENESS_THRESHOLD", 3600.0), \
         patch("speckit_memory.server._first_call_done", True), \
         patch("speckit_memory.server.load_manifest", side_effect=OSError("disk error")), \
         patch("speckit_memory.server._index_dir", return_value=MagicMock()):
        s._check_staleness()  # must not raise
        assert s._first_call_done is True  # unchanged — exception prevented the reset

    captured = capsys.readouterr()
    assert "[speckit-memory] WARNING: staleness check failed:" in captured.err
    assert "disk error" in captured.err


# ---------------------------------------------------------------------------
# T007: run_sync writes last_sync_ts to manifest on success
# ---------------------------------------------------------------------------

def test_run_sync_writes_last_sync_ts(tmp_path):
    """run_sync writes a last_sync_ts float field to the manifest on successful completion."""
    from speckit_memory.sync import run_sync
    from speckit_memory.index import load_manifest

    embed_fn = MagicMock(return_value=[0.1] * 768)

    before = time.time()
    run_sync(
        index_dir=tmp_path,
        repo_root=tmp_path,
        embed_fn=embed_fn,
        model_name="test-model",
        full=True,
    )
    after = time.time()

    manifest = load_manifest(tmp_path)
    assert "last_sync_ts" in manifest, "last_sync_ts missing from manifest after run_sync"
    assert isinstance(manifest["last_sync_ts"], float)
    assert before <= manifest["last_sync_ts"] <= after


# ---------------------------------------------------------------------------
# T008: stale check resets flag; subsequent _ensure_init calls run_sync
# ---------------------------------------------------------------------------

def test_stale_then_ensure_init_triggers_run_sync():
    """_check_staleness resets _first_call_done=False; subsequent _ensure_init invokes run_sync."""
    import speckit_memory.server as s

    stale_ts = time.time() - 7200
    manifest = {"version": "2", "entries": {}, "last_sync_ts": stale_ts}

    with patch("speckit_memory.server._MEMORY_STALENESS_THRESHOLD", 3600.0), \
         patch("speckit_memory.server._first_call_done", True), \
         patch("speckit_memory.server.load_manifest", return_value=manifest), \
         patch("speckit_memory.server._index_dir", return_value=MagicMock()), \
         patch("speckit_memory.server.run_sync") as mock_run_sync:
        mock_run_sync.return_value = {
            "indexed": 0, "skipped": 0, "deleted": 0, "duration_ms": 0, "model": "test"
        }

        s._check_staleness()
        assert s._first_call_done is False

        s._ensure_init()
        mock_run_sync.assert_called_once()


# ---------------------------------------------------------------------------
# T009: _check_staleness called on summary_only=True path
# ---------------------------------------------------------------------------

def test_check_staleness_called_on_summary_only_path():
    """_check_staleness is called even when summary_only=True in memory_recall."""
    import speckit_memory.server as s

    with patch("speckit_memory.server._check_staleness") as mock_stale, \
         patch("speckit_memory.server._index_dir", return_value=MagicMock()), \
         patch("speckit_memory.server.init_table", return_value=MagicMock()), \
         patch("speckit_memory.server.scan_chunks", return_value=[]):
        s.memory_recall(query="test", summary_only=True)
        mock_stale.assert_called_once()


# ---------------------------------------------------------------------------
# T010: non-numeric MEMORY_STALENESS_THRESHOLD treated as 0 at import
# ---------------------------------------------------------------------------

def test_invalid_staleness_threshold_treated_as_zero():
    """Non-numeric MEMORY_STALENESS_THRESHOLD does not raise at import; treated as 0 (disabled)."""
    import speckit_memory.server as s

    orig_env = os.environ.get("MEMORY_STALENESS_THRESHOLD")
    try:
        os.environ["MEMORY_STALENESS_THRESHOLD"] = "not-a-number"
        importlib.reload(s)
        assert s._MEMORY_STALENESS_THRESHOLD == 0.0
    finally:
        if orig_env is None:
            os.environ.pop("MEMORY_STALENESS_THRESHOLD", None)
        else:
            os.environ["MEMORY_STALENESS_THRESHOLD"] = orig_env
        importlib.reload(s)  # restore module to default state


# ---------------------------------------------------------------------------
# T015: memory-convention.md contains required constitution gate documentation
# ---------------------------------------------------------------------------

def test_memory_convention_has_constitution_gate():
    """memory-convention.md contains required constitution gate documentation (FR-008, FR-009, FR-011)."""
    convention_path = Path(__file__).parents[3] / ".claude" / "rules" / "memory-convention.md"
    content = convention_path.read_text(encoding="utf-8")

    assert "Constitution gate" in content, \
        "Constitution gate section missing (FR-008)"
    assert "memory_enabled" in content, \
        "memory_enabled field name not documented (FR-008)"
    assert "absent" in content, \
        "absent-field default-to-true behavior not documented (FR-009)"
    assert "unparseable" in content, \
        "unparseable constitution fallback not documented (FR-011)"
