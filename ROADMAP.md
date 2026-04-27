# Roadmap

## Scope (slimmed from original brief)

**In:**
- 2 services only: API gateway + payment service (one language, kept boring)
- One region, multi-AZ
- Terraform via official modules (`terraform-aws-modules/vpc/aws`, `terraform-aws-modules/eks/aws`)
- Helm-deployed apps + ingress (AWS Load Balancer Controller)
- Datadog: APM, logs, infra metrics, synthetics
- Jira: incident tickets + runbook links
- CI/CD: one tool (GitHub Actions or Jenkins — TBD, see DECISIONS.md)
- WAF + ACM/HTTPS
- HPA, PDB, probes, multi-AZ pod spread
- Chaos/failure-injection drills (the main learning vehicle)

**Out (or stretch only):**
- 4-service mesh (fraud, notification) — adds code, not learning
- Multi-region with Route 53 / Global Accelerator — week of work, parked as stretch
- Self-hosted Prom/Grafana/Jaeger — Datadog covers this; revisit only if useful for the new role

## Why this shape

Principal SRE differentiator = debugging under pressure + tradeoff reasoning, not "I built it once." Twelve phases done linearly = forgotten in three weeks. Skeleton-then-break-repeatedly = sticks.

## Phase shape

| Phase | Focus | Est. weeks |
|---|---|---|
| 1 | Skeleton: VPC + EKS + 1 service + Datadog trace flowing | 1 |
| 2 | Ingress (ALB), HTTPS, second service, service-to-service trace | 1 |
| 3 | CI/CD pipeline: build → test → image → deploy | 1 |
| 4 | HA/scaling: HPA, PDB, probes, load test, watch it scale | 1 |
| 5 | Failure-injection drills #1: pod kill, node drain, image pull fail | 1–2 |
| 6 | Failure-injection drills #2: DB latency, downstream slow, dependency timeout | 1–2 |
| 7 | WAF + Datadog synthetics + alerts wired to Jira | 1 |
| 8 | Deployment strategies: blue/green or canary (pick one) | 1 |
| Stretch | Multi-region, second CI tool, chaos mesh | — |

Each phase ends with: updated `runbook.md`, `lessons.md` entry, and a recorded "interview-style explanation" of what was built and why.

## Definition of done (per phase)

1. It works.
2. I broke it on purpose at least once and recovered.
3. Runbook entry exists.
4. I can explain it cold to an interviewer in 60 seconds.
