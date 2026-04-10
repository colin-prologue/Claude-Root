"""Shared pytest fixtures for all test suites.

fake_embedder: Returns deterministic 768-dim unit vectors, distinct per unique
input. Allows contract and unit tests to run without a live Ollama process
while still producing meaningful cosine-similarity scores between different texts.
"""
import hashlib
import math
import pytest


@pytest.fixture
def fake_embedder():
    """Callable returning deterministic 768-dim unit vectors distinct per unique input."""
    def _embed(text: str) -> list[float]:
        # Hash the input to get a reproducible seed, spread across dimensions.
        digest = hashlib.sha256(text.encode()).digest()  # 32 bytes
        vec = [0.0] * 768
        for i, byte in enumerate(digest):
            # Map each byte's contribution to a spread of dimensions so
            # different inputs produce genuinely different unit vectors.
            base = (i * 24) % 768
            vec[base] += (byte / 128.0) - 1.0
        norm = math.sqrt(sum(v * v for v in vec))
        if norm == 0:
            vec[0] = 1.0
            return vec
        return [v / norm for v in vec]
    return _embed
