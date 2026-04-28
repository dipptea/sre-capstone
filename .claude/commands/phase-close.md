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

4. Verify these docs were updated *for this phase*. For each, read the file and check:
   - **`runbook.md`** — has a section for this phase, written in user's own words (not pasted from Claude). If missing, stop and ask the user to write it now in their own words.
   - **`lessons.md`** — has at least one entry for this phase. **The entry must follow the declared format** with all three field headers: `**What I did:**`, `**What surprised me / what I got wrong:**`, `**How I'd explain it to a peer:**`. If missing entirely, stop and prompt: "what's the one thing from this phase you'd struggle to explain to a peer? write that down using the three-field format." If an entry exists but skips fields, point out which fields are missing and ask the user to fill them in — *do not fill them in for them*.
   - **`scratch.md` review (offered, not gated)** — read `scratch.md`. If it has entries dated within this phase, summarize them and ask the user: "Anything in scratch you want to promote into lessons.md as a proper three-field entry?" If they say yes, walk them through promoting (they write the new entry; you do not). Either way, this is offered help, not a gate — the phase can close with scratch unchanged.
   - **`ARCHITECTURE.md`** — diagram and "Last updated" line reflect the new cumulative state. If not updated:
     a. Read the active spec's `Architecture (delta this phase)` section.
     b. Show it to the user as a starting point.
     c. Walk them through merging it into ARCHITECTURE.md's "Current state" diagram (preserving prior phases' components, adding this phase's).
     d. Update the "Last updated" line to today's date with a one-line summary of what changed.
     e. Confirm with the user before saving.
   - **`INVENTORY.md`** — has the new resources from this phase listed, with monthly cost estimates, region/account, and the exact teardown command. Cumulative monthly cost line is updated. If a resource was *removed* this phase, mark it as torn down and date it. If `INVENTORY.md` is missing or stale (older than this phase's start commit), stop and walk the user through filling it in — this is the budget-safety net.

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

The lessons.md format check (step 4) and INVENTORY.md check (step 4) are also non-negotiable. A lessons entry that skips fields is a vibes entry, not a retrievable one. An un-updated INVENTORY is a slow-leaking budget.
