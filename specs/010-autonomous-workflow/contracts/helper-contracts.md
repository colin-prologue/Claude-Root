# Contract — `run-*.sh` Helper Outputs

Every helper has a single purpose, a defined invocation, and exit-code semantics suitable for use from the slash-command markdown. Output goes to stdout; diagnostics to stderr; exit code is the routing input.

Source of truth: ADR-019 (deterministic core boundary), plus the FRs each helper implements. ADR-022 (verdict-receipt enforcement) and ADR-023 (pre-route postcheck) extend the deterministic core; their helper contracts appear below.

## Verdict-Receipt Protocol (ADR-022)

`run-decide-next.sh`, `run-emit-event.sh`, and `run-serialize.sh` cooperate via a one-shot on-disk receipt and a termination-time completeness invariant to **structurally detect** both forgery (LLM authors a route event without invoking the helper) and omission (LLM invokes one helper but skips the other) of the deterministic-core protocol:

1. `run-decide-next.sh` writes its verdict to `specs/[###]/.run/last-verdict` as a single line: `<verdict>\t<run_id>\t<input_hash>\t<ts>` (tab-separated). **Before minting**, it checks the existing receipt size — if non-empty, a prior verdict was minted but never consumed, the helper exits non-zero and writes a `verdict-omitted` semantic-failure entry to `decisions-log.md` (in-band omission detection per ADR-022 step 5).
2. `run-emit-event.sh`, when emitting any event in the **routing-decision set** (`route`, `stage-skip`, `abort`, `halt-*`), MUST read `.run/last-verdict` and assert that the event matches the verdict, `run_id`, and `input_hash`. **Missing-receipt is treated identically to mismatched-receipt** (the LLM either bypassed `run-decide-next.sh` or attempted a second emission after the first consumed the receipt).
3. On match: emission proceeds; the receipt is consumed (truncated to 0 bytes).
4. On mismatch or missing receipt: emission refuses (exit 1), no sidecar line is written, and a `verdict-mismatch` semantic-failure entry is appended to `decisions-log.md` via the same canonical write path the subagent uses.
5. Events outside the routing-decision set (`stage-start`, `break-lock`, `budget-exhausted`) emit without receipt requirement.
6. `run-lock.sh acquire` wipes any stale receipt; `run-lock.sh release` wipes the receipt as part of cleanup.
7. **Pipeline completeness invariant** (ADR-022 step 6, termination-time): `run-serialize.sh`, before appending the coalesced summary, asserts (a) `.run/last-verdict` is empty and (b) `.run/control-flow.log` contains at least one routing-decision event for every stage that has a per-stage record in `decisions-log.md`. On mismatch, it writes a `pipeline-incomplete` semantic-failure entry to the canonical log before the coalesced summary, surfacing the omission in the durable audit trail. This catches the case where the LLM skips both `run-decide-next.sh` and `run-emit-event.sh` for a stage (neither in-band check fires).

Tier 1 unit tests cover: matched emission consumes the receipt; mismatched emission refuses and writes the canonical `verdict-mismatch` entry; second emission attempt without fresh verdict fails identically; stale cross-run receipt fails on `run_id` mismatch; **`run-decide-next.sh` refuses to mint when prior receipt is unconsumed and writes `verdict-omitted`**; **`run-serialize.sh` writes `pipeline-incomplete` when sidecar lacks a routing event for a stage record**. Plus a **static-grep test** asserting `.claude/commands/speckit.run.md` invokes `run-decide-next.sh` and `run-emit-event.sh` for every routing point in the prescribed sequence (catches authoring drift before runtime).

---

## `run-common.sh`

**Implements**: shared bash utilities for the `run-*.sh` family (separated from the project-wide `common.sh` to keep the orchestrator helper surface auditable independently).

**Not invoked directly**; sourced by other `run-*.sh` helpers via `. "$(dirname "$0")/run-common.sh"`.

**Provides**:
- `_run_lock_dir <feature-dir>` — canonical path to `.run/`.
- `_atomic_rename_into <src> <dst>` — `mv -f` wrapper with stderr capture for stage-then-rename writes (LOG-012).
- `_emit_canonical_entry <feature-dir> <entry-markdown>` — append a markdown section to `decisions-log.md` via stage-then-rename. Used by `run-emit-event.sh` for `verdict-mismatch` entries, by `run-decide-next.sh` for `verdict-omitted` entries, and by `run-serialize.sh` for the coalesced summary and `pipeline-incomplete` entries (the three orchestrator-authored canonical-entry exceptions per ADR-016).
- `_sweep_tmp <dir>` — remove orphan `.tmp` files left by an interrupted prior run.
- `_run_id_of_lock <feature-dir>` — read `run_id=` line from the lock file.
- `_hash_input <data>` — short hash for verdict-receipt input field.

