# tests/

Two-tier test layout for the `/speckit.run` orchestrator (per ADR-017).

## Tier 1 — `unit/` (bats, pre-commit)

Fast, deterministic, no LLM calls. Covers every `run-*.sh` helper, the verdict-receipt
protocol, completeness predicates, target validation, and slash-command authoring drift.

**Run locally:**

```bash
bats tests/unit/
```

Tier 1 is TDD-strict (Principle III): tests are written and verified to fail before the
helper they exercise is implemented. Helper/test pairs land as commit pairs per
`plan.md` "Intra-PR commit discipline."

## Tier 2 — `smoke/` (bats + real subagents, pre-merge, cost-capped)

Two synthetic fixtures (one green path, one halt path) that exercise `/speckit.run`
end-to-end with real subagent dispatches. Per-run cap: 50K tokens; per-merge cap:
100K tokens (ADR-021). Smoke runs are not part of the pre-commit loop and not run
by CI in V1; they are invoked manually before merge to `main`.

**Run locally:**

```bash
bats tests/smoke/
```

Smoke harnesses inside the bats files read per-run token cost and exit non-zero on
cap breach (ADR-021).

## Dependency

`bats-core` is a soft dependency of this template — only required to run Tier 1
tests locally. Install via:

- macOS: `brew install bats-core`
- Linux: `sudo apt-get install bats` or follow [bats-core install](https://bats-core.readthedocs.io/)

The orchestrator and helpers themselves have no runtime dependency on bats.
