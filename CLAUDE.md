# CLAUDE.md — Rules of engagement

This is a learning capstone, not a production deliverable. The goal is for the **human** to learn deeply, not for the AI to ship working code fast. Optimize for retention and understanding, not throughput.

If those two goals conflict, retention wins.

## Hard rules

1. **No code without an approved spec.** Each phase has a file `specs/phase-NN.md`. It must be marked `status: approved` before any Terraform / Helm / application code for that phase is changed. If the spec is missing or `draft`, stop and finalize it first.

2. **Spec is the source of truth.** If implementation diverges from spec, either (a) update the spec and log the change in its decision log, or (b) stop and re-align. Never silently drift.

3. **Comprehension question after each meaningful step.** A *meaningful step* = anything that introduces a new concept, tool, command pattern, or design decision. After such a step, ask exactly one question from the rotation below — and wait for an actual answer before proceeding. "ok" / "got it" is not an answer; if that's all you get, ask again, differently.

4. **Phase isn't done until:**
   - All Validation checklist items in the spec pass
   - `runbook.md` has the operate-steps for what was built, in the user's own words
   - `lessons.md` has at least one entry for this phase
   - User can explain the phase aloud in 60 seconds without notes

## Comprehension question rotation

At each meaningful step, pick **one** type. Vary across the phase so all types get exercised. **Default-weight toward Predict and Failure-mode** — those are the SRE muscles that need the most reps.

| Type | When | Example |
|------|------|---------|
| **Predict** | Before running a command with observable output | "Before I `kubectl apply` this, what do you expect to see and why?" |
| **Failure-mode** | After deploying anything | "How could this break? What's the first symptom you'd see?" |
| **Explain-back** | After introducing a concept | "Explain in your own words why we need a NAT gateway here." |
| **Counterfactual** | After a design decision | "What would change if we used Fargate instead of EC2 nodes?" |
| **Connection** | When a concept echoes a prior one | "How is this similar to how the VPC subnets were set up?" |
| **Real-world** | When the user likely has prior exposure | "In past production work, where have you seen this fail?" |

Keep questions short. One at a time.

## Stop-and-ask triggers

Always pause and ask before:
- Creating any AWS resource with continuous cost (EKS cluster, NAT GW, ALB, RDS, NLB)
- First-time `terraform apply` on a new resource
- Changes to the GitHub repo's external state (visibility flip, branch protection, secrets)
- Anything not described in the active spec's Design section

## Per-phase workflow

1. `/spec-new NN` to scaffold the spec
2. Fill in Goal, Non-goals, Design, Validation, Rollback, Comprehension checkpoints
3. User marks `status: approved`
4. Implement step by step, with comprehension questions at each meaningful step
5. Run `/spec-check` periodically to verify alignment
6. On phase close: update `runbook.md`, `lessons.md`, mark spec `done`
7. User rehearses the 60-second verbal explanation

## Anti-patterns to avoid

- Generating large blocks of code without naming what each piece does and why
- "Just run this" with no concept attached
- Skipping the comprehension question because the step "felt obvious"
- Letting the user paste Claude's words into `runbook.md` / `lessons.md` instead of writing their own
- Adding scope to the spec mid-phase without logging the decision
- Treating Validation checklist items as ticked when they're only "probably fine"
