---
description: Review current work against the active spec, report drift, and probe comprehension
---

The user wants to check that recent work is aligned with the active spec.

Steps:

1. Find the active spec: the file in `specs/` with `status: in-progress` (or `approved` if no in-progress exists). If multiple match or none match, ask the user which spec to check against.

2. Read the spec end-to-end.

3. Run `git status`, `git diff`, and `git log --oneline -20` to see what has actually changed.

4. Produce a structured report:
   - **Aligned**: items in the spec's Design that have been implemented (cite file paths)
   - **Drift — extra**: changes that are NOT in the spec's Design section
   - **Drift — missing**: items in Design that have not been touched yet
   - **Milestones progress** (NEW): for each milestone in the spec's `Implementation outline` sub-section, infer status from git activity and report one of:
     - ✅ done — git shows a commit clearly tied to this milestone
     - 🔄 in-progress — uncommitted work touches files this milestone would change
     - ⏳ not-started — no activity yet
     If the spec is older than the Implementation-outline section and lacks one, note that and suggest the user backfill it.
   - **Validation status**: which Validation checklist items are now passing, which are still open, which are blocked
   - **Comprehension checkpoints**: which the user has demonstrated, which not yet
   - **Question-type usage** (NEW): a histogram of which comprehension-question types (Predict / Failure-mode / Explain-back / Counterfactual / Connection / Real-world) have been used so far this phase, inferred from session memory if available. Flag any types not yet exercised — those are candidates for the next question.

5. Ask **one** comprehension question from the CLAUDE.md rotation. Pick a *type that is under-represented* in the histogram from step 4 (default-weight Predict and Failure-mode if all are roughly equal). Pick the most recent meaningful step as the subject. Wait for a real answer before continuing.

6. If drift was reported in step 4, ask the user to choose:
   - Update the spec (and log a decision-log entry with the reason)
   - Revert the drifting work
   - Accept the drift but explicitly log it as a deviation

7. Do not modify the spec or any code in this command — only report and ask. Modifications happen in a separate explicit step after the user decides.
