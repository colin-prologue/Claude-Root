# Speckit Command Optimization Recommendations

**Generated**: 2026-04-20
**Scope**: `.claude/commands/speckit.*.md` (16 files, 3,994 LOC total)
**Evaluated against**: skill-creator best practices (progressive disclosure, lean prompts, explain-why, avoid rigid MUSTs, bundle repeated work)
**Status** (by "Recommended Execution Order" numbering below):

- ✅ Done — steps 1–6 (extension hooks, quote-escape, `## Context` trim, ignore-patterns template, ADR gate unified to CRITICAL, memory-gate shortening). Committed to `skill-plugin-optimization` as `1147861`, not yet pushed.
- ⏭ Deferred — step 7 (tone pass on MUST/NEVER/NON-NEGOTIABLE, a.k.a. "Highest-Impact #3"). Intentionally split to a follow-up branch for passage-by-passage review.
- 💤 Not started — steps 8 (constitution calibration → script) and 9 (brainstorm Round prompts → agent definitions). Optional larger refactors.

---

## Overall Verdict

The speckit command system is mature and coherent. Workflow chain (brainstorm → constitution → specify → clarify → plan → tasks → implement → review/audit/retro) is well thought out. Memory gate semantics are correct. `.specify/templates/` and `.specify/scripts/` already implement progressive disclosure properly.

The meaningful opportunities are three: eliminate dead code, factor cross-command duplication, and tone down rigid MUST/NEVER prose where the *why* already carries the load.

---

## File Sizes (for reference)

| File | Lines |
|---|---|
| speckit.brainstorm.md | 470 |
| speckit.constitution.md | 361 |
| speckit.review-profile.md | 341 |
| speckit.checklist.md | 295 |
| speckit.review.md | 265 |
| speckit.audit.md | 264 |
| speckit.init.md | 263 |
| speckit.specify.md | 260 |
| speckit.retro.md | 240 |
| speckit.codereview.md | 239 |
| speckit.implement.md | 218 |
| speckit.analyze.md | 218 |
| speckit.tasks.md | 208 |
| speckit.clarify.md | 208 |
| speckit.plan.md | 114 |
| speckit.taskstoissues.md | 30 |

---

## Highest-Impact Issues

### 1. Dead-code extension hooks (~125 lines wasted per invocation)

**What**: `speckit.tasks.md` and `speckit.implement.md` contain large "Extension Hooks" blocks (before + after) that check for `.specify/extensions.yml`.

**Evidence**: Confirmed `.specify/extensions.yml` does NOT exist in this repo.

- `speckit.implement.md` lines 15-45 (before) + lines 191-218 (after) ≈ 65 lines
- `speckit.tasks.md` lines 24-54 (before) + lines 105-132 (after) ≈ 60 lines

**Fix options** (pick one):
- **(A) Delete entirely** if extension hooks aren't a live feature.
- **(B) Factor into `.specify/scripts/bash/check-extension-hooks.sh`** that silently no-ops when YAML is absent. Replace the prose block with one-line invocations in each command.

Recommendation: Option B if extension hooks are planned future infrastructure, Option A if they're vestigial.

---

### 2. Duplicated boilerplate across commands (~200 lines saved)

| Duplication | Occurrences | Fix |
|---|---|---|
| Single-quote escape instruction (`'I'\''m Groot'`) | 10 files verbatim | Move to `common.sh` output/help, or reference `.claude/rules/` once. ~150 chars × 10 = ~1500 chars. |
| Memory gate parse-constitution front-matter prose | plan.md, review.md, audit.md | The canonical version already lives in `.claude/rules/memory-convention.md`. Shorten each command to: "Apply memory gate per `memory-convention.md`; on enabled, call `memory_recall('<query>')`." |
| `## Context\n\n$ARGUMENTS` trailing block | ~7 files (brainstorm, analyze, audit, review, retro, clarify, codereview) | Redundant with `## User Input` block at top. Delete trailers. |
| ADR gate check | plan, tasks, implement, analyze (different severities!) | Define ONE canonical "ADR gate" spec; have each command cite it. Current inconsistency: `tasks.md` WARNING vs `implement.md` CRITICAL for the same gap — decide and unify. |
| `## User Input` + "You MUST consider the user input" line | ~14 files | Candidate for `.claude/rules/` or deletion — the `$ARGUMENTS` context is obvious. |

---

### 3. All-caps ALWAYS/NEVER/NON-NEGOTIABLE overuse

**Skill-creator red flag** (verbatim from the skill): *"If you find yourself writing ALWAYS or NEVER in all caps, or using super rigid structures, that's a yellow flag."*

**Heaviest offenders**:
- `speckit.implement.md`: "NON-NEGOTIABLE" (×3), "REQUIRED" (×4), "CRITICAL", "STOP"
- `speckit.tasks.md`: "CRITICAL", "MUST" (×6), "REQUIRED", "ALWAYS", "NEVER"
- `speckit.brainstorm.md`: "NEVER evaluate", "ALWAYS wait", "MUST NOT be mixed"
- `speckit.review.md`: "CRITICAL", "Do NOT" (×3)