**Test surface**: covered indirectly via the helpers that source it; no dedicated bats file (per ADR-019 single-purpose convention — `run-common.sh` is infrastructure, not a routing primitive).

---

## `run-lock.sh`

**Implements**: FR-027, FR-028, ADR-018.

**Invocations**:
```
run-lock.sh acquire <feature-dir>
run-lock.sh release <feature-dir>
run-lock.sh break <feature-dir>
run-lock.sh check-sentinel <feature-dir>
```

**Behavior**:
- `acquire` — atomic `mkdir`-based create; on conflict, prints lock contents to stdout and exits non-zero. On success: wipes stale `.run/last-verdict` (ADR-022) and sweeps `.run/*.tmp` (LOG-012) before returning.
- `release` — staged remove of `run-lock`, `abort` sentinel (if present), and `last-verdict` via temp-dir-rename idiom (FR-027 atomicity). MUST be invoked **after** `run-serialize.sh` has appended the coalesced summary on every termination path.
- `break` — same as `release` but tolerates absence of an active session; emits `break-lock` event to sidecar (per ADR-018).
- `check-sentinel` — exit 0 if `abort` is absent; exit 1 if present. **Per ADR-019 b1 amendment** (sentinel fold-in), this command is no longer invoked by the orchestrator between dispatches; `run-decide-next.sh` consumes the sentinel state internally and emits the `abort` verdict. `check-sentinel` remains as a Tier 1 test surface and as a recovery utility (e.g., for `run-lock.sh break` flows that need to surface sentinel state to `break-lock` event payload).

**Exit codes**:
- `0` — success.
- `1` — lock held (acquire), or sentinel present (check-sentinel).
- `2` — usage error.
- `3` — filesystem error.

---

## `run-completeness.sh`

**Implements**: FR-026.

**Invocation**:
```
run-completeness.sh <feature-dir> <stage>
```

**Output (stdout)**: single token — `complete` or `incomplete`. No other output.

**Exit codes**:
- `0` — token written; routing input is the token.
- `2` — usage error (unknown stage, feature-dir missing).

**Per-stage logic** documented in `data-model.md` § E-7.

---

## `run-target.sh`

**Implements**: FR-009.

**Invocations**:
```
run-target.sh validate <target-string>
run-target.sh next <target-string> <last-completed-stage>
```

**Behavior**:
- `validate` — parse `<target-string>` (e.g., `specify→review→plan`); confirm contiguous subsequence of canonical order. Exit 0 if valid.
- `next` — given last completed stage, output the next stage in target. Output `__END__` if target exhausted.

**Output (stdout)**: stage name on success, `__END__` at exhaustion, empty on validation success.

**Exit codes**:
- `0` — success.
- `1` — invalid target (validate) or last-completed not in target (next).
- `2` — usage error.

---

## `run-decide-next.sh`

**Implements**: ADR-019 routing core; FRs 004, 021, 022, 023, 025.

**Invocation**:
```
run-decide-next.sh <feature-dir>
```

**State inputs** (read on every invocation): the latest entry in `decisions-log.md`, the existing `.run/last-verdict` size, and the **`.run/abort` sentinel file** (per ADR-019 b1 fold-in — sentinel detection is now part of the routing decision rather than a fast-path orchestrator check).

