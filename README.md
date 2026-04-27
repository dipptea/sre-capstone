# Capstone: Multi-Region Payment Platform

Hands-on capstone to rebuild Principal-SRE-level production confidence. Stack: AWS, EKS, Terraform, Helm, Datadog, Jira, GitHub (CI/CD TBD).

## Approach

Build a small skeleton fast, then spend most of the time **breaking and debugging** it. The skill that sticks is debugging muscle memory, not building-from-scratch trivia.

## How we work in this repo

Spec-driven. Every phase begins with a spec under [specs/](specs/) that must be `status: approved` before any code changes. See [CLAUDE.md](CLAUDE.md) for the full rules of engagement and the comprehension-question rotation.

- `/spec-new NN` — scaffold a phase spec (and updates STATUS in ROADMAP.md)
- `/spec-check` — verify current work against the active spec, surface drift, probe comprehension
- `/phase-close NN` — gate: walk validation, verbal + visual recall, mark spec `done`, update STATUS, commit & push

## Docs in this repo

- [CLAUDE.md](CLAUDE.md) — rules of engagement (spec-first, question rotation, stop-and-ask triggers)
- [ARCHITECTURE.md](ARCHITECTURE.md) — cumulative current system state (updated at end of each phase)
- [ROADMAP.md](ROADMAP.md) — overall scope (slimmed from the original 12-phase plan)
- [PHASE-01.md](PHASE-01.md) — week 1 detailed plan (will become `specs/phase-01.md` once approved)
- [DECISIONS.md](DECISIONS.md) — open decisions and log of choices made
- [specs/_template.md](specs/_template.md) — spec template
- [runbook.md](runbook.md) — operational runbook, grown as we go
- [lessons.md](lessons.md) — what stuck, what didn't, gotchas — written in own words

## Constraints

- **Time:** 6–7 hrs/week
- **Budget:** up to ~$5k total acceptable; not a learning constraint
- **Goal:** production debugging confidence, not breadth of tools touched
