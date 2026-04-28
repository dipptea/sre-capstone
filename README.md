# Capstone: Multi-Region Payment Platform

Hands-on capstone to rebuild Principal-SRE-level production confidence. Stack: AWS, EKS, Terraform, Helm, Datadog, Jira, GitHub (CI/CD TBD).

## Approach

Build a small skeleton fast, then spend most of the time **breaking and debugging** it. The skill that sticks is debugging muscle memory, not building-from-scratch trivia.

## How we work in this repo

Spec-driven. Every phase begins with a spec under [specs/](specs/) that must be `status: approved` before any code changes. See [CLAUDE.md](CLAUDE.md) for the full rules of engagement, the four-mode learning loop, the Hands rule, and the comprehension-question rotation.

- `/spec-new NN` — scaffold a phase spec (and updates STATUS in ROADMAP.md)
- `/spec-check` — verify current work against the active spec, surface drift, probe comprehension
- `/phase-close NN` — gate: walk validation, verbal + visual recall, mark spec `done`, update STATUS, commit & push
- `/resume` — orient at the start of a fresh session (read-only summary of where you are)
- `/check-framework` — verify the framework itself is healthy (hook registered, specs in consistent state, INVENTORY fresh)

A PreToolUse hook (`.claude/hooks/check-spec-status.py`, registered in `.claude/settings.json`) blocks `Write`/`Edit` to infra/app code unless a spec is `approved` or `in-progress`. Doc/framework files are always allowed.

## Docs in this repo

- [CLAUDE.md](CLAUDE.md) — rules of engagement (spec-first, question rotation, Hands rule, lifecycle, SOP framing for borrowing this elsewhere)
- [ARCHITECTURE.md](ARCHITECTURE.md) — cumulative current system state (updated at end of each phase)
- [ROADMAP.md](ROADMAP.md) — overall scope (slimmed from the original 12-phase plan)
- [DECISIONS.md](DECISIONS.md) — open decisions and log of choices made (cross-phase decisions; phase-local decisions live in each spec's Decision log)
- [INVENTORY.md](INVENTORY.md) — what AWS resources are running, what they cost, how to tear them down
- [specs/_template.md](specs/_template.md) — spec template
- [runbook.md](runbook.md) — operational runbook (how to operate the system), grown as we go
- [lessons.md](lessons.md) — matured learnings, three-field format enforced at phase close
- [scratch.md](scratch.md) — freeform notes bin; no format. Promote entries to `lessons.md` when they mature.

## Constraints

- **Time:** 6–7 hrs/week
- **Budget:** up to ~$5k total acceptable; not a learning constraint. Soft alert at $200/mo, hard cap at $500/mo. See [INVENTORY.md](INVENTORY.md).
- **Goal:** production debugging confidence, not breadth of tools touched

## Borrowing this SOP elsewhere

This repo isn't only a capstone — it's a worked example of a portable spec-driven SOP for using Claude Code on any non-trivial responsibility. The seven primitives that make it work (template, lifecycle, slash commands, mechanical block, standing docs, comprehension rotation, Hands rule) are documented in [CLAUDE.md](CLAUDE.md#borrowing-this-sop-for-other-work). The framework here is biased toward AWS+k8s SRE work; the *shape* is reusable for postmortems, design reviews, onboarding plans, change requests, and anything else where a spec-first discipline pays off.
