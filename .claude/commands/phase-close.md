---
description: Close a phase — verify deliverables, run verbal + visual recall, mark spec done, update STATUS
argument-hint: <phase-number>
---

The user wants to close phase $ARGUMENTS. This command is the gate, not a celebration — refuse to close a phase that isn't actually done.

Steps:

1. Read `specs/phase-$ARGUMENTS.md`. If `status:` is not `in-progress`, ask the user to confirm before continuing (might be a typo).

2. Run `git status` and `git diff` and `git log --oneline` since the phase started, to see what was actually done.

3. Walk through the spec's **Validation** checklist with the user, item by item. For each:
   - Ask: "is this passing right now? evidence?"
   - If unclear or "probably," **stop**. The phase isn't done.
   - Tick the box only when there's concrete evidence.

4. Verify these docs were updated *for this phase*:
   - `runbook.md` — has a section for this phase, written in user's own words (not pasted from Claude)
   - `lessons.md` — has at least one entry for this phase
   - `ARCHITECTURE.md` — diagram and last-updated line reflect new cumulative state
   If any are missing, stop and ask the user to update before continuing.

5. **Verbal explanation gate.** Ask the user to explain — out loud, to themselves or a recorder — what was built in this phase and why each piece exists, in 60 seconds, without notes. Then ask them to type back ONE sentence summarizing it. The type-back proves the verbal happened and reinforces it.

6. **Redraw-from-memory gate.** Ask the user to draw the architecture diagram on paper or in a fresh blank file, without looking at the spec or `ARCHITECTURE.md`. Ask them to confirm they did it. If they say "no" or "later," stop and surface what feels unclear — that's the gap.

7. Update spec frontmatter: `status: in-progress` → `status: done`.

8. Update the **STATUS** section at the top of `ROADMAP.md`:
   - "Last completed phase" = this phase
   - "Current phase" = next pending phase (or "—" if this was the last)
   - "Last updated" = today's date

9. Show the user a one-line summary of what's about to be committed and ask them for the commit message (one sentence, focus on the *why*, not the *what*). Then stage all changes, commit, and push.

10. End by suggesting `/spec-new <NN+1>` to scaffold the next phase, or congratulate them and stop here if this was the last phase.

**Refuse** to skip steps 3, 4, 5, or 6 even if the user pushes. The whole point of this command is that closing a phase requires the work to actually be done.