**Rule of thumb**: Where surrounding prose already explains the reasoning (e.g., "divergence protects creativity", "TDD protects against wrong assumptions"), the all-caps directive is dead weight and trains the model to filter it out. Keep caps only for truly catastrophic violations (security, data loss).

**Pass**: Go through and soften ~70% of the MUSTs. Keep the ones where the why is thin or the stakes are genuinely high.

---

## Medium-Impact Issues

### 4. `speckit.constitution.md` calibration logic should be code

Lines 121-188 encode a deterministic decision table (21 answers → 8 rigor levels). The LLM re-derives it from scratch each invocation, with drift risk.

**Fix**: Move to `.specify/scripts/bash/calibrate.sh` taking 21 answers and emitting rigor levels as JSON. Faster, testable, cheaper. The prompt just invokes the script and presents results.

---

### 5. `speckit.implement.md` ignore-patterns table is reference material

Lines 111-132 list ~15 technologies × their ignore patterns. Always loaded, rarely all-needed.

**Fix options**:
- Move to `.specify/references/ignore-patterns.md` and load on demand from the command
- Or fold into a deterministic helper `.specify/scripts/bash/ensure-ignores.sh`

---

### 6. `speckit.brainstorm.md` at 470 lines is borderline

The four Round prompts (lines 164-210) duplicate framing that lives in the persona agents (visionary, user-advocate, technologist, provocateur).

**Fix**: Let agents own their framing. Command just says "spawn the four brainstorming agents sequentially with [shared problem statement + prior art]". Saves ~40 lines.

---

## Smaller Improvements

- **`speckit.checklist.md`** (295 lines): wrong/correct examples repeat in three places (Purpose, Anti-Examples, Examples by Dimension). Collapse to one canonical table. Saves ~60 lines.
- **`speckit.analyze.md` vs `speckit.audit.md`**: audit is a superset of analyze. `analyze` could be much thinner, or they could share an internal detection pass definition.
- **ADR gap check severity drift**: `speckit.tasks.md` line 72 says WARNING, `speckit.implement.md` line 139 says CRITICAL for the same condition. Decide and unify.
- **`speckit.codereview.md` line 115**: `security-reviewer` scope guidance is embedded in the prompt; could live in the agent definition instead.

---

## Token-Savings Summary (estimated)

| Fix | Lines Saved |
|---|---|
| #1 Extension hooks removal | ~125 |
| #2 Quote-escape to shared rule | ~100 (across 10 files) |
| #2 Trailing `## Context` trim | ~28 |
| #2 Memory gate shortening | ~15 |
| #2 ADR gate consolidation | ~30 |
| #5 Ignore-patterns to script | ~20 |
| #6 Brainstorm Round prompts | ~40 |
| #3 MUST/NEVER tone pass | ~30-50 (across many files) |
| **Total** | **~390-410** |

That's ~10% reduction with better maintainability and no feature loss.

---

## Things Done Well (Keep)

- `handoffs` frontmatter — clean pattern, makes chaining explicit
- Memory gate semantics (best-effort, fail silently) — correctly captured in `memory-convention.md` ✓ matches ADR-051
- Anti-convergence three-phase review protocol — excellent WHY explanation
- Rigor calibration by gate (benchmark-validated, ADR-007 sourced)
- Template separation — `.specify/templates/` loads only on demand
- Bash script extraction — `check-prerequisites.sh`, `create-new-feature.sh`, `setup-plan.sh`, `common.sh`

---

## Recommended Execution Order

If proceeding, apply in this order (easiest/biggest-win first):

1. **Decide on extension hooks** — delete (if vestigial) or move to script. Biggest single win, purely mechanical.
2. **Shorten quote-escape line** — move to shared rule, one-line reference from each command.
3. **Trim trailing `## Context` blocks** — mechanical grep-and-remove.
4. **Move ignore-patterns to script** — refactor.
5. **Unify ADR gate severity** — decide WARNING vs CRITICAL; apply.
6. **Shorten memory-gate inline prose** — reference rules file.
7. **Tone-pass the MUSTs/NEVERs** — judgment-heavy, do last with human review.
8. **(Optional)** Factor constitution calibration into script.
9. **(Optional)** Factor brainstorm Round prompts into agent definitions.

Steps 1-6 are mechanical and can be done in one PR. Step 7 should be a separate PR with passage-by-passage review. Steps 8-9 are bigger refactors worth their own branches.

---

## Context for Next Session

Spec-kit commands are actually slash commands (`.claude/commands/*.md`), not skills (`.claude/skills/*.md`). Skill-creator best practices still apply (they're about prompt quality), but the triggering/description concerns from skill-creator don't — slash commands are invoked explicitly, not auto-triggered.

Current branch: `skill-plugin-optimization`
No prior commits on this branch related to these changes — clean slate for whichever fixes you choose to apply.
