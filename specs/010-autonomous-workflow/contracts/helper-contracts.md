# Contract — `run-*.sh` Helper Outputs

Every helper has a single purpose, a defined invocation, and exit-code semantics suitable for use from the slash-command markdown. Output goes to stdout; diagnostics to stderr; exit code is the routing input.

Source of truth: ADR-019 (deterministic core boundary), plus the FRs each helper implements. ADR-022 rev.1 (single-helper routing — LOG-026) and ADR-023 (pre-route postcheck) extend the deterministic core; their helper contracts appear below.

## Single-Helper Routing (ADR-022 rev.1)

`run-route.sh` handles routing decisions atomically: it reads `decisions-log.md`, derives the verdict, and emits the appropriate sidecar event in a single process. No on-disk receipt is written or consumed.

The original two-step verdict-receipt protocol (`run-decide-next.sh` → `.run/last-verdict` → `run-emit-event.sh` validation) was eliminated in LOG-026. The sole remaining defense against helper bypass is the PR3b-ii static-grep test asserting that `speckit.run.md` invokes `run-route.sh` at every routing point.

Tier 1 unit tests cover: continue/halt/skip/abort routing matrix; no-receipt invariant (sequential calls succeed without pre-flight check); resume-scan filter (FR-023); FR-024 criterion enforcement; usage errors.

---

## `run-common.sh`

**Implements**: shared bash utilities for the `run-*.sh` family (separated from the project-wide `common.sh` to keep the orchestrator helper surface auditable independently).

**Not invoked directly**; sourced by other `run-*.sh` helpers via `. "$(dirname "$0")/run-common.sh"`.

**Provides**:
- `_run_lock_dir <feature-dir>` — canonical path to `.run/`.
- `_atomic_rename_into <src> <dst>` — `mv -f` wrapper with stderr capture for stage-then-rename writes (LOG-012).
- `_emit_canonical_entry <feature-dir> <entry-markdown>` — append a markdown section to `decisions-log.md` via stage-then-rename. Used by `run-serialize.sh` for the coalesced termination summary (ADR-016).
- `_sweep_tmp <dir>` — remove orphan `.tmp` files left by an interrupted prior run.
- `_run_id_of_lock <feature-dir>` — read `run_id=` line from the lock file.
- `_latest_routable_anchor <feature-dir>` — outputs `<entry_type>:<stage>:<lineno>` for the latest entry in `decisions-log.md` that is a valid resume anchor (FR-023 / RC-5 filter). Used by `run-route.sh` to locate the routing anchor.

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
- `acquire` — atomic `mkdir`-based create; on conflict, prints lock contents to stdout and exits non-zero. On success: sweeps `.run/*.tmp` (LOG-012) before returning.
- `release` — staged remove of `run-lock` and `abort` sentinel (if present) via temp-dir-rename idiom (FR-027 atomicity). MUST be invoked **after** `run-serialize.sh` has appended the coalesced summary on every termination path.
- `break` — same as `release` but tolerates absence of an active session; emits `break-lock` event to sidecar (per ADR-018).
- `check-sentinel` — exit 0 if `abort` is absent; exit 1 if present. **Per ADR-019 b1 amendment** (sentinel fold-in), this command is no longer invoked by the orchestrator between dispatches; `run-route.sh` reads the sentinel internally. `check-sentinel` remains as a Tier 1 test surface and recovery utility.

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

## `run-route.sh`

**Implements**: ADR-019 routing core; ADR-022 rev.1 (single-helper atomic routing); FRs 004, 021, 023, 024, 025.

**Invocation**:
```
run-route.sh <feature-dir> [key=value]...
```

**Required key=value by verdict** (all others ignored):

| Verdict | Required fields |
|---|---|
| `continue` | `from=<stage>` `to=<stage>` `reason=<text>` |
| `skip:<stage>` | `stage=<stage>` `criterion=<text>` |
| `abort` | `triggered_by=<text>` |
| `halt:<reason>` | (none — halt recorded via subagent canonical log) |

**Behavior**: reads `decisions-log.md`, derives verdict from the latest routable anchor (FR-023 resume-scan filter), emits the appropriate sidecar event atomically. No receipt file is written or read.

