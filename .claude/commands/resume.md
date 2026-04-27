---
description: Orient at the start of a fresh session — read-only summary of where you are
---

The user just opened a fresh session and wants to know where they are in the capstone. This command is read-only — do not modify any files.

Steps:

1. Read `ROADMAP.md` and extract the **STATUS** section (Current phase, Last completed phase, Last updated).

2. Identify the active spec from STATUS's "Current phase" — match by phase number to `specs/phase-NN.md`. Read it.

3. Run `git log --oneline -10` and `git status` to see recent activity.

4. If `lessons.md` has entries, read the most recent 1–2.

5. If `DECISIONS.md` has open decisions, note them.

6. Produce a structured report with these sections (use clear markdown headers):
   - **Where you are**: phase number + title, spec status (`draft` / `approved` / `in-progress` / `done`), days since last commit
   - **Recent commits**: last 5 from `git log --oneline`
   - **Active spec status**:
     - If `draft`: list which sections are still `(to be filled)` — this tells the user what's left to reach `approved`
     - If `approved`: list the Validation checklist items not yet ticked, and the design items not yet implemented (compare spec Design against committed code)
     - If `in-progress`: same as approved, plus a one-line "what was the last meaningful step from the commits"
     - If `done`: suggest `/spec-new <NN+1>` for the next phase
   - **Open decisions** (from DECISIONS.md, only if any unresolved): one bullet each
   - **Open questions** (from active spec, only if any unresolved): one bullet each
   - **Suggested next action**: ONE concrete sentence (not a paragraph)

7. Ask **one** warm-up comprehension question from the CLAUDE.md rotation. Weight toward Predict or Failure-mode. Subject = the most recent meaningful step (from the latest commit message or the spec's most recent Decision-log entry). The point is to confirm the prior context is in the user's head before continuing.

8. Wait for the user's answer before doing anything else. Do not auto-continue with implementation.
