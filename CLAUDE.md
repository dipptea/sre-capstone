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

## The Hands rule (who types what)

This is a hybrid loop: Claude scaffolds, the user runs the load-bearing commands. Watching builds shallow understanding; the user's hands on the keyboard build the muscle that holds up under incident pressure.

**User runs:**
- Anything that **changes real state**: `terraform apply`, `kubectl apply`, `helm install` / `upgrade` / `rollback`
- Anything you'd reach for **during an incident**: `kubectl get` / `describe` / `logs` / `exec`, `aws ec2 describe-*`, `dig`, `curl` against a service
- **Verification commands** at the end of each milestone (proves it works to the user, not just to Claude)
- `terraform plan` — diagnostic, but reading a plan is a core SRE muscle
- `git` commits and pushes for the user's own work

**Claude runs (or writes the file, user doesn't touch):**
- File scaffolding: `.tf`, `.yaml`, Dockerfiles, IAM JSON
- One-shot setup that's done once and never again: `terraform init`, `gh repo create`
- Linting / formatting: `terraform fmt`, `yamllint`
- Doc lookups, boilerplate generation, search
- Verbose log greps that don't teach anything

**Heuristic:** if a future incident or job interview would expect the user to do it from memory, the user does it now. Everything else is mechanical and Claude takes it.

### How Claude queues commands for the user

For each implementation milestone, Claude presents the commands the user should run as a small block. For each command:

- The exact command
- One line: what it does
- One line: what to look for / what to expect in the output
- One **Predict** question to answer *before* hitting enter

Then wait for the user to run it and report what they saw. After surprising output: explain it, and use it as the subject of the next comprehension question. Do not move to the next milestone until the user has actually run the verification command for the current one.

## Stop-and-ask triggers

Always pause and ask before:
- Creating any AWS resource with continuous cost (EKS cluster, NAT GW, ALB, RDS, NLB)
- First-time `terraform apply` on a new resource
- Changes to the GitHub repo's external state (visibility flip, branch protection, secrets)
- Anything not described in the active spec's Design section

## Spec lifecycle

```
draft → approved → in-progress → done
                       ↓
                    blocked  (paused, will resume)
                       ↓
                  abandoned  (will not resume)

done → in-progress  (re-opening a closed phase, with gate)
```

State transitions:
- **draft → approved**: when the user explicitly says "approved" / "go" on a draft spec, flip the frontmatter `status:` to `approved`. Never flip without that explicit signal.
- **approved → in-progress**: flip the moment implementation begins (first edit to a `.tf`, `.yaml`, source file, etc., for that phase). The PreToolUse hook will block such edits if no spec is `approved` or `in-progress`.
- **in-progress → blocked**: when work pauses on something out-of-band (AWS quota request, decision pending, life). Set `status: blocked` and add a `blocker:` line in frontmatter explaining what's needed to unblock. `/resume` will lead with this.
- **blocked → in-progress**: when the blocker resolves. Remove the `blocker:` line.
- **draft / approved / in-progress → abandoned**: when the phase will not be completed (scope change, merged into a later phase, deprioritized). Set `status: abandoned`, add a one-line `abandoned_reason:` to frontmatter, and append a final entry to the spec's decision log explaining why. The file stays in `specs/` as historical record — do not delete it.
- **in-progress → done**: only via `/phase-close NN`, which runs the full close gate.
- **done → in-progress (re-open)**: rare. Allowed only when a later phase reveals a defect in this phase's design. Required: append a Decision-log entry stating which later phase surfaced the issue and what's changing; revert ARCHITECTURE.md's "Last updated" line to reflect that the diagram is now in flux. Re-close via `/phase-close NN` as normal.

## The four-mode learning loop

This framework is designed around four learning modes that should all fire each phase. Whenever you adopt this SOP elsewhere, preserve the four:

1. **Watch** — Claude scaffolds the file or generates the boilerplate. You read along, predict, ask clarifying questions. Cheap.
2. **Do** — You run the load-bearing commands (see "Hands rule" above). Your fingers move; your eyes watch real output.
3. **Answer** — At each meaningful step, one comprehension question (rotation above). Default-weight Predict and Failure-mode.
4. **Document** — At phase close, *you* write the runbook + lessons entries in your own words. Not Claude.

Skipping any one of the four hollows out the learning. Watching without doing = passive. Doing without answering = mechanical. Answering without documenting = no retrievable artifact later.

## Decision log: which one goes where

Two logs exist. They serve different scopes:

- **Spec's "Decision log" section** (in each `specs/phase-NN.md`) — decisions *local to that phase*. Mid-phase deviations from the Design section, rationale for a substitution, why a milestone got reordered. Phase-scoped.
- **`DECISIONS.md` at repo root** — decisions that *span phases* or *outlive the phase that made them*. CI tool choice, language choice, module strategy. Cross-phase.

Rule of thumb: if the next phase will need to know about this decision, it goes in `DECISIONS.md`. If it only matters within the current phase, it goes in the spec's decision log.

## Per-phase workflow

1. `/spec-new NN` to scaffold the spec
2. Fill in Goal, Non-goals, Background, Design (all 5 sub-sections), Validation, Rollback, Comprehension checkpoints
3. User marks `status: approved`
4. Implement step by step, with comprehension questions at each meaningful step
5. Run `/spec-check` periodically to verify alignment
6. On phase close: run `/phase-close NN` (handles runbook + lessons + ARCHITECTURE check, verbal & visual recall, status flip, commit)

## Slash commands

- `/spec-new NN` — scaffold a phase spec
- `/spec-check` — verify current work against active spec, surface drift, probe comprehension
- `/phase-close NN` — gate command; refuses to close a phase that isn't done
- `/resume` — orient at the start of a fresh session (read-only summary of where you are)
- `/check-framework` — verify the framework itself is healthy (hook registered, specs in consistent state, INVENTORY fresh). Run when something feels off.

## Enforcement

There is a PreToolUse hook at `.claude/hooks/check-spec-status.py` that blocks `Write`/`Edit` to infra/app code (`.tf`, `.yaml`, `.py`, `.js`, `.ts`, `.go`, `Dockerfile`, etc.) unless a spec is `approved` or `in-progress`. Doc/framework files (anything in `specs/`, `.claude/`, plus `README.md`, `CLAUDE.md`, `ROADMAP.md`, `ARCHITECTURE.md`, `DECISIONS.md`, `INVENTORY.md`, `runbook.md`, `lessons.md`, `scratch.md`) are always allowed.

`scratch.md` is the unfiltered notes bin — freeform, no format enforcement. Use it for half-formed thoughts; promote matured entries to `lessons.md` (which *does* enforce format) at phase close.

The hook also refuses to write any `phase-NN.md` filename outside `specs/`. Phase specs live only in `specs/phase-NN.md` — root-level phase files are rejected to prevent the kind of drift that produced the original `PHASE-01.md` duplicate.

If the hook misfires, comment out the entry in `.claude/settings.json` — but first investigate why. The hook is the harness's only real enforcement of the spec-first rule.

## Borrowing this SOP for other work

The pattern in this repo is portable. To replicate elsewhere (postmortems, design reviews, onboarding plans, change requests at work), keep the same seven primitives:

1. **A template** that names the shape of "good thinking" for the class of work. The template is the thinking, frozen.
2. **A lifecycle state machine** (draft → approved → in-progress → done, plus blocked/abandoned/reopened) so the work has clear transitions.
3. **Slash commands at each transition** — one to start, one to check, one to close, one to orient on resume. Each command is just an SOP-as-markdown.
4. **A mechanical block** (hook, CI check, merge gate, label) that physically prevents skipping the gate under pressure. This is the difference between norm and rule.
5. **Standing docs that accumulate state** across the work (architecture, decisions, inventory, runbook, lessons).
6. **Comprehension questions in a defined rotation** so review isn't shallow rubber-stamp.
7. **The Hands rule** — explicit split between what the AI does and what the human does, so the human builds the muscle that matters.

If any one of these is missing in your other context, that's the first place to install it. The order of installation matters too — start with the template (cheapest), then the gate (highest leverage), then the rest grows naturally.

## Anti-patterns to avoid

- Generating large blocks of code without naming what each piece does and why
- "Just run this" with no concept attached
- Skipping the comprehension question because the step "felt obvious"
- Letting the user paste Claude's words into `runbook.md` / `lessons.md` instead of writing their own
- Adding scope to the spec mid-phase without logging the decision
- Treating Validation checklist items as ticked when they're only "probably fine"