1. **Sentinel check** (ADR-019 b1 / FR-027): if `.run/abort` exists, verdict is `abort` regardless of log state.
2. **Routing matrix** (latest routable anchor → verdict):
   - `subagent-record` with `halt=true` → `halt:<reason>` (no sidecar event emitted)
   - `subagent-record` with `halt=false` → `continue` → emits `route` event
   - `abort` entry → `abort` → emits `abort` event
   - `stage-skip:<stage>` entry → `skip:<stage>` → emits `stage-skip` event (FR-024: `criterion` required)
   - other (`stage-start`, `stage-end`, `route`, `escalate`) → `continue` → emits `route` event

3. **Resume-scan filter** (FR-023 / RC-5): skips orchestrator bookkeeping entries when scanning for the routing anchor. Valid anchor types: `subagent-record`, `stage-start`, `stage-end`, `stage-skip`, `route`, `abort`, `escalate`.

**Output (stdout)**: `continue | halt:<reason> | skip:<stage> | abort`

**Reasons** (after `halt:`): `subagent-halt-directive`, `schema-violation`, `code-gate-blocking` (ADR-014), `multi-blocker-collected` (FR-021), `postcheck-failed` (ADR-023), `unspecified` (halt=true with no reason field).

**Exit codes**:
- `0` — routing action completed (event emitted for continue/skip/abort; stdout carries verdict for halt).
- `1` — semantic failure (log missing/unreadable, no routable anchor).
- `2` — usage error (missing feature-dir, missing required field for derived verdict).

---

## `run-emit-event.sh`

**Implements**: ADR-020 sidecar JSONL emission (non-routing events only; ADR-022 rev.1).

**Contract**: see `sidecar-event.md` for the wire format.

**Scope** (ADR-022 rev.1): handles only non-routing events — `stage-start`, `break-lock`, `budget-exhausted`. Routing events (`route`, `stage-skip`, `abort`) are now emitted by `run-route.sh`. Passing a routing event name exits 2.

**Invocation**:
```
run-emit-event.sh <feature-dir> <event-name> [key=value]...
```

**Required fields by event**:

| Event | Required |
|---|---|
| `stage-start` | `stage` |
| `break-lock` | `prior_session`, `prior_ts` |
| `budget-exhausted` | `tier`, `tokens` |

**Exit codes**:
- `0` — JSONL line appended to `.run/control-flow.log`.
- `2` — usage error, unknown/routing event name, or missing required field.

---

## `run-validate-entry.sh`

**Implements**: FR-006.

**Contract**: see `.specify/contracts/decision-log-entry.md` § Validation contract.

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
2. `check-prerequisites.sh --feature-dir <feature-dir>` — feature-dir invariants hold (spec.md, plan.md, tasks.md exist as required by the stage; constitution.md present). The `--feature-dir` flag overrides the script's default branch-name-derived feature path, which is required when `/speckit.run` is invoked with `--resume --feature-dir=...` from a branch whose name does not encode the target feature directory.
3. For `stage=implement` only: cross-check claimed test files in the subagent record against `git ls-files` — claimed-but-missing test paths are findings.

**Invocation order**: MUST run **before** `run-route.sh` so that postcheck failures suppress the route and surface findings inline in the BLOCKING-checkpoint payload.

**Output (stdout)**: clean exit MUST emit the single neutral status line `postcheck: no findings` (no iconography, no color, no "✓"-style affirmation, no "all checks passed" phrasing). One finding per line (`<check>: <detail>`) on failure. **Rationale** (Re-Review #3 M-4 / LOG-013): an overtly affirmative no-findings banner converts ambiguity into reassurance and accelerates BLOCKING-gate rubber-stamping. The neutral phrasing is a normative MUST here (not a recommendation in LOG-013) so that the slash-command author and the static-grep test (PR3b-ii) have a single source of truth.

**Exit codes**:
- `0` — all checks passed; orchestrator proceeds to `run-route.sh`.
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
1. **Coalesce write**: Reads the sidecar at `.run/control-flow.log`, formats a single coalesced FR-006-conforming markdown section (including the termination kind, reason, and event summary), and appends it to `decisions-log.md` via the **stage-then-rename idiom** (LOG-012):
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
