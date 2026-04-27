# Phase 1 — Hello, observable payment (Week 1, ~6–7 hrs)

## Goal

By end of week 1: **one trace flows from a `curl` request, through the payment service, into Datadog APM, with the trace ID also appearing in the service log line.** That's the whole goal. No ALB, no second service, no CI/CD, no WAF.

## Why this scope

If observability isn't working at the very start, every later phase (debugging, chaos, scaling) is built on sand. Get the trace flowing first. Everything else is decoration.

## Steps

| # | Time | Step |
|---|------|------|
| 1 | 30m | AWS account + budget alarm ($200/mo warn, $500/mo hard); Datadog trial; Jira free tier; GitHub repo `optum-capstone` |
| 2 | 1.5h | Terraform: VPC + EKS (multi-AZ, 2× t3.medium nodes) via official modules |
| 3 | 30m | `aws eks update-kubeconfig`, verify `kubectl get nodes` returns 2 ready |
| 4 | 1h | Install Datadog agent via Helm chart; verify cluster + node metrics in Datadog UI |
| 5 | 1.5h | Tiny `payment` service with `POST /pay` endpoint; Datadog/OTel tracer wired in; JSON logs with `trace_id` field |
| 6 | 1h | Dockerize, push to ECR, deploy via a Helm chart you write by hand (don't use a generator) |
| 7 | 30m | `curl` via `kubectl port-forward`; confirm trace in Datadog APM **and** trace_id appears in pod log line |

## Stretch (only if time)

Write a one-page `runbook.md` entry: "How to deploy this service from zero" — in your own words, not copy-pasted commands. **This is the actual Principal-SRE deliverable.** If you skip the runbook, the phase isn't done; it's just code.

## Deliberately skipped this week

- ALB / Ingress controller
- WAF, ACM/HTTPS
- CI/CD pipeline
- Second service
- HPA, PDB, probes
- Failure injection

Each of those gets its own dedicated week.

## Session split (suggested)

- **Session A (~3h):** steps 1–3 (accounts + Terraform + cluster up)
- **Session B (~3h):** steps 4–7 (Datadog + service + trace flowing)
- **Session C (~1h):** runbook write-up + verbal explanation rehearsal

## End-of-phase check

- [ ] `kubectl get pods -n payment` shows running pod
- [ ] `curl` to `/pay` returns 200
- [ ] Datadog APM shows the trace
- [ ] Pod log line for that request contains the same `trace_id`
- [ ] `runbook.md` has a "deploy from zero" section
- [ ] You can verbally explain in 60s what you built and why each piece exists
