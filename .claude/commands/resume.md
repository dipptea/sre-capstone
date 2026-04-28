---
description: Orient at the start of a fresh session — read-only summary of where you are
---

The user just opened a fresh session and wants to know where they are in the capstone. This command is read-only — do not modify any files.

Steps:

1. Read `ROADMAP.md` and extract the **STATUS** section (Current phase, Last completed phase, Last updated).

2. Identify the active spec from STATUS's "Current phase" — match by phase number to `specs/phase-NN.md`. Read it. Note the `status:` field and any `blocker:` or `abandoned_reason:` fields.

3. Run `git log --oneline -10` and `git status` to see recent activity. **Pay attention to uncommitted work** — staged but uncommitted changes mean prior work didn't reach a good stopping point.

4. **Quick framework health check** (so silent failures don't compound across sessions):
   - Confirm `.claude/settings.json` exists and registers the PreToolUse hook for Write/Edit.
   - Confirm `.claude/hooks/check-spec-status.py` exists and is readable.
   - Scan `specs/phase-*.md` for inconsistent state: zero or multiple files with `status: in-progress` is suspicious; flag it.
   - If any of the above is off, surface it loudly at the top of the report and suggest `/check-framework` for a full diagnosis. Do not silently continue.

5. If `lessons.md` has entries, read the most recent 1–2.

6. If `DECISIONS.md` has open decisions, note them.

7. Read `INVENTORY.md`. Note the cumulative monthly cost and the date of last update — surface in the report so the user is aware of what's running and what it's costing.

8. Produce a structured report with these sections (use clear markdown headers):
   - **🚧 Blocker** (only if active spec has `status: blocked` and a `blocker:` field): show the blocker prominently *at the top* — this is the first thing the user should see. Suggest the user resolve it before doing anything else.
   - **⚠️ Uncommitted work** (only if `git status` shows staged or modified files): list the files; warn that prior work didn't commit cleanly.
   - **⚠️ Framework health** (only if step 4 found issues): list each issue.
   - **Where you are**: phase number + title, spec status (`draft` / `approved` / `in-progress` / `blocked` / `done` / `abandoned`), days since last commit
   - **Currently running (from INVENTORY.md)**: cumulative monthly cost + last-updated date. If older than 14 days while a spec is `in-progress` or `done`, flag the inventory as possibly stale.
   - **Recent commits**: last 5 from `git log --oneline`
   - **Active spec status**:
     - If `draft`: list which sections are still `(to be filled)` — this tells the user what's left to reach `approved`
     - If `approved`: list the Validation checklist items not yet ticked, and the design items not yet implemented (compare spec Design against committed code)
     - If `in-progress`: same as approved, plus a one-line "what was the last meaningful step from the commits", plus milestones progress from the Implementation outline (✅ done / 🔄 in-progress / ⏳ not-started per milestone)
     - If `blocked`: show the blocker (already at top) and the milestones progress so the user remembers where they paused
     - If `done`: suggest `/spec-new <NN+1>` for the next phase
     - If `abandoned`: skip to next phase suggestion; do not surface as active work
   - **Open decisions** (from DECISIONS.md, only if any unresolved): one bullet each
   - **Open questions** (from active spec, only if any unresolved): one bullet each
   - **Suggested next action**: ONE concrete sentence (not a paragraph)

9. Ask **one** warm-up comprehension question from the CLAUDE.md rotation. Weight toward Predict or Failure-mode. Subject = the most recent meaningful step (from the latest commit message or the spec's most recent Decision-log entry). The point is to confirm the prior context is in the user's head before continuing.

10. Wait for the user's answer before doing anything else. Do not auto-continue with implementation.
