"""Manifest diff + file crawl + embed + chunking logic."""
from __future__ import annotations

import re
from pathlib import Path
from typing import Any


# ~6000 chars ≈ 1500 tokens (4 chars/token heuristic)
MAX_CHUNK_CHARS = 6000
MIN_CHUNK_CHARS = 50


def _strip_frontmatter(text: str) -> tuple[str, dict[str, str]]:
    """Remove YAML frontmatter (---...---) from the start of a markdown file.

    Returns (body_text, frontmatter_kv_dict).
    """
    if not text.startswith("---"):
        return text, {}
    end = text.find("\n---", 3)
    if end == -1:
        return text, {}
    fm_block = text[3:end].strip()
    body = text[end + 4:].lstrip("\n")
    kv: dict[str, str] = {}
    for line in fm_block.splitlines():
        if ":" in line:
            k, _, v = line.partition(":")
            kv[k.strip()] = v.strip()
    return body, kv


def _split_at_paragraphs(text: str, max_chars: int, heading_prefix: str) -> list[str]:
    """Split long text at paragraph boundaries, attaching heading prefix to continuations."""
    parts: list[str] = []
    current = ""
    for para in re.split(r"\n\n+", text):
        candidate = (current + "\n\n" + para).strip() if current else para
        if len(candidate) <= max_chars:
            current = candidate
        else:
            if current:
                parts.append(current)
            # para itself may be oversized — hard-cut as last resort
            while len(para) > max_chars:
                parts.append(para[:max_chars])
                para = para[max_chars:]
            current = para
    if current:
        parts.append(current)
    return parts


def chunk_markdown(filename: str, text: str) -> list[dict[str, Any]]:
    """Split markdown into chunks according to the data-model chunking rules.

    Args:
        filename: The source filename (used as section label when no headings).
        text: Raw markdown content.

    Returns:
        List of chunk dicts with keys: content, section, source_file.
    """
    body, _fm = _strip_frontmatter(text)
    stem = Path(filename).stem  # filename without extension

    # Split into (heading, content) pairs using H1/H2 as boundaries
    heading_pattern = re.compile(r"^(#{1,2})\s+(.+)$", re.MULTILINE)
    matches = list(heading_pattern.finditer(body))

    raw_sections: list[tuple[str, str]] = []  # (heading_label, body_text)

    if not matches:
        # No headings — whole file is one logical section
        raw_sections.append((stem, body.strip()))
    else:
        # Text before first heading (if any)
        preamble = body[: matches[0].start()].strip()
        if preamble:
            raw_sections.append((stem, preamble))
        for i, m in enumerate(matches):
            level = len(m.group(1))
            if level > 2:
                continue  # only H1/H2 are split boundaries
            heading_label = m.group(2).strip()
            start = m.end()
            end = matches[i + 1].start() if i + 1 < len(matches) else len(body)
            section_body = body[start:end].strip()
            raw_sections.append((heading_label, section_body))

    # Apply min-size merge and max-size split
    chunks: list[dict[str, Any]] = []
    pending_heading: str | None = None
    pending_body: str | None = None

    def flush(heading: str, content: str) -> None:
        parts = _split_at_paragraphs(content, MAX_CHUNK_CHARS, heading)
        if not parts:
            return
        for idx, part in enumerate(parts):
            section_label = heading if idx == 0 else f"{heading} (continued)"
            chunks.append({
                "content": part,
                "section": section_label,
                "source_file": filename,
            })

    for heading, content in raw_sections:
        if not content:
            # Empty section — skip
            continue
        if len(content) < MIN_CHUNK_CHARS:
            # Too short — merge into next
            if pending_heading is not None:
                # Accumulate into current pending
                pending_body = (pending_body + "\n\n" + content).strip()
            else:
                pending_heading = heading
                pending_body = content
            continue

        if pending_heading is not None:
            # Short section merges INTO this section — use this section's heading
            combined = (pending_body + "\n\n" + content).strip()
            flush(heading, combined)
            pending_heading = None
            pending_body = None
        else:
            flush(heading, content)

    if pending_heading is not None and pending_body:
        flush(pending_heading, pending_body)

    return chunks
