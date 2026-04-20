# Fix 7 Orphan Decision Records

> **Context for a fresh session:** The `adr-crossref-check` skill (see `.claude/skills/adr-crossref-check/SKILL.md`) surfaced 7 ADR/LOG files in `.specify/memory/` with zero inbound references from `specs/**/*.md`. Principle VII (Decision Transparency, NON-NEGOTIABLE) requires bidirectional cross-references. This plan resolves each orphan.

**Goal:** Either add a back-reference from the appropriate spec/plan/tasks artifact, or mark the record superseded/archived via a LOG (UPDATE), for each of the 7 orphans.

**How to verify:** Run `.specify/scripts/bash/check-adr-crossrefs.sh` — expect exit 0 and "OK: all records have at least one reference..." when done.

**Relevant skills:**
- `adr-crossref-check` — diagnostic
- `writing-decision-records` — how to author back-references and the consuming-artifact `## Decision Records` table format

---

## The 7 Orphans

For each record below: read the file, identify which feature (specs/###-*/) it belongs to, and either (a) add an entry in that feature's spec.md / plan.md / tasks.md under a `## Decision Records` table, or (b) if the record is obsolete, write a new LOG (UPDATE) that supersedes it and cross-references both.

- [ ] **ADR_052_component-model-manifest**
  - File: `.specify/memory/ADR_052_component-model-manifest.md`
  - Likely owner: feature `008-auto-sync-staleness` (recent merge; retro commit `253no3c` mentions ADR-052)
  - Action: verify in 008's spec.md/plan.md, add to Decision Records table

- [ ] **LOG_014_filter-parameter-naming-drift**
  - File: `.specify/memory/LOG_014_filter-parameter-naming-drift.md`
  - Action: read the LOG; trace the feature it was raised against (check `Raised In` field if present, else grep specs/ for the filter parameter names referenced)

- [ ] **LOG_015_unimplemented-error-codes**
  - File: `.specify/memory/LOG_015_unimplemented-error-codes.md`
  - Action: same as above

- [ ] **LOG_016_claude-md-placeholder-text**
  - File: `.specify/memory/LOG_016_claude-md-placeholder-text.md`
  - Likely owner: CLAUDE.md itself, not a spec — consider adding reference from `CLAUDE.md` or closing as resolved

- [ ] **LOG_031_codereview-005-fast-follows**
  - File: `.specify/memory/LOG_031_codereview-005-fast-follows.md`
  - Likely owner: feature `005-sync-stale-cleanup` (name suggests it)

- [ ] **LOG_052_memory-store-no-ensure-init**
  - File: `.specify/memory/LOG_052_memory-store-no-ensure-init.md`
  - Likely owner: feature `006-ollama-fallback` (touches `_ensure_init`) or `008-auto-sync-staleness`

- [ ] **LOG_054_gate-enforcement-convention-risk**
  - File: `.specify/memory/LOG_054_gate-enforcement-convention-risk.md`
  - Context: connects to ADR-051 constitution memory gate work on 2026-04-18; likely owner is feature where that gate was wired (check commits touching speckit.plan/review/audit)

---

## Per-record procedure

1. `cat .specify/memory/<record>.md` — read header fields, especially `Raised In` / `Decision Made In`.
2. `grep -l "<subject keywords>" specs/*/spec.md specs/*/plan.md specs/*/tasks.md` — find the consuming artifact.
3. In the consuming artifact, under `## Decision Records`, add a row:
   ```markdown
   | ADR-NNN | <title> | <type> | <status> | [ADR_NNN](.specify/memory/ADR_NNN_<slug>.md) |
   ```
   If the artifact lacks a Decision Records section, add one under the highest-level heading that makes sense (see `writing-decision-records` skill for placement guidance).
4. Commit per record or batch by feature.
5. After all 7 resolved: `.specify/scripts/bash/check-adr-crossrefs.sh` should exit 0.

---

## Commit strategy

One commit per feature (not per record) — some records likely share a feature. Commit message: `docs(memory): add back-references for orphan ADR/LOGs (###)` naming the feature number.

## Completion check

Final step before closing this task:
```bash
.specify/scripts/bash/check-adr-crossrefs.sh; echo "exit:$?"
```
Must print `OK: all records have at least one reference from specs/` and `exit:0`.
