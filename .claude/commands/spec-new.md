---
description: Scaffold a new phase spec from the template
argument-hint: <phase-number>
---

The user wants to start a new spec for phase $ARGUMENTS.

Steps:

1. Read `specs/_template.md` and `ROADMAP.md`.
2. If `specs/phase-$ARGUMENTS.md` already exists, stop and ask the user whether to open it for editing or overwrite. Do not silently overwrite.
3. Create `specs/phase-$ARGUMENTS.md` from the template. Pre-fill `phase`, `created` (today's date), and the title from ROADMAP.md if it can be inferred.
4. Then walk the user through the spec one section at a time — **never ask for everything at once**:
   a. Goal (1–2 sentences)
   b. Non-goals (the "we are NOT doing X this phase" list)
   c. Initial design sketch (rough — bullet points of what gets created/changed)
   d. Validation checklist (how we'll know it worked)
   e. Rollback plan
   f. Comprehension checkpoints (what the user should be able to explain at end)
   g. Any open questions

5. After each section the user answers, write it into the file and confirm before moving on. Apply the comprehension-question rotation from CLAUDE.md if a section introduces a new concept.

6. **Do not mark `status: approved`** without an explicit "approved" or "go" from the user.

7. **Do not start implementation** in this command. This command produces only the spec. Implementation begins after approval, in a separate session.

8. End by reminding the user: spec is in `draft`; review it, then say "approved" to lock it.
