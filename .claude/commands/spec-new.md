---
description: Scaffold a new phase spec from the template
argument-hint: <phase-number> [--force]
---

The user wants to start a new spec for phase $ARGUMENTS.

**Parse $ARGUMENTS:**
- The phase number is the first non-flag token (e.g. `01`).
- The flag `--force` (anywhere in $ARGUMENTS) is the explicit override for the existence check.

Refer to the parsed phase number as `<NN>` below.

Steps:

1. Read `specs/_template.md` and `ROADMAP.md`.

2. **Existence check — refuse to overwrite without `--force`.**
   - If `specs/phase-<NN>.md` does **not** exist → continue to step 3.
   - If `specs/phase-<NN>.md` **exists and `--force` was NOT passed** → STOP. Refuse. Show the user:
     - The existing file's `status:` from the frontmatter
     - The most recent commit that touched it (`git log --oneline -1 -- specs/phase-<NN>.md`)
     - These three options:
       1. Run `/resume` to orient on the in-flight phase
       2. Edit the spec directly (Edit tool — file is always allowed by the hook)
       3. Re-run with `/spec-new <NN> --force` to overwrite — **this loses any uncommitted spec content**
     - Do not proceed under any circumstance without `--force`.
   - If `specs/phase-<NN>.md` **exists and `--force` WAS passed** →
     - Read the file. Summarize what's in it: status, which sections have content beyond the `(to be filled)` placeholder, last commit timestamp.
     - Ask the user one final confirmation: "Confirm overwrite of phase-<NN>.md? This will replace its contents with a fresh template."
     - Only proceed if the user explicitly says yes / confirm / overwrite. "ok" alone is insufficient — ask again.

3. Create `specs/phase-<NN>.md` from the template. Pre-fill:
   - `phase: <NN>`
   - `created:` today's date
   - `title:` derived from the per-phase block heading in ROADMAP.md (the line `### Phase <NN> — <title>`). If the heading isn't there or is unclear, ask the user for the title.

4. Walk the user through the spec **one section at a time** — never ask for everything at once. The order matches the template:
   1. **Goal** (1–2 sentences)
   2. **Non-goals** (the "we are NOT doing X this phase" list — this section reduces drift more than any other)
   3. **Background** (why this phase, what it depends on, what comes after — link to ROADMAP and prior specs)
   4. **Design — Decisions & rationale** (prose technical approach: AWS / k8s resources, key config choices and reason for each)
   5. **Design — Architecture** (Mermaid `flowchart` of cumulative system state at end of phase, with new components highlighted)
   6. **Design — Request flow** (Mermaid `sequenceDiagram` of a representative request through the system)
   7. **Design — Failure-mode notes** (per *new* component: symptom / blast radius / mitigation — this is the highest-value section for SRE muscle)
   8. **Validation** (observable, checkable conditions — not "looks fine")
   9. **Rollback / undo** (concrete revert steps)
   10. **Comprehension checkpoints** (things the user should be able to explain unprompted at end of phase)
   11. **Open questions** (must be resolved before status: approved)

5. After each section the user answers, write it into the file and confirm before moving on. Apply the comprehension-question rotation from CLAUDE.md if a section introduces a new concept (especially during Design and Failure-mode notes).

6. **Do not mark `status: approved`** without an explicit "approved" or "go" from the user.

7. **Do not start implementation** in this command. This command produces only the spec.

8. Update the **STATUS** section at the top of `ROADMAP.md`:
   - "Current phase" = `$ARGUMENTS — <title> (drafting spec)`
   - "Last updated" = today's date

9. End by reminding the user: spec is in `draft`; review it, then say "approved" to lock it. After that, the next `Write`/`Edit` to infra/app code will trigger the PreToolUse hook and bump the spec to `in-progress`.
