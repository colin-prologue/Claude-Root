---
description: Run a contiguous speckit pipeline sequence with BLOCKING checkpoints at every gate
---

## Input

`$ARGUMENTS` — parse the following flags:

- `--target <seq>` **(required)** — pipeline subsequence, e.g. `specify→plan→tasks`. Reordering rejected.
- `--checkpoints <list>` *(optional)* — comma-separated non-code gate names to BLOCK. Code-action gates (`implement`, `codereview`, `audit`) always BLOCK regardless.
- `--force` — bypass the spec-exists / no-log guard (FR-023).
- `--break-lock` — surface and clear a stale lock from a prior session.

---

## Initialization

Helper prefix: `.specify/scripts/bash/`. Invoke each helper from the repo root.

1. Run `check-prerequisites.sh --json`. Parse `FEATURE_DIR` (absolute path) from output.
2. Run `run-target.sh validate "$TARGET"`. On exit ≠ 0: print the validation error, stop.
3. If `--break-lock`:
   - Run `run-lock.sh break "$FEATURE_DIR"`. Print the prior lock's `session_id` and `created_at`.
   - Ask: "Confirm prior session is dead and lock can be cleared? (yes/no)." On "no": stop.
4. FR-023 guard (skip if `--force`): if `$FEATURE_DIR/spec.md` exists and `$FEATURE_DIR/decisions-log.md` absent — halt with: "spec.md exists but no decisions-log.md found. Re-invoke with `--force` to start a fresh run."
5. Run `run-lock.sh acquire "$FEATURE_DIR"`. On exit ≠ 0 — halt (§Halt: lock-conflict).
6. Set `STAGE` = first stage in `--target`. Set `PREV_STAGE` = "".

---

## Per-Stage Loop

Repeat until `STAGE = __END__`. On any failure, jump to §TERMINATE with the appropriate kind.

### a. Completeness check

```
run-completeness.sh "$FEATURE_DIR" "$STAGE"
```

If output = `complete`:
```
run-route.sh "$FEATURE_DIR" stage="$STAGE" criterion="artifact already present"
```
Advance: `STAGE = run-target.sh next "$TARGET" "$STAGE"`. Continue loop.

### b. Emit stage-start

```
run-emit-event.sh "$FEATURE_DIR" stage-start stage="$STAGE"
```

### c. Store pre-dispatch HEAD

```
git rev-parse HEAD > "$FEATURE_DIR/.run/pre-dispatch-head"
```

### d. Code-gate BLOCKING pause

Only if `STAGE ∈ {implement, codereview, audit}`:

```
→ about to dispatch: $STAGE
   review the prior stage output in $FEATURE_DIR/decisions-log.md
   type `proceed` to continue or `abort` to stop
```

Wait for user input. On `abort`: TERMINATE(abort).

### e. Dispatch subagent

Use the **Task tool**. Pass the following to the subagent:

> Feature directory: `$FEATURE_DIR` (absolute path)
> Stage: `$STAGE`
>
> Run `/speckit.$STAGE` for this feature. Then write a FR-006-conforming record
> to `$FEATURE_DIR/decisions-log.md`. Schema: `specs/010-autonomous-workflow/contracts/decision-log-entry.md`.
> The record MUST include `halt: true` or `halt: false`. If halting, include
> `halt-reason: <subagent-halt-directive | schema-violation | unspecified>`.
> Do NOT skip writing the canonical log entry.

Wait for Task completion before proceeding.

### f. Post-dispatch checks (code-action stages only)

Only if `STAGE ∈ {implement, codereview, audit}`:

**Sandbox check:**
```
run-check-sandbox.sh "$FEATURE_DIR" "$STAGE"
```
On exit ≠ 0: TERMINATE(permission-failure) — include violation list in halt message.

**Postcheck:**
```
run-postcheck.sh "$FEATURE_DIR" "$STAGE"
```
On exit 0 (`postcheck: no findings`): continue to step g.
On exit ≠ 0: present findings, then prompt:

```
postcheck findings above — type `proceed` to override (recorded) or `abort` to stop
```

On `proceed`: proceed to step g with `POSTCHECK_OVERRIDE=true`.
On `abort`: TERMINATE(abort).

### g. Route

```
run-route.sh "$FEATURE_DIR" from="$STAGE" to="$NEXT_STAGE" reason="subagent complete"
```

If `POSTCHECK_OVERRIDE=true`, use `reason=postcheck-override` instead.

Read stdout:

| Verdict | Action |
|---|---|
| `continue` | Advance STAGE → continue loop |
| `halt:<reason>` | TERMINATE(halt) with that reason |
| `abort` | TERMINATE(abort) |
| `skip:<stage>` | Advance STAGE → continue loop |

Advance: `PREV_STAGE = STAGE`, then `STAGE = run-target.sh next "$TARGET" "$STAGE"`.

When `run-target.sh next` outputs `__END__`: TERMINATE(clean).

---

## TERMINATE

**On every exit path**, run in this order before stopping:

```
run-serialize.sh "$FEATURE_DIR" <kind>
run-lock.sh release "$FEATURE_DIR"
```

`<kind>`: `clean` | `halt` | `abort` | `permission-failure`

Then present the appropriate halt message (§Halt Messages), or on clean:

> Pipeline complete. Stages run: [list]. Artifacts in `$FEATURE_DIR`.

---

## Halt Messages

Every message is self-contained: stage, failure class, re-trigger command.

**subagent-halt-directive**
> `$STAGE` halted with blocking findings. Address the findings in `$FEATURE_DIR/decisions-log.md`, then re-run: `/speckit.run --target "$TARGET"`

**schema-violation**
> `$STAGE` subagent wrote a malformed decisions-log entry. Inspect and fix or roll back the entry, then re-run: `/speckit.run --target "$TARGET"`

**permission** (sandbox)
> Sandbox violation after `$STAGE`. Disallowed path(s): [list from run-check-sandbox.sh stdout]. Fix the violation, then re-run: `/speckit.run --target "$TARGET"`

**postcheck-failed** (on abort)
> Post-dispatch check failed for `$STAGE`. [findings from run-postcheck.sh stdout]. Fix and re-run: `/speckit.run --target "$TARGET"`

**abort** (user or sentinel)
> Run aborted at `$STAGE`. All artifacts produced so far remain on disk. Re-run: `/speckit.run --target "$TARGET"`

**lock-conflict**
> Lock held — session: [id], created: [ts]. If that session is dead, re-run with `--break-lock`.

**rate-limit — temporal**
> Rate limit hit during `$STAGE`. Wait the indicated duration, then re-run: `/speckit.run --target "$TARGET"`
