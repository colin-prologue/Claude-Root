"""Shared pytest fixtures for all test suites.

fake_embedder: Returns a deterministic 768-dim zero vector for any input.
Allows contract and unit tests to run without a live Ollama process.
"""
import pytest


@pytest.fixture
def fake_embedder():
    """Callable that returns a fixed 768-dim zero vector regardless of input."""
    def _embed(text: str) -> list[float]:
        return [0.0] * 768
    return _embed
