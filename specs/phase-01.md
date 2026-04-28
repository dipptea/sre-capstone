---
phase: 01
title: Hello, observable payment
status: draft
created: 2026-04-27
---

# Phase 01 — Hello, observable payment

## Goal

By the end of Phase 1, a single `curl` request to a payment service running on EKS produces a distributed trace visible in Datadog APM, with the same trace ID present in the pod's log line for that request. Infrastructure (VPC, EKS, Datadog agent) is provisioned via Terraform and Helm.

## Non-goals

- **External traffic / public ingress.** No ALB, no Route 53, no public DNS. Access via `kubectl port-forward` only. *(deferred to Phase 2)*
- **Second service.** Only the payment service. No fraud, notification, or API gateway services. *(deferred to Phase 2)*
- **CI/CD pipeline.** Manual `terraform apply` and `helm upgrade`. No GitHub Actions, no Jenkins. *(deferred to Phase 3)*
- **Autoscaling and HA discipline.** No HPA, no PodDisruptionBudget, no multi-pod replicas. One pod is enough to prove the trace flows. *(deferred to Phase 4)*
- **TLS / HTTPS.** No ACM certs, no encrypted traffic. `kubectl port-forward` is local-loopback. *(deferred to Phase 2 with the ALB)*
- **WAF / security layer.** No web firewall rules, no rate limiting. *(deferred to Phase 7)*
- **Failure injection.** Not breaking anything yet — build the skeleton first. *(deferred to Phases 5–6)*
- **Self-hosted observability.** No Prometheus, no Grafana, no Jaeger. Datadog covers all of it. *(out of capstone scope)*
- **Multi-region.** Single region. *(stretch only)*

## Background

**Why this phase first.** Foundation. Without distributed tracing + log correlation working, every later phase — failure-injection drills, scaling, deployment-strategy validation — is debugging blind. The observability spine goes in before anything else.

**Depends on:** Nothing. First phase.

**Followed by:** [Phase 2 — Ingress and second service](../ROADMAP.md#phase-2--ingress-and-second-service) (ALB, HTTPS, second service, cross-service trace propagation).

**Effort estimate.** ~6–7 focused hours. At 6 hrs/day pace, one focused day, likely split into two sessions (Terraform + cluster bring-up; service + Datadog + trace verification).

**Pre-requisites that block `status: approved`.** Two of the three open decisions in [../DECISIONS.md](../DECISIONS.md):
- **Service language** (Node.js or Python) — needed for the service implementation
- **Terraform modules approach** (official modules vs from-scratch) — needed for the VPC + EKS code
- CI/CD tool decision is *not* required yet (deferred to Phase 3)

**Other prerequisites** (not blockers if already in place):
- AWS account with billing enabled and a budget alarm configured
- Datadog account (trial is fine)
- GitHub repo (already created: `dipptea/sre-capstone`)
- `aws`, `kubectl`, `helm`, `terraform`, `docker` installed locally

## Design

### Decisions & rationale

**Resolved decisions** (logged to [../DECISIONS.md](../DECISIONS.md)):
- Service language: **Python 3.12 + FastAPI** (`ddtrace` is mature; not the learning bottleneck)
- Terraform modules: **Official modules** — `terraform-aws-modules/vpc/aws` v5.x, `terraform-aws-modules/eks/aws` v20.x
- CI/CD tool: still open; deferred to Phase 3

**Region & cost.** Single region `us-east-1`. Estimated steady-state cost ~$200–260/mo: EKS control plane ($73), 2× t3.medium on-demand (~$60), single NAT gateway (~$33), data transfer/EBS (~$10), Datadog APM (~$30/host, free for 14-day trial).

**Networking (VPC module).**
- VPC CIDR `10.0.0.0/16`, 3 AZs (`us-east-1a/b/c`)
- 3 public subnets (ALB future home, NAT) + 3 private subnets (EKS nodes/pods)
- **Single NAT gateway in `us-east-1a`** — saves ~$66/mo over per-AZ NAT. Tradeoff: if `1a` NAT fails, pods in `1b`/`1c` lose internet egress. Phase 4 will revisit per-AZ NAT for HA.
- Internet gateway on public subnets

**Compute (EKS module).**
- EKS version 1.32
- One managed node group: 2× `t3.medium` (2 vCPU / 4 GiB), on-demand (predictability over Spot in Phase 1), distributed across private subnets
- Cluster endpoint: public + private
- Control-plane logs `api`, `audit`, `authenticator` enabled to CloudWatch

**IAM / IRSA.**
- OIDC provider attached to cluster (allows pod-level IAM via service accounts)
- Datadog agent SA uses IRSA to read pod metadata
- Payment service: no AWS API access in Phase 1, so no IAM beyond default

**Container registry.** One ECR repository `payment-service`. Image tag = short git SHA (immutable — no `latest`/`main` tags).

**Observability (Datadog).**
- Helm chart `datadog/datadog` v3.x
- **Node Agent** (DaemonSet) — host metrics, accepts traces over UDS from same-node pods
- **Cluster Agent** — coordinates cluster-level metrics, runs the admission controller
- API key in K8s Secret `datadog-secret` in `datadog` namespace (manually placed Phase 1; automated in later phases)
- Enabled: APM, logs, infra metrics
- Auto-instrumentation via admission controller (`admission.datadoghq.com/python-lib.version`)

**Application — payment service.**
- `POST /pay` → returns `{"status":"success", "payment_id":"<uuid>"}` after a random 50–200ms sleep (simulates work)
- `GET /healthz` → 200 OK
- Logging: stdlib `logging`, JSON output, `dd.trace_id` + `dd.span_id` auto-injected by `ddtrace`
- Container: `python:3.12-slim`, multi-stage build, non-root user
- Resources: requests 100m CPU / 128 MiB; limits 200m CPU / 256 MiB

**Helm chart (hand-written).** `charts/payment/` with `Chart.yaml`, `values.yaml`, and templates for `deployment.yaml`, `service.yaml`, `serviceaccount.yaml`. Namespace `payment`.

**Access (Phase 1 only).**
```
kubectl port-forward -n payment svc/payment 8080:8080
curl -X POST localhost:8080/pay
```

### Architecture (delta this phase)

_(to be filled — Mermaid flowchart)_

### Request flow

_(to be filled — Mermaid sequenceDiagram)_

### Failure-mode notes

_(to be filled — per new component: symptom, blast radius, mitigation)_

## Validation

_(to be filled)_

## Rollback / undo

_(to be filled)_

## Comprehension checkpoints

_(to be filled)_

## Open questions

_(to be filled)_

## Decision log

_(entries appended during execution)_
