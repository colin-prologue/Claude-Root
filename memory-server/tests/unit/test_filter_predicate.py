"""Unit tests for shared filter-predicate helpers (ADR-055).

Drives the same spec dict through `_build_filter_predicate` and
`_build_filter_sql` and asserts matching pass/fail rows. Guards the two
variants against drift as new filter fields are added.
"""
from __future__ import annotations

import pytest

from speckit_memory.index import (
    _build_filter_predicate,
    _build_filter_sql,
    init_table,
    insert_chunks_batch,
)


@pytest.fixture
def tmp_index(tmp_path):
    index_dir = tmp_path / ".index"
    index_dir.mkdir()
    return index_dir


def _row(idx: int, *, type_: str, feature: str, tags: list[str], source_file: str) -> dict:
    return {
        "id": f"00000000-0000-0000-0000-{idx:012d}",
        "content": f"content-{idx}",
        "vector": [0.0] * 768,
        "source_file": source_file,
        "section": "Intro",
        "type": type_,
        "feature": feature,
        "date": "2026-04-21",
        "tags": tags,
        "synthetic": False,
    }


FIXTURE_ROWS = [
    _row(0, type_="adr", feature="002", tags=["memory", "vector"], source_file=".specify/memory/ADR_008.md"),
    _row(1, type_="log", feature="002", tags=["memory"], source_file=".specify/memory/LOG_014.md"),
    _row(2, type_="adr", feature="003", tags=["memory", "filters"], source_file=".specify/memory/ADR_020.md"),
    _row(3, type_="spec", feature="003", tags=[], source_file="specs/003-memory-server-hardening/spec.md"),
    _row(4, type_="synthetic", feature="002", tags=["plan"], source_file="synthetic"),
]


def _id(idx: int) -> str:
    return f"00000000-0000-0000-0000-{idx:012d}"


ALL_IDS = {_id(i) for i in range(len(FIXTURE_ROWS))}


# Each tuple: (label, spec, expected_ids). Explicit expected_ids catch a class
# of drift the set-equality-only assertion (python_ids == sql_ids) could miss:
# a regression that breaks both builders identically would pass the agreement
# check while silently returning the wrong rows.
SPECS = [
    ("empty", {}, ALL_IDS),
    ("type_only", {"filter_type": "adr"}, {_id(0), _id(2)}),
    ("feature_only", {"filter_feature": "002"}, {_id(0), _id(1), _id(4)}),
    ("single_tag", {"filter_tags": ["memory"]}, {_id(0), _id(1), _id(2)}),
    ("multi_tag_all_match", {"filter_tags": ["memory", "vector"]}, {_id(0)}),
    ("multi_tag_none_match", {"filter_tags": ["memory", "nonexistent"]}, set()),
    ("source_file", {"filter_source_file": ".specify/memory/LOG_014.md"}, {_id(1)}),
    ("type_plus_feature", {"filter_type": "adr", "filter_feature": "002"}, {_id(0)}),
    ("type_plus_tag", {"filter_type": "adr", "filter_tags": ["filters"]}, {_id(2)}),
    ("all_fields", {
        "filter_type": "adr",
        "filter_feature": "002",
        "filter_tags": ["memory"],
        "filter_source_file": ".specify/memory/ADR_008.md",
    }, {_id(0)}),
    ("no_match", {"filter_type": "nonexistent"}, set()),
]


@pytest.mark.parametrize("label,spec,expected_ids", SPECS, ids=[s[0] for s in SPECS])
def test_predicate_and_sql_agree(tmp_index, label, spec, expected_ids):
    """Predicate and SQL WHERE both return the expected row set for a spec.

    Asserts `python_ids == expected_ids == sql_ids` — a parallel regression that
    breaks both builders identically would fail the expected-set arm.
    """
    table = init_table(tmp_index)
    insert_chunks_batch(table, FIXTURE_ROWS)

    pred = _build_filter_predicate(spec)
    python_ids = {r["id"] for r in FIXTURE_ROWS if pred(r)}

    where = _build_filter_sql(spec)
    if where:
        sql_rows = table.search().where(where).limit(100).to_list()
    else:
        sql_rows = table.to_arrow().to_pylist()
    sql_ids = {r["id"] for r in sql_rows}

    assert python_ids == expected_ids, (
        f"Predicate drift for spec '{label}': matched {python_ids}, expected {expected_ids}"
    )
    assert sql_ids == expected_ids, (
        f"SQL drift for spec '{label}': matched {sql_ids}, expected {expected_ids}"
    )


def test_predicate_handles_none_tags():
    """Predicate treats a row with tags=None the same as tags=[] (guarded by `or []`)."""
    pred = _build_filter_predicate({"filter_tags": ["memory"]})
    row_none = {"type": "adr", "feature": "002", "tags": None, "source_file": "x"}
    row_empty = {"type": "adr", "feature": "002", "tags": [], "source_file": "x"}
    assert pred(row_none) is False
    assert pred(row_empty) is False
    # Must not raise on None.tags
    assert pred({"type": "adr", "feature": "002", "tags": None, "source_file": "x"}) is False


def test_empty_spec_matches_all():
    pred = _build_filter_predicate({})
    assert all(pred(r) for r in FIXTURE_ROWS)
    assert _build_filter_sql({}) == ""


def test_sql_escapes_single_quotes():
    spec = {"filter_source_file": "foo's.md"}
    assert _build_filter_sql(spec) == "source_file = 'foo''s.md'"


def test_none_values_are_ignored():
    """Keys present with None/empty values behave the same as absent keys."""
    spec = {
        "filter_type": None,
        "filter_feature": "",
        "filter_tags": [],
        "filter_source_file": None,
    }
    pred = _build_filter_predicate(spec)
    assert all(pred(r) for r in FIXTURE_ROWS)
    assert _build_filter_sql(spec) == ""
