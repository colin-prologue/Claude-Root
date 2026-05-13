# LOG-026 — ADR-022 Receipt Protocol Eliminated (ADR-022 rev.1)

**Date**: 2026-05-13
**Status**: Closed — decision implemented
**Related**: ADR-022, specs/010-autonomous-workflow/plan.md, specs/010-autonomous-workflow/spec.md

## Summary

The verdict-receipt protocol introduced by ADR-022 was eliminated. The two-step
`run-decide-next.sh` + `run-emit-event.sh` routing flow was replaced by a single
`run-route.sh` helper that reads the log, derives the verdict, and emits the
sidecar event atomically.

## Background

ADR-022 added a verdict-receipt mechanism to prevent the LLM from calling
`run-emit-event.sh` with a routing event without first calling
`run-decide-next.sh`. The receipt was a file (`.run/last-verdict`) minted by
decide-next and consumed by emit-event, with a hash of the log state at
decision time to detect stale receipts.

## Why It Was Removed

Two adversarial reviewers (code-simplifier + devils-advocate) identified the
overrun during pre-push review of PR2b: helpers landed at 649 LOC against a
plan budget of ~350. Investigation found ~70% of the overrun was design
overhead, not implementation fat.

The core finding: the receipt protocol defends against one failure mode (helper
bypass — LLM calls emit-event without calling decide-next) that already has a
second defense in PR3b-ii (static-grep test enforcing the call sequence in
`speckit.run.md`). Two defenses for one failure mode in a deterministic,
single-caller system is over-design.

Additional consequences of the protocol that argued for removal:
- `verdict-omitted` canonical entries would appear in `decisions-log.md` on any
  Ctrl-C between decide-next and emit-event (benign interrupts pollute the log).
- `pipeline-incomplete` entries (ADR-022 step 6) were purely diagnostic with no
  prescribed recovery action — audit theatre.
- The receipt-hash verification required `_hash_input` + `_latest_routable_anchor`
  to be called in both helpers, coupling them to a shared input model.

## What Changed

| Before | After |
|---|---|
| `run-decide-next.sh` (134 LOC) | Deleted |
| `run-emit-event.sh` (251 LOC) | Slimmed to 106 LOC (non-routing events only) |
| `run-serialize.sh` (264 LOC) | Slimmed to 109 LOC (pipeline-completeness invariant removed) |
| `run-route.sh` | New: 172 LOC (atomic decide + emit) |
| Total helpers: 649 LOC | Total helpers: 387 LOC (route + emit-event) |

`run-common.sh` lost `_hash_input` (no remaining caller). `_emit_canonical_entry`
and `_atomic_rename_into` stay — still used by `run-serialize.sh` for the
coalesced termination summary.

## Test Impact

- `test_decide_next.bats` (21 cases): deleted
- `test_emit_event.bats`: trimmed from 21 to 9 cases (routing cases removed)
- `test_serialize.bats`: trimmed from 20 to 11 cases (invariant-a/b removed)
- `test_route.bats` (23 cases): new
- Net suite: 118/118 green (was 137/137 before PR2b redesign)

## Remaining Defense Against Helper Bypass

The single remaining defense is the PR3b-ii static-grep test, which will assert
that `speckit.run.md` calls `run-route.sh` (not the old pair) for routing
decisions. This is adequate: the failure mode is an authoring error in a
markdown file, not a runtime race condition.