**Behavior**:
1. **Pre-flight omission check** (ADR-022 step 5): if `.run/last-verdict` is non-empty, a prior verdict was minted but never consumed by an emission. The helper refuses to mint, exits non-zero, writes a `verdict-omitted` semantic-failure entry to `decisions-log.md` via `_emit_canonical_entry`. No receipt is overwritten (the original unconsumed verdict remains as evidence).
2. **Sentinel check** (ADR-019 b1 fold-in / FR-027): if `.run/abort` exists, the verdict is `abort`, written ahead of any other routing logic. Receipt is minted normally (so `run-emit-event.sh` can validate the `abort` event like every other route).
3. **Routing logic**: Reads the latest **subagent record** in `decisions-log.md` (see resume-scan filter below), applies routing logic, outputs one of:
   - `continue` — proceed to next target stage.
   - `halt:<reason>` — halt and present to developer (subagent emitted `halt_directive=true`, OR validation failed, OR a checkpoint threshold reached).
   - `skip:<stage>` — skip the named stage (predicate or empty-output condition met; FR-024).
   - `abort` — abort sentinel detected (step 2 above) OR subagent emitted abort entry.

   **Resume-scan filter** (Re-Review #2 RC-5 / FR-023): when locating the "latest entry" for routing, the helper MUST skip the three orchestrator-authored entry types (`verdict-mismatch`, `verdict-omitted`, `pipeline-incomplete` — see ADR-016 single-writer-at-a-time framing). These entries are violation/bookkeeping records, not stage-completion records, and are not valid resume anchors. The latest entry read for routing is the most recent entry with `entry_type ∈ {stage-start, stage-end, halt, abort, stage-skip, route, break-lock}` (i.e., a subagent-authored stage record OR an orchestrator-authored control-flow record, but never an orchestrator-authored canonical-exception record). Without this filter, a `pipeline-incomplete` written at the end of a prior crashed run becomes the resume anchor on the next `--resume`, producing wrong-stage resumption.

**Side effect** (ADR-022): on every successful invocation (including `abort`), writes the verdict to `.run/last-verdict` as `<verdict>\t<run_id>\t<input_hash>\t<ts>` (tab-separated, single line). The receipt is the structural prerequisite for the next `run-emit-event.sh` call in the routing-decision set.

**Reasons** (after `halt:`): `subagent-halt-directive`, `schema-violation`, `code-gate-blocking` (ADR-014), `multi-blocker-collected` (FR-021 — emitted only when a review stage's halt directive aggregates multiple blockers), `postcheck-failed` (ADR-023 — emitted when `run-postcheck.sh` exited non-zero), `verdict-mismatch` (ADR-022 — emitted by `run-emit-event.sh`'s canonical-write path when a prior emission was refused).

**Exit codes**:
- `0` — verdict written to stdout AND receipt written; LLM MUST obey verdict and invoke `run-emit-event.sh` next.
- `1` — log unreadable / malformed beyond recovery (halts as semantic failure per FR-019), OR pre-flight omission detected (canonical `verdict-omitted` entry written; orchestrator MUST halt). No fresh receipt is written.
- `2` — usage error. No receipt is written.

---

## `run-emit-event.sh`

**Implements**: ADR-020 sidecar JSONL emission; ADR-022 verdict-receipt enforcement.

**Contract**: see `sidecar-event.md` for the wire format.

**Verdict-receipt enforcement** (ADR-022): for events in the routing-decision set (`route`, `stage-skip`, `abort`, `halt-*`), the helper MUST:
1. Read `.run/last-verdict`.
2. Compare verdict, `run_id`, and `input_hash` to the event being emitted.
3. On match: append the JSONL line to `.run/control-flow.log`, then truncate `.run/last-verdict` to 0 bytes.
4. On mismatch or missing receipt: refuse emission (exit 1), append a `verdict-mismatch` entry to `decisions-log.md` via `_emit_canonical_entry` (run-common.sh), and write a diagnostic line to stderr.

Events outside the routing-decision set (`stage-start`, `break-lock`, `budget-exhausted`) are emitted without receipt requirement.

**Exit codes**:
- `0` — event emitted; receipt consumed (if applicable).
- `1` — verdict-receipt mismatch or missing; canonical `verdict-mismatch` entry written; orchestrator MUST halt.
- `2` — usage error or filesystem error.

---

## `run-validate-entry.sh`

**Implements**: FR-006.

**Contract**: see `decision-log-entry.md` § Validation contract.

---

## `run-check-sandbox.sh`

**Implements**: FR-020.

**Invocation**:
```
run-check-sandbox.sh <feature-dir> <stage>
```

**Behavior**: After a code-action subagent (`implement`, `codereview`, `audit`) returns, audit `git diff` against the FR-020 allowlist. Reports any disallowed path modification. **Independent of `run-postcheck.sh`** (ADR-023): sandbox checks audit "did the subagent touch a file it shouldn't have"; postcheck audits "do the artifacts the subagent claims to have produced satisfy cross-references and prerequisites." Both run on every code-action stage.

**Output (stdout)**: empty on clean; one violation per line (`<path>: <reason>`) on detection.

**Exit codes**:
- `0` — sandbox clean.
- `1` — violation detected (orchestrator MUST halt as permission failure per FR-019; the halt path triggers MUST-coalesce per ADR-016 amendment).
- `2` — usage error or git unavailable.

---

## `run-postcheck.sh`

**Implements**: ADR-023 pre-route linter postcheck on code-action stages.

**Invocation**:
```
run-postcheck.sh <feature-dir> <stage>
```

**Stage applicability**: V1 invokes only for `stage ∈ {implement, codereview, audit}`. Non-code stages are out of scope per LOG-010.

**Behavior**: Runs the project's existing linters against the post-dispatch repository state and the just-written subagent record:
1. `check-adr-crossrefs.sh` — every ADR/LOG referenced in the subagent record exists; every newly-created ADR/LOG has at least one inbound reference (Principle VII).
2. `check-prerequisites.sh --feature-dir <feature-dir>` **[PRECURSOR: PR0 — adds this flag; `check-prerequisites.sh` exits 1 on `--feature-dir` today]** — feature-dir invariants hold (spec.md, plan.md, tasks.md exist as required by the stage; constitution.md present). The `--feature-dir` flag is consumed positionally by `check-prerequisites.sh` and overrides the script's default branch-name-derived feature path. **Precursor task** (Re-Review #2 RC-2 / Re-Review #3 S-1): `check-prerequisites.sh` and the underlying `common.sh::find_feature_dir_by_prefix()` are extended in a 1-commit precursor (PR0) before PR3a to accept this flag; until that commit lands, the flag does not exist in the script and `run-postcheck.sh` cannot be implemented to satisfy this contract. The flag is required (not optional) because `run-postcheck.sh` may be invoked under `/speckit.run --resume --feature-dir=...` from a branch whose name does not encode the target feature directory; relying on the script's branch-derived default produces silent wrong-directory validation in that case.
3. For `stage=implement` only: cross-check claimed test files in the subagent record against `git ls-files` — claimed-but-missing test paths are findings.

**Invocation order**: MUST run **before** `run-decide-next.sh` so that postcheck failures suppress the route and surface findings inline in the BLOCKING-checkpoint payload.

**Output (stdout)**: clean exit MUST emit the single neutral status line `postcheck: no findings` (no iconography, no color, no "✓"-style affirmation, no "all checks passed" phrasing). One finding per line (`<check>: <detail>`) on failure. **Rationale** (Re-Review #3 M-4 / LOG-013): an overtly affirmative no-findings banner converts ambiguity into reassurance and accelerates BLOCKING-gate rubber-stamping. The neutral phrasing is a normative MUST here (not a recommendation in LOG-013) so that the slash-command author and the static-grep test (PR3b-ii) have a single source of truth.

**Exit codes**:
- `0` — all checks passed; orchestrator proceeds to `run-decide-next.sh`.
- `1` — one or more checks failed; orchestrator emits `halt:postcheck-failed` with the findings appended to the BLOCKING-checkpoint payload. Developer override (`proceed`) is captured as `route` event with `reason=postcheck-override`.
- `2` — usage error or required linter unavailable.

---

## `run-serialize.sh`

**Implements**: ADR-016 MUST-coalesce write of the orchestrator's coalesced summary to `decisions-log.md` on every termination path.

**Invocation**:
```
run-serialize.sh <feature-dir> <termination-kind>
```

**`<termination-kind>`**: one of `clean`, `halt`, `abort`, `permission-failure`.

**Behavior**:
1. **Pipeline completeness invariant** (ADR-022 step 6): before formatting the coalesced summary, assert that:
   - `.run/last-verdict` is empty (no unconsumed verdict at termination), AND
   - `.run/control-flow.log` contains at least one routing-decision event (`route`, `stage-skip`, `abort`, `halt-*`) for every stage that has a per-stage record in `decisions-log.md` (i.e., the LLM did not skip both `run-decide-next.sh` and `run-emit-event.sh` for any stage).
   On invariant violation, write a `pipeline-incomplete` semantic-failure entry to `decisions-log.md` via `_emit_canonical_entry` **before** the coalesced summary, listing each missing-event stage. The coalesced summary still appends afterward; `pipeline-incomplete` becomes part of the durable audit trail rather than blocking termination.
2. **Coalesce write**: Reads the sidecar at `.run/control-flow.log`, formats a single coalesced FR-006-conforming markdown section (including the termination kind, reason, and event summary), and appends it to `decisions-log.md` via the **stage-then-rename idiom** (LOG-012):
   1. Read current `decisions-log.md` into a same-directory temp file (`decisions-log.md.<run_id>.tmp`).
   2. Append the coalesced summary block to the temp file.
   3. `mv -f` the temp file over `decisions-log.md` (atomic on macOS/Linux same-filesystem semantics).

If `decisions-log.md` does not exist (cold start), the temp file is created from scratch with the coalesced block as its only content.

**Invocation order**: MUST run **before** `run-lock.sh release` on every termination path. Extracted as a separate helper (per S-1 plan-gate decision) so the coalesce logic is independently testable in Tier 1 (write protocol + sidecar→canonical translation, separate from the lock-lifecycle concerns of `run-lock.sh`).

**Output (stdout)**: empty on success; diagnostic on failure.

**Exit codes**:
- `0` — coalesced summary appended; canonical log is in a consistent state.
- `1` — write failed (filesystem error, mv failed, sidecar unparseable). Caller MUST proceed to `run-lock.sh release` regardless to avoid stale-lock state; the canonical log remains as it was before the failed write (atomic-rename guarantees this).
- `2` — usage error.
