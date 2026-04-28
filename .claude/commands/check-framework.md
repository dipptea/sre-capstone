---
description: Verify the framework itself is healthy — hook registered, specs in consistent state, INVENTORY fresh
---

The user wants to verify the framework's enforcement and state machinery is intact. This command is read-only — it only reports, it does not fix.

Run when something feels off (a Write/Edit went through that shouldn't have, `/resume` flagged a problem, or before starting a new phase after a long break).

Steps:

1. **Hook registration check.**
   - Read `.claude/settings.json`. Confirm there is a `hooks.PreToolUse` entry that matches `Write|Edit` and runs `python3 $CLAUDE_PROJECT_DIR/.claude/hooks/check-spec-status.py`.
   - If missing or malformed, report it as **CRITICAL** — the spec-first rule is unenforced.

2. **Hook file check.**
   - Confirm `.claude/hooks/check-spec-status.py` exists.
   - Confirm it is readable. (Permission to execute is determined by the harness invocation; readability is sufficient signal here.)
   - Read the first 30 lines and confirm it parses as Python (no syntax error in the shebang/imports area).

3. **Spec state consistency.**
   - List every file matching `specs/phase-*.md`. For each, parse the `status:` from frontmatter.
   - Report:
     - Count of `draft`, `approved`, `in-progress`, `blocked`, `done`, `abandoned` specs.
     - **Inconsistencies** (any of these is a finding):
       - More than one spec with `status: in-progress` (only one phase should be active at a time).
       - A spec with `status: blocked` but no `blocker:` field — incomplete state.
       - A spec with `status: abandoned` but no `abandoned_reason:` field.
       - A spec with `status: draft` whose phase number is *less than* the latest `done` spec's phase number — possibly a stranded older draft.
       - A spec whose phase number does not match its filename (e.g., `phase-03.md` with `phase: 02` in frontmatter).

4. **ROADMAP STATUS consistency.**
   - Read the STATUS section of `ROADMAP.md`.
   - Confirm "Current phase" matches the phase whose spec is `approved` or `in-progress` (or `draft` if no spec is approved yet).
   - Confirm "Last completed phase" matches the highest-numbered spec with `status: done`.
   - Report any mismatch — STATUS is human-edited and drifts.

5. **INVENTORY freshness.**
   - Read `INVENTORY.md`. Find the "Last updated" line.
   - If older than 14 days AND any spec is `in-progress` or `done`, flag the inventory as possibly stale.
   - If `INVENTORY.md` is missing entirely, flag as **CRITICAL** — no budget safety net.

6. **ARCHITECTURE.md alignment.**
   - Read `ARCHITECTURE.md`'s "Last updated" line.
   - If a spec is `done` and was closed *after* `ARCHITECTURE.md`'s last-updated date, the diagram is behind — flag it.

7. **Produce a structured report.** Group findings by severity:
   - **CRITICAL** — enforcement is off (hook missing, INVENTORY missing). Surface first.
   - **WARNING** — state is inconsistent (spec mismatches, stale INVENTORY, diagram behind).
   - **INFO** — counts and a one-line "framework looks healthy" if all checks pass.

8. End with a one-line **Recommended action** if any findings exist. Do not modify any files in this command — recommend the next step (e.g., "edit `ROADMAP.md` STATUS line to match phase-04.md", "run /phase-close 03 to update ARCHITECTURE.md") and stop.

Do not ask a comprehension question in this command — `/check-framework` is a maintenance check, not a learning step.
