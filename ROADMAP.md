# Roadmap

## STATUS

- **Current phase:** 01 — Hello, observable payment (Milestones 1–3 ✅ / Milestone 4 in progress)
- **Last completed phase:** —
- **Last updated:** 2026-04-29

_This section is updated by `/spec-new` and `/phase-close`. Manual edits are fine._

---

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

## Phase shape (high level)

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

Each phase ends with: updated `runbook.md`, `lessons.md` entry, updated `ARCHITECTURE.md`, and a recorded "interview-style explanation" of what was built and why.

## Definition of done (per phase)

1. It works — Validation checklist in the spec all green.
2. I broke it on purpose at least once and recovered.
3. Runbook entry exists, in my own words.
4. ARCHITECTURE.md reflects the new cumulative state.
5. I can explain it cold in 60 seconds.
6. I can redraw the architecture from memory.

---

## Per-phase plan

> Per-phase **design detail** lives in `specs/phase-NN.md`, written via `/spec-new NN` right before the phase starts. The blocks below are the *learning intent* — coarse enough not to lock in design decisions, rich enough to feel grounded in the journey.

### Phase 1 — Hello, observable payment

**Goal:** Provision VPC + EKS via Terraform, deploy a single payment service via Helm, and confirm one end-to-end Datadog trace with log correlation on a `curl` request.

**Depends on:** Foundation — no prior phases.

**Why this first:** Observability before everything. Without traces flowing in Phase 1, every later debugging exercise is built on sand. You can't debug what you can't see.

**Comprehension checkpoints:**
- Why a NAT gateway exists and which subnets need it
- What the Datadog agent does and why it runs as a DaemonSet
- How a trace ID propagates from request → service → log line
- What you'd check first if metrics suddenly stopped flowing

---

### Phase 2 — Ingress and second service

**Goal:** External traffic reaches the service via an ALB with HTTPS termination. A second downstream service is added so traces span service boundaries.

**Depends on:** Phase 1 (cluster, Datadog agent, payment service).

**Why now:** You can't debug service-to-service issues with one service. Add the second one *after* observability is solid — otherwise you don't know if a problem is the new service or the missing telemetry.

**Comprehension checkpoints:**
- How AWS Load Balancer Controller maps an Ingress to an ALB (target groups, listeners, ALB-vs-NLB choice)
- Where ACM certs live and how they attach
- How a trace propagates across services via HTTP headers
- What changes in the Datadog APM view once one service calls another

---

### Phase 3 — CI/CD pipeline (push to main → deployed)

**Goal:** Push to `main` → image built → tests run → image pushed → cluster deployed, with automatic rollback if health checks fail.

**Depends on:** Phase 2 (a stable two-service system worth automating).

**Why now:** Manual `helm upgrade` is fine for one service in week 1. By week 3 you have two services + ingress + cert renewal — manual deploys become the bug source.

**Comprehension checkpoints:**
- What the pipeline actually does, step by step
- Where image tags come from and why mutable tags (`latest`, `main`) are a production footgun
- How the pipeline authenticates to AWS (OIDC vs long-lived access keys — and why this matters)
- Where the rollback boundary lives — what triggers it, what it actually reverses

---

### Phase 4 — HA and scaling

**Goal:** HPA scales the service under load; PodDisruptionBudget prevents simultaneous evictions; readiness/liveness/startup probes detect unhealthy pods correctly.

**Depends on:** Phases 1–3.

**Why now:** Need a stable, observable, deployable system before adding scaling. Otherwise you can't tell if anomalies are real failures or just scaling artifacts.

**Comprehension checkpoints:**
- Liveness vs readiness vs startup — what each one actually causes Kubernetes to *do*
- Why HPA on CPU is often wrong (and the small set of cases it's right)
- What PDB does during a node drain — and what it can't protect against
- How you'd verify the HPA is actually working under realistic load

---

### Phase 5 — Failure injection: infrastructure

**Goal:** Deliberately break the system three ways. Observe each failure in Datadog, recover, and write the runbook entry from real experience.

**Depends on:** Phase 4 (HA must exist or breakage just breaks things).

**Why now:** This is the first phase where you *see* recovery rather than assume it. Pod kill and node drain test the orchestrator; image-pull-fail tests your CI/CD assumptions.

**Comprehension checkpoints:**
- The first signal in Datadog for each failure type — and how soon it appears
- What recovers automatically vs what needs human action
- Why image-pull failures look different from pod crashes (and where each shows up first)
- How to find which node a pod was on after the node is gone

---

### Phase 6 — Failure injection: dependencies

**Goal:** Inject realistic distributed-systems failures — slow DB, slow downstream service, dependency timeout. Observe trace impact and decide which failures the system should tolerate vs surface as errors.

**Depends on:** Phase 5 (you should already be fluent reading Datadog).

**Why now:** Pod/node failures are easy to spot. The hard Principal-SRE incidents are *slow* systems, not *down* systems. This is the highest-value phase for the role.

**Comprehension checkpoints:**
- How a slow downstream shows up in upstream traces
- The difference between cascading failure and graceful degradation
- Where retry-storms come from and how to detect one in flight
- What signals tell you a failure is downstream-of-you vs caused-by-you

---

### Phase 7 — WAF, synthetics, alerts

**Goal:** WAF rules in front of the ALB. Datadog synthetic checks running every minute against the payment endpoint. Alerts auto-create Jira tickets with runbook links.

**Depends on:** Phases 2 (ALB exists), 6 (you know what real failures look like, so alerts are tunable).

**Why now:** WAF earlier = false positives you don't yet have intuition for. Alerts earlier = pure noise. Now there's something worth protecting and meaningful to alert on.

**Comprehension checkpoints:**
- What WAF rules typically catch, and what they miss
- Synthetic vs real-user monitoring — when you need both
- Why "alert into Slack" alone is an anti-pattern
- How to tune an alert that's flapping without just raising the threshold

---

### Phase 8 — Deployment strategy

**Goal:** Pick one (blue/green OR canary), implement it, deliberately deploy a broken version, watch the strategy contain the blast radius.

**Depends on:** All prior phases.

**Why now:** This is the safety net the previous phases earn the right to add. Without observability, scaling, alerting, and incident reps, blue/green is theater — you'd flip the toggle but not know if the new version is actually healthier.

**Comprehension checkpoints:**
- Tradeoffs between blue/green and canary — picking the wrong one for the wrong reason
- What "5% of traffic to the new version" really means at the L7 / pod level
- Where the rollback decision gets made — automated vs human, fast vs deliberate
- How you'd extend this strategy to a multi-service deploy

---

### Stretch (only after the 8 core phases)

| Phase | Focus | Why stretch |
|---|---|---|
| Multi-region | Route 53 latency-based routing, region failover | Adds a week of work and a class of failures the rest of the capstone doesn't cover. Worth doing only if the new role is multi-region. |
| Second CI tool | Add Jenkins (or GHA, whichever you skipped) | Useful only if you're walking into a shop using both. Otherwise diminishing returns. |
| Chaos mesh | Structured chaos engineering tooling | Only after Phases 5 + 6 are solid. Premature = framework theater. |
