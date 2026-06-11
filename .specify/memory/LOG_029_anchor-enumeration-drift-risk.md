---
name: LOG-029 Anchor-enumeration drift risk in _latest_routable_anchor
description: _latest_routable_anchor filters by entry_type; if new orchestrator-authored types are added without updating the filter, resume will use wrong anchors
type: open-question
cross-references:
  - .specify/scripts/bash/run-common.sh (_latest_routable_anchor)
  - .specify/memory/ADR_016_decision-log-canonical-derivative.md (exception list)
  - .specify/memory/ADR_022_verdict-receipt-enforcement.md
---

# LOG-029: Anchor-enumeration drift risk in `_latest_routable_anchor`

**Date**: 2026-05-22
**Status**: Partially mitigated (L-1 docstring fixed in code review; structural risk remains)

## Observation

`_latest_routable_anchor` in `run-common.sh` identifies the latest resumable entry in `decisions-log.md` by scanning entry type. It skips orchestrator-authored canonical-exception entries (`verdict-mismatch`, `verdict-omitted`, `pipeline-incomplete`) that are not valid resume anchors.

The filter enum must stay in sync with the exception list in ADR-016. When a new orchestrator-authored exception type is added (e.g., `stage-skip` added in this code review), the filter must be updated simultaneously or resume will treat the new type as a subagent record and anchor on it incorrectly.

In this case, `stage-skip` IS a valid resume anchor (it represents a completed stage, not a protocol-violation marker), so no filter update was needed. However, the structural risk is that a future exception type might not be a valid anchor, and the filter update could be forgotten.

The docstring for `_latest_routable_anchor` referenced deleted helpers (`run-decide-next.sh`, `run-emit-event.sh`) — corrected in this code review to point to `run-route.sh`. The stale docstring is the observable symptom of the underlying drift risk.

## Recommended mitigation

When adding a new orchestrator-authored canonical entry type to ADR-016, the engineering checklist should include:
1. Decide: is this type a valid resume anchor? (If yes → no filter change needed. If no → add to skip-list.)
2. Update `_latest_routable_anchor` docstring to list current skip-types.
3. Add a bats test asserting the type's anchor/non-anchor behavior.

Consider a constants file (sourced by `run-common.sh`) enumerating the skip-list so it can be tested independently of the scanner logic.
