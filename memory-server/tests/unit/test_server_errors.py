"""Unit tests for _embed_error, _ensure_init retry, summary_only bypass, and config error.

Phases covered:
  T003  — _embed_error raises ToolError with correct category prefix
  T003b — _ensure_init stays False on failure, retries on recovery (LOG-035)
  T009  — summary_only=True never calls _embed_text or _ensure_init (LOG-038)
  T015  — invalid OLLAMA_BASE_URL raises EMBEDDING_CONFIG_ERROR (FR-009)
"""
from __future__ import annotations

import pytest
from pathlib import Path
from unittest.mock import patch, MagicMock


# ---------------------------------------------------------------------------
# T003: _embed_error helper
# ---------------------------------------------------------------------------

class TestEmbedError:
    """T003: _embed_error raises ToolError with correct category prefix per exception type."""

    def test_connection_error_raises_embedding_unavailable(self):
        from fastmcp.exceptions import ToolError
        from speckit_memory.server import _embed_error

        with pytest.raises(ToolError) as exc_info:
            raise _embed_error(ConnectionError("refused"), "nomic-embed-text")
        assert "EMBEDDING_UNAVAILABLE" in str(exc_info.value)

    def test_os_error_raises_embedding_unavailable(self):
        from fastmcp.exceptions import ToolError
        from speckit_memory.server import _embed_error

        with pytest.raises(ToolError) as exc_info:
            raise _embed_error(OSError("no route to host"), "nomic-embed-text")
        assert "EMBEDDING_UNAVAILABLE" in str(exc_info.value)

    def test_httpx_timeout_raises_embedding_unavailable(self):
        import httpx
        from fastmcp.exceptions import ToolError
        from speckit_memory.server import _embed_error

        with pytest.raises(ToolError) as exc_info:
            raise _embed_error(httpx.TimeoutException("timed out"), "nomic-embed-text")
        assert "EMBEDDING_UNAVAILABLE" in str(exc_info.value)

    def test_httpx_read_error_raises_embedding_unavailable(self):
        """httpx.ReadError (TransportError subclass) must produce EMBEDDING_UNAVAILABLE (S-01)."""
        import httpx
        from fastmcp.exceptions import ToolError
        from speckit_memory.server import _embed_error

        with pytest.raises(ToolError) as exc_info:
            raise _embed_error(httpx.ReadError("mid-response failure"), "nomic-embed-text")
        assert "EMBEDDING_UNAVAILABLE" in str(exc_info.value)

    def test_response_error_404_raises_embedding_model_error(self):
        import ollama as ollama_sdk
        from fastmcp.exceptions import ToolError
        from speckit_memory.server import _embed_error

        exc = ollama_sdk.ResponseError("model not found", 404)
        with pytest.raises(ToolError) as exc_info:
            raise _embed_error(exc, "nomic-embed-text")
        assert "EMBEDDING_MODEL_ERROR" in str(exc_info.value)

    def test_response_error_non_404_raises_embedding_unavailable(self):
        import ollama as ollama_sdk
        from fastmcp.exceptions import ToolError
        from speckit_memory.server import _embed_error

        exc = ollama_sdk.ResponseError("server error", 500)
        with pytest.raises(ToolError) as exc_info:
            raise _embed_error(exc, "nomic-embed-text")
        assert "EMBEDDING_UNAVAILABLE" in str(exc_info.value)

    def test_error_message_contains_model_name_on_404(self):
        import ollama as ollama_sdk
        from fastmcp.exceptions import ToolError
        from speckit_memory.server import _embed_error

        exc = ollama_sdk.ResponseError("not found", 404)
        with pytest.raises(ToolError) as exc_info:
            raise _embed_error(exc, "my-custom-model")
        assert "my-custom-model" in str(exc_info.value)

    def test_error_message_contains_hint(self):
        from fastmcp.exceptions import ToolError
        from speckit_memory.server import _embed_error

        with pytest.raises(ToolError) as exc_info:
            raise _embed_error(ConnectionError("refused"), "nomic-embed-text")
        assert "Hint:" in str(exc_info.value)


# ---------------------------------------------------------------------------
# T003b: _ensure_init retry-on-recovery (LOG-035)
# ---------------------------------------------------------------------------

class TestEnsureInitRetry:
    """T003b: _ensure_init must NOT set _first_call_done=True on failure, and must
    retry on next call (resolves LOG-035)."""

    def test_flag_stays_false_when_run_sync_raises(self):
        """_first_call_done must remain False when _ensure_init's run_sync fails."""
        import speckit_memory.server as srv

        original_flag = srv._first_call_done
        srv._first_call_done = False
        try:
            with patch("speckit_memory.server.run_sync", side_effect=ConnectionError("down")), \
                 patch("speckit_memory.server._index_dir", return_value=Path("/tmp/fake")), \
                 patch.object(Path, "mkdir"):
                srv._ensure_init()

            assert srv._first_call_done is False, (
                "_first_call_done must stay False when _ensure_init fails (LOG-035)"
            )
        finally:
            srv._first_call_done = original_flag

    def test_retries_after_failure(self):
        """_ensure_init retries and sets flag on second call after first call fails."""
        import speckit_memory.server as srv

        original_flag = srv._first_call_done
        srv._first_call_done = False
        call_count = [0]

        def conditional_sync(**kwargs):
            call_count[0] += 1
            if call_count[0] == 1:
                raise ConnectionError("First call fails")
            return {"indexed": 0, "skipped": 0, "deleted": 0, "duration_ms": 0, "model": "nm"}

        try:
            with patch("speckit_memory.server.run_sync", side_effect=conditional_sync), \
                 patch("speckit_memory.server._index_dir", return_value=Path("/tmp/fake")), \
                 patch.object(Path, "mkdir"):
                srv._ensure_init()
                assert srv._first_call_done is False, "Flag must stay False after first failure"

                srv._ensure_init()
                assert srv._first_call_done is True, "Flag must be True after successful retry"
        finally:
            srv._first_call_done = original_flag


