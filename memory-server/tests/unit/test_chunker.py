"""Unit tests for the heading-aware chunking algorithm."""
import pytest
from speckit_memory.sync import chunk_markdown

# Padding to ensure sections exceed the 50-char minimum
PAD = "This is sufficient body content for the section. " * 2  # ~100 chars


def test_h1_h2_split_produces_separate_chunks():
    """H1 and H2 headings each create new chunk boundaries."""
    md = f"# Section A\n\n{PAD}\n\n## Subsection B\n\n{PAD}\n\n# Section C\n\n{PAD}"
    chunks = chunk_markdown("test.md", md)
    sections = [c["section"] for c in chunks]
    assert "Section A" in sections
    assert "Subsection B" in sections
    assert "Section C" in sections
    assert len(chunks) == 3


def test_max_chunk_size_continuation_prefix():
    """A section exceeding 6000 chars is split with a continuation prefix."""
    long_para = "word " * 1500  # ~7500 chars
    md = f"# Big Section\n\n{long_para}"
    chunks = chunk_markdown("test.md", md)
    assert len(chunks) >= 2
    continuation = [c for c in chunks if "(continued)" in c["section"]]
    assert len(continuation) >= 1
    assert continuation[0]["section"].startswith("Big Section")


def test_min_size_section_merged_into_following():
    """A section with fewer than 50 chars is merged into the next section."""
    # "Hi." is 3 chars — below min. Should be merged into the following section.
    md = f"# Short\n\nHi.\n\n## Real Content\n\n{PAD}"
    chunks = chunk_markdown("test.md", md)
    # "Short" heading content should not appear as its own chunk
    sections = [c["section"] for c in chunks]
    assert "Short" not in sections
    assert len(chunks) == 1  # merged into one chunk


def test_no_headings_produces_single_chunk():
    """A file with no headings produces exactly one chunk."""
    md = f"This is a paragraph.\n\n{PAD}"
    chunks = chunk_markdown("myfile.md", md)
    assert len(chunks) == 1
    assert chunks[0]["section"] == "myfile"  # filename without extension


def test_yaml_frontmatter_excluded_from_chunk_content():
    """YAML frontmatter between --- delimiters is stripped from chunk content."""
    md = f"---\ntitle: My ADR\ndate: 2026-04-06\n---\n\n# Decision\n\n{PAD}"
    chunks = chunk_markdown("adr.md", md)
    for chunk in chunks:
        assert "title: My ADR" not in chunk["content"]
        assert "date: 2026-04-06" not in chunk["content"]
    combined = " ".join(c["content"] for c in chunks)
    assert "sufficient body content" in combined


def test_empty_section_heading_only_skipped():
    """A heading with no body content (empty section) is skipped."""
    md = f"# Real Section\n\n{PAD}\n\n# Empty\n\n# Another Real\n\n{PAD}"
    chunks = chunk_markdown("test.md", md)
    sections = [c["section"] for c in chunks]
    assert "Empty" not in sections
    assert "Real Section" in sections
    assert "Another Real" in sections
