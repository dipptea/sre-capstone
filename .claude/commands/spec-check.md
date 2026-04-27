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
   - **Validation status**: which Validation checklist items are now passing, which are still open, which are blocked
   - **Comprehension checkpoints**: which the user has demonstrated, which not yet

5. Ask **one** comprehension question from the CLAUDE.md rotation. Weight toward Predict or Failure-mode. Pick the most recent meaningful step as the subject. Wait for a real answer before continuing.

6. If drift was reported in step 4, ask the user to choose:
   - Update the spec (and log a decision-log entry with the reason)
   - Revert the drifting work
   - Accept the drift but explicitly log it as a deviation

7. Do not modify the spec or any code in this command — only report and ask. Modifications happen in a separate explicit step after the user decides.