# ---------------------------------------------------------------------------
# T009: summary_only bypass (LOG-038)
# ---------------------------------------------------------------------------

class TestSummaryOnlyBypass:
    """T009: summary_only=True must bypass _embed_text and _ensure_init entirely."""

    @pytest.fixture
    def tmp_index(self, tmp_path):
        idx = tmp_path / ".index"
        idx.mkdir()
        return idx

    def test_summary_only_never_calls_embed_text(self, tmp_index):
        """memory_recall(summary_only=True) must not call _embed_text even with Ollama down."""
        from speckit_memory.server import memory_recall

        embed_called = []

        def bad_embed(text):
            embed_called.append(text)
            raise ConnectionError("Ollama down")

        with patch("speckit_memory.server._embed_text", side_effect=bad_embed), \
             patch("speckit_memory.server._index_dir", return_value=tmp_index):
            result = memory_recall(query="test", summary_only=True)

        assert embed_called == [], "summary_only=True must never call _embed_text"
        assert "results" in result

    def test_summary_only_never_calls_ensure_init(self, tmp_index):
        """memory_recall(summary_only=True) must not call _ensure_init (LOG-038)."""
        from speckit_memory.server import memory_recall

        ensure_init_called = []

        def mock_ensure_init():
            ensure_init_called.append(True)

        with patch("speckit_memory.server._ensure_init", side_effect=mock_ensure_init), \
             patch("speckit_memory.server._index_dir", return_value=tmp_index):
            memory_recall(query="test", summary_only=True)

        assert ensure_init_called == [], "summary_only=True must not call _ensure_init (LOG-038)"

    def test_semantic_recall_with_ollama_down_raises_tool_error(self, tmp_index):
        """memory_recall in semantic mode with Ollama down raises ToolError (ADR-033)."""
        from fastmcp.exceptions import ToolError
        from speckit_memory.server import memory_recall

        def bad_embed(text):
            raise ConnectionError("Ollama down")

        with patch("speckit_memory.server._embed_text", side_effect=bad_embed), \
             patch("speckit_memory.server._index_dir", return_value=tmp_index), \
             patch("speckit_memory.server._first_call_done", True):
            with pytest.raises(ToolError, match="EMBEDDING_UNAVAILABLE"):
                memory_recall(query="test")

    def test_read_error_caught_by_memory_recall(self, tmp_index):
        """httpx.ReadError (TransportError subclass not caught before S-01) raises ToolError (S-01)."""
        import httpx
        from fastmcp.exceptions import ToolError
        from speckit_memory.server import memory_recall

        def bad_embed(text):
            raise httpx.ReadError("mid-response failure")

        with patch("speckit_memory.server._embed_text", side_effect=bad_embed), \
             patch("speckit_memory.server._index_dir", return_value=tmp_index), \
             patch("speckit_memory.server._first_call_done", True):
            with pytest.raises(ToolError, match="EMBEDDING_UNAVAILABLE"):
                memory_recall(query="test")


# ---------------------------------------------------------------------------
# T015: EMBEDDING_CONFIG_ERROR for invalid OLLAMA_BASE_URL (FR-009)
# ---------------------------------------------------------------------------

class TestEmbeddingConfigError:
    """T015: _embed_text raises ToolError EMBEDDING_CONFIG_ERROR for non-HTTP/HTTPS URL."""

    def test_ftp_url_raises_config_error(self):
        from fastmcp.exceptions import ToolError
        import speckit_memory.server as srv

        with patch("speckit_memory.server._OLLAMA_BASE_URL", "ftp://bad"):
            with pytest.raises(ToolError, match="EMBEDDING_CONFIG_ERROR"):
                srv._embed_text("any text")

    def test_empty_scheme_raises_config_error(self):
        from fastmcp.exceptions import ToolError
        import speckit_memory.server as srv

        with patch("speckit_memory.server._OLLAMA_BASE_URL", "not-a-url"):
            with pytest.raises(ToolError, match="EMBEDDING_CONFIG_ERROR"):
                srv._embed_text("any text")

    def test_http_url_does_not_raise_config_error(self):
        """Valid http:// URL must NOT raise EMBEDDING_CONFIG_ERROR (may raise other errors)."""
        from fastmcp.exceptions import ToolError
        import speckit_memory.server as srv

        mock_client = MagicMock()
        mock_client.embed.return_value = {"embeddings": [[0.0] * 768]}

        with patch("speckit_memory.server._OLLAMA_BASE_URL", "http://localhost:11434"), \
             patch("ollama.Client", return_value=mock_client):
            try:
                srv._embed_text("any text")
            except ToolError as e:
                assert "EMBEDDING_CONFIG_ERROR" not in str(e), (
                    "http:// URL must not trigger EMBEDDING_CONFIG_ERROR"
                )
