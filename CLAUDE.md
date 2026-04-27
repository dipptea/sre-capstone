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
   - `ARCHITECTURE.md` is updated to reflect the new cumulative system state
   - User can explain the phase aloud in 60 seconds without notes
   - User can redraw the architecture diagram from memory (no peeking at the spec)

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

## Spec lifecycle

`draft` → `approved` → `in-progress` → `done`

State transitions:
- **draft → approved**: when the user explicitly says "approved" / "go" on a draft spec, flip the frontmatter `status:` to `approved`. Never flip without that explicit signal.
- **approved → in-progress**: flip the moment implementation begins (first edit to a `.tf`, `.yaml`, source file, etc., for that phase). The PreToolUse hook will block such edits if no spec is `approved` or `in-progress`.
- **in-progress → done**: only via `/phase-close NN`, which runs the full close gate.

## Per-phase workflow

1. `/spec-new NN` to scaffold the spec
2. Fill in Goal, Non-goals, Background, Design (all 4 sub-sections), Validation, Rollback, Comprehension checkpoints
3. User marks `status: approved`
4. Implement step by step, with comprehension questions at each meaningful step
5. Run `/spec-check` periodically to verify alignment
6. On phase close: run `/phase-close NN` (handles runbook + lessons + ARCHITECTURE check, verbal & visual recall, status flip, commit)

## Slash commands

- `/spec-new NN` — scaffold a phase spec
- `/spec-check` — verify current work against active spec, surface drift, probe comprehension
- `/phase-close NN` — gate command; refuses to close a phase that isn't done
- `/resume` — orient at the start of a fresh session (read-only summary of where you are)

## Enforcement

There is a PreToolUse hook at `.claude/hooks/check-spec-status.py` that blocks `Write`/`Edit` to infra/app code (`.tf`, `.yaml`, `.py`, `.js`, `.ts`, `.go`, `Dockerfile`, etc.) unless a spec is `approved` or `in-progress`. Doc/framework files (anything in `specs/`, `.claude/`, plus `README.md`, `CLAUDE.md`, `ROADMAP.md`, `ARCHITECTURE.md`, `DECISIONS.md`, `runbook.md`, `lessons.md`) are always allowed.

If the hook misfires, comment out the entry in `.claude/settings.json` — but first investigate why. The hook is the harness's only real enforcement of the spec-first rule.

## Anti-patterns to avoid

- Generating large blocks of code without naming what each piece does and why
- "Just run this" with no concept attached
- Skipping the comprehension question because the step "felt obvious"
- Letting the user paste Claude's words into `runbook.md` / `lessons.md` instead of writing their own
- Adding scope to the spec mid-phase without logging the decision
- Treating Validation checklist items as ticked when they're only "probably fine"
