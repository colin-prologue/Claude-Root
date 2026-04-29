# Quickstart — `/speckit.run`

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

This is the developer-facing how-to. Read this to understand what `/speckit.run` does, how to invoke it, and how to recover when it halts.

---

## What it does

Runs a contiguous subset of the speckit pipeline (`specify → clarify → plan → tasks → analyze → implement → codereview → audit`) in one invocation. Each stage runs in a fresh subagent; the orchestrator coordinates from your main session, writes a structured decision log, and pauses for explicit `proceed` at every code-action gate.

V1 ships single-mode **BLOCKING-everywhere**: every gate stops for your approval. There is no "fire and forget" mode in V1.

---

## Invocation

```
/speckit.run --target "specify→review→clarify→plan" [--checkpoints "pre-plan"] [--force] [--break-lock]
```

**Flags**:
- `--target` (required) — contiguous subsequence of the canonical pipeline. Examples: `specify→plan`, `specify→review→clarify→plan→review→tasks`. Reordering is rejected.
- `--checkpoints` (optional) — comma-separated list of non-code BLOCKING gates. Code-action gates are always BLOCKING regardless. Defaults to all configured non-code gates.
- `--force` — required when re-invoking on a feature directory that has `spec.md` but no `decisions-log.md` (FR-023). Without `--force`, the orchestrator halts to prevent accidental overwrite.
- `--break-lock` — required when `specs/[###]/.run/run-lock` is present from a prior session. The orchestrator surfaces the lock contents (session id, creation timestamp) so you can confirm the prior session is genuinely dead before clearing it. (ADR-018)

---

## Typical run

1. Create a feature branch (`git checkout -b 011-my-feature`) and an initial description (`specs/011-my-feature/description.md` — informal scratch).
2. Invoke `/speckit.run --target "specify→review→clarify→plan→review→tasks"`.
3. Watch the orchestrator dispatch each stage. After each non-code BLOCKING gate, you'll see:
   ```
   ✓ specify complete — specs/011-my-feature/spec.md
   ✓ review complete — no halt directive
   → next stage: clarify

   Type `proceed` to continue, `abort` to stop, or edit the artifact and re-run.
   ```
4. On `proceed`, the next subagent dispatches.
5. On `abort`, the orchestrator writes an `abort` entry, atomically removes the lock + sentinel, and exits. All artifacts produced so far remain on disk.

---

## Aborting mid-run

From a separate terminal in the same repo:

```
touch specs/011-my-feature/.run/abort
```

The orchestrator checks for this sentinel between every stage dispatch. Detection latency ≤ one stage boundary (SC-007). The currently-running subagent finishes its dispatch (the orchestrator does not interrupt mid-subagent), then the run halts.

---

## Resuming after interruption

V1 supports **in-session resume only**. If the run halted due to a temporal failure (rate limit), semantic failure (malformed entry), or you issued `abort`:

1. Read the halt summary in the developer-facing message — it names the failed stage and the recovery command.
2. Re-invoke `/speckit.run` with the same `--target`. The orchestrator detects existing complete artifacts (per FR-026 completeness predicate), skips them with explicit `stage-skip` log entries, and resumes at the first incomplete stage.

Cross-session resume (e.g., closing your laptop overnight and continuing tomorrow) is V2 (ADR-015). In V1, an interrupted run from a prior Claude Code session leaves a stale lock; clear it with `--break-lock` after confirming the prior session is dead.

---

## Reading the decision log

Two files matter:

- **`specs/[###]/decisions-log.md`** — canonical, human-primary. Every subagent's per-stage record is here, in order. Read this to audit what the pipeline decided and why.
- **`specs/[###]/.run/control-flow.log`** — orchestrator-only sidecar in JSONL. Useful for tooling or for reconstructing a partial run after interruption. Not required reading.

After clean termination, the orchestrator appends a single coalesced control-flow summary to `decisions-log.md`. Mid-run, the canonical log contains only subagent records — the orchestrator's view of routing is in the sidecar until close.

---

## When the orchestrator halts

| Halt class | What happened | What to do |
|---|---|---|
| `subagent-halt-directive` | A review/audit subagent flagged blocking findings | Read the subagent's log entry, address findings (edit the artifact), re-run `/speckit.run` |
| `code-gate-blocking` | About to dispatch `implement`/`codereview`/`audit` | Read the prior stage's artifact; type `proceed` or `abort` |
| `schema-violation` | Subagent wrote a malformed `decisions-log.md` entry | Inspect the entry; fix or roll back; re-run |
| `rate-limit — temporal` | API rate limit hit mid-dispatch | Wait the indicated duration; re-run |
| `permission` | Sandbox violation, lock conflict, or tool denial | Read the diagnostic; address (edit, `--break-lock`, etc.); re-run |

In every halt case, the orchestrator's halt message is self-contained: it names the failed stage, the failure class, and the exact re-trigger command. You should not need to dig through documentation.

---

## What's not in V1

- **OBSERVING mode** — V2 (ADR-015). V1 is BLOCKING-everywhere.
- **Cross-session auto-resume on rate-limit** — V2 (ADR-015). V1 halts and waits.
- **Checkpoint-decision files** for the learning loop — V2 (US-3, ADR-015).
- **Token-usage telemetry in the decision log** — V2 (ADR-015).
- **Concurrent runs** on the same feature directory — forbidden (FR-028).
