# Architecture

Single canonical view of the **cumulative current system state**. Updated at the end of each phase.

For the *delta* introduced by any given phase (and the failure-mode notes for new components), see that phase's spec under [specs/](specs/).

## Phase 02 — current cumulative state

End-state of Phase 02: Phase 01 + public HTTPS via ALB. Public users hit `https://payment.payservice.click/pay` from any laptop on the internet → 200, with no `--insecure` flag, observable end-to-end in Datadog APM and Logs.

![Phase 02 architecture — public HTTPS via ALB](docs/diagrams/phase-02-architecture.png)

*Diagram above is the polished view (PNG). The Mermaid version below is the source-controlled equivalent — easier to edit in PRs, renders inline in GitHub.*

```mermaid
flowchart LR
    user["🌐 Public user<br/>(curl, browser)"]
    r53["Route 53<br/>payment.payservice.click<br/>(alias to ALB)"]
    dev["💻 Operator laptop<br/>kubectl"]

    subgraph awsregion["☁️ AWS · us-east-1 · account 591316258137"]
        subgraph ekscp["EKS Control Plane — AWS-managed"]
            api["EKS API Server endpoint"]
        end

        acm["ACM cert<br/>payment.payservice.click"]

        subgraph yourvpc["VPC · 10.0.0.0/16"]
            igw["Internet Gateway"]
            subgraph publica["AZ-a · public subnet 10.0.101.0/24"]
                alba["ALB · internet-facing<br/>(spans both AZs)"]
                nat["NAT Gateway"]
            end
            subgraph publicb["AZ-b · public subnet 10.0.102.0/24"]
                albb["ALB ENI in AZ-b"]
            end
            subgraph aza["AZ-a · private subnet 10.0.1.0/24"]
                node1["Worker node 1"]
                pod["payment-service pod"]
                lbc["AWS LBC pod<br/>(Deployment, 2 replicas)"]
                ddA["Datadog agent pod"]
            end
            subgraph azb["AZ-b · private subnet 10.0.2.0/24"]
                node2["Worker node 2"]
                ddB["Datadog agent pod"]
            end
        end
        ecr[("ECR repo<br/>payment-service:&lt;git-sha&gt;")]
        iam["IAM Role for LBC<br/>(IRSA via OIDC)"]
    end

    ddsaas[("Datadog SaaS")]

    user -.->|"① DNS"| r53
    r53 -.->|"② alias"| user
    user ==>|"③ HTTPS :443"| alba
    acm -.->|"cert binding"| alba
    alba ==>|"④ HTTP :8080 (target type ip)"| pod
    dev -.->|"kubectl"| api
    api -.->|"tunnel"| pod
    lbc -.->|"watches Ingress"| iam
    iam -.->|"manages"| alba
    pod -->|"trace + log"| ddA
    ddA --> nat
    ddB --> nat
    nat --> igw
    igw --> ddsaas
    node1 -.->|"image pull"| nat
    nat -.-> ecr
```

### Components by layer (cumulative)

**Network (Phase 01, Milestone 3)**
- VPC `10.0.0.0/16` in `us-east-1`
- 2 public subnets (`10.0.101.0/24`, `10.0.102.0/24`) — host the NAT GW + ALB
- 2 private subnets (`10.0.1.0/24`, `10.0.2.0/24`) — host worker nodes + pods
- 1 shared NAT Gateway in AZ-a (Phase 5 will expand to per-AZ)
- 1 Internet Gateway

**Compute (Phase 01, Milestone 4)**
- EKS cluster `capstone-sre-cluster` (Kubernetes 1.34, public + private API endpoint, IRSA enabled)
- Managed node group: 2× `t3.medium` EC2 instances, one per AZ, 30 GB gp3 EBS each
- AWS access via SSO role `CapstoneAdmin` (no long-lived IAM keys)

**Observability (Phase 01, Milestone 5)**
- Datadog Helm chart deployed as DaemonSet (one agent pod per node)
- Each agent pod runs 3 containers: `agent`, `trace-agent`, `process-agent`
- Telemetry ships to `us5.datadoghq.com` via NAT GW egress
- `logs.containerCollectAll = true` enables stdout/stderr collection from all pods

**Application (Phase 01, Milestone 6 + Phase 02 Milestone 6)**
- ECR repository `payment-service` with IMMUTABLE git-SHA tags (lifecycle policy keeps last 10)
- FastAPI app exposing `POST /pay` (returns synthetic payment_id) + `GET /health`
- Hand-written Helm chart (Deployment + Service + ServiceAccount + ConfigMap + **Ingress added in Phase 02**)
- `ddtrace-run` entrypoint + `python-json-logger` for structured JSON
- `DD_LOGS_INJECTION=true` injects `dd.trace_id`/`dd.span_id` into every log line
- Service points to Datadog agent via cluster DNS (`datadog.datadog.svc.cluster.local:8126`)

**Public ingress (Phase 02)**
- Domain `payservice.click` (Route 53 registration, 1-year, auto-renew off, lapses 2027-05-04)
- Route 53 hosted zone `payservice.click` (auto-created with domain)
- Alias `A` record `payment.payservice.click` → ALB
- ACM public cert for `payment.payservice.click` (DNS-validated, ACM auto-renews while attached to a load balancer)
- AWS Application Load Balancer (`internet-facing`, spans both AZs)
  - HTTP `:80` listener — `ssl-redirect` → 443
  - HTTPS `:443` listener — ACM cert attached
  - Target group `target-type: ip` (forwards to pod IP, skips kube-proxy hop)
  - Health check `GET /health`
- AWS Load Balancer Controller (Helm chart `eks/aws-load-balancer-controller` v1.11.0; controller v2.11.0; Deployment in `kube-system`, 2 replicas with leader election)
- IRSA IAM role `capstone-sre-lbc-irsa` with AWS-published LBC policy; trust policy locked to `kube-system:aws-load-balancer-controller`
- Subnet tags: `kubernetes.io/role/elb=1` (public) + `kubernetes.io/role/internal-elb=1` (private) for LBC discovery

### Request flow

End-to-end trace path for `curl -X POST https://payment.payservice.click/pay` (verified in Phase 02 Milestone 8):

1. **DNS resolution:** laptop's resolver → Route 53 alias → ALB's public IPs (one per AZ)
2. **TLS handshake:** ALB presents the ACM cert; laptop validates against the public CA chain (no `--insecure` needed)
3. **ALB routing:** Host header matches the Ingress rule for `payment.payservice.click`; ALB forwards plain HTTP to the pod's VPC IP on `:8080` (target type `ip`, skips kube-proxy)
4. **Pod handles request:** FastAPI generates a `payment_id`, emits a JSON log line with `dd.trace_id` injected by ddtrace, returns 200
5. **Response:** ALB re-wraps in TLS, returns to laptop
6. **Trace + log shipping (async, NAT-dependent):** unchanged from Phase 01 — pod → Datadog agent (via cluster DNS) → Datadog SaaS via NAT GW
7. **Correlation:** trace + log linked by `dd.trace_id` in Datadog UI

**Operator path** (kubectl port-forward → EKS API → kubelet → pod) is still available for debugging but is no longer the primary user request path.

**New failure-mode (Phase 02):** if the LBC pod dies, the *existing ALB keeps routing fine* (AWS-managed, lives outside the cluster) — but pod-IP changes stop being reflected. During a rollout, traffic still flows to dead pod IPs and you get 502s. Existing pods unaffected; new deploys silently broken.

---

## Phase 01 baseline (preserved for comparison)

End-state of Phase 01: VPC + EKS + payment-service + Datadog observability pipeline. One end-to-end traced `curl` request whose trace correlates to a log line via shared `trace_id`.

![Phase 01 architecture — VPC + EKS + payment-service + Datadog](docs/diagrams/phase-01-architecture.png)

*Diagram above is the polished view (PNG). The Mermaid version below is the source-controlled equivalent — easier to edit in PRs, renders inline in GitHub.*

```mermaid
flowchart LR
    dev["💻 Developer laptop<br/>kubectl + curl"]

    subgraph awsregion["☁️ AWS · us-east-1 · account 591316258137"]

        subgraph ekscp["EKS Control Plane — AWS-managed (not in your VPC)"]
            api["EKS API Server endpoint<br/>(AWS-managed NLB)"]
        end

        subgraph yourvpc["VPC · 10.0.0.0/16"]
            igw["Internet Gateway"]
            nat["NAT Gateway<br/>(shared · AZ-a public subnet)"]

            subgraph eksdp["EKS Data Plane — worker nodes, in your VPC"]
                subgraph aza["AZ-a · private subnet 10.0.1.0/24"]
                    node1["Worker node 1<br/>t3.medium EC2"]
                    pod["payment-service pod<br/>FastAPI + ddtrace"]
                    ddA["Datadog agent pod<br/>(DaemonSet)"]
                end
                subgraph azb["AZ-b · private subnet 10.0.2.0/24"]
                    node2["Worker node 2<br/>t3.medium EC2"]
                    ddB["Datadog agent pod<br/>(DaemonSet)"]
                end
            end
        end

        ecr[("ECR repo<br/>payment-service:&lt;git-sha&gt;<br/>IMMUTABLE tags")]
    end

    ddsaas[("Datadog SaaS<br/>us5.datadoghq.com<br/>APM + Logs + Metrics")]

    dev ==>|"① kubectl HTTPS<br/>(port-forward)"| api
    api ==>|"② tunnel via kubelet"| pod
    pod -->|"③ trace + log<br/>via datadog svc DNS"| ddA
    ddA -->|"④ HTTPS to Datadog"| nat
    ddB --> nat
    nat --> igw
    igw --> ddsaas
    node1 -.->|"image pull<br/>(deploy time only)"| nat
    nat -.-> ecr
```

### Components by layer

**Network (Phase 01, Milestone 3)**
- VPC `10.0.0.0/16` in `us-east-1`
- 2 public subnets (`10.0.101.0/24`, `10.0.102.0/24`) — host the NAT GW
- 2 private subnets (`10.0.1.0/24`, `10.0.2.0/24`) — host worker nodes
- 1 shared NAT Gateway in AZ-a (Phase 5 will expand to per-AZ)
- 1 Internet Gateway

**Compute (Phase 01, Milestone 4)**
- EKS cluster `capstone-sre-cluster` (Kubernetes 1.34, public + private API endpoint, IRSA enabled)
- Managed node group: 2× `t3.medium` EC2 instances, one per AZ, 30 GB gp3 EBS each
- AWS access via SSO role `CapstoneAdmin` (no long-lived IAM keys)

**Observability (Phase 01, Milestone 5)**
- Datadog Helm chart deployed as DaemonSet (one agent pod per node)
- Each agent pod runs 3 containers: `agent`, `trace-agent`, `process-agent`
- Telemetry ships to `us5.datadoghq.com` via NAT GW egress
- `logs.containerCollectAll = true` enables stdout/stderr collection from all pods

**Application (Phase 01, Milestone 6)**
- ECR repository `payment-service` with IMMUTABLE git-SHA tags (lifecycle policy keeps last 10)
- FastAPI app exposing `POST /pay` (returns synthetic payment_id) + `GET /health`
- Hand-written Helm chart (Deployment + Service + ServiceAccount + ConfigMap)
- `ddtrace-run` entrypoint + `python-json-logger` for structured JSON
- `DD_LOGS_INJECTION=true` injects `dd.trace_id`/`dd.span_id` into every log line
- Service points to Datadog agent via cluster DNS (`datadog.datadog.svc.cluster.local:8126`)

## Request flow

End-to-end trace path for a `curl POST /pay` (verified in Phase 01 Milestone 7):

1. **Setup (one-time per session):** `kubectl port-forward svc/payment 8080:80 -n payment` opens an HTTPS tunnel from laptop → public EKS API server endpoint → kubelet on the pod's node
2. **Request (synchronous, NAT-independent):** `curl http://localhost:8080/pay` is tunneled through kubelet → pod's port 8080
3. **App handles request:** FastAPI generates a `payment_id`, emits a JSON log line with `dd.trace_id` injected by ddtrace, returns 200
4. **Trace shipping (async, NAT-dependent):** ddtrace ships the span to the Datadog agent pod via cluster DNS (NOT loopback — we use the K8s service, not host-IP); the agent batches and ships to `us5.datadoghq.com` via NAT GW
5. **Log shipping (async, NAT-dependent):** the agent's log collector tails the pod's stdout/stderr file on the node and ships to Datadog SaaS
6. **Correlation:** in Datadog, clicking the trace's span shows the log line with the matching `dd.trace_id`, and clicking a log shows its connected trace

**Failure-mode reminder:** if the NAT GW dies, steps 1–3 keep working (control-plane path). Steps 4–5 go silent — the system *works*, but observability *lies*. This is the partial-observability lesson Phase 5's NAT drill will demonstrate live.

## How this is maintained

Maintenance rules live in [`CLAUDE.md`](CLAUDE.md) (hard rule #4 + `/phase-close` flow). This file is updated at phase close — see CLAUDE.md for the full list of phase-close gates.

## Last updated

2026-05-05 — Phase 02 closed. Added: Route 53 alias + ACM cert + AWS Application Load Balancer + AWS Load Balancer Controller (with IRSA) + subnet tags. Public HTTPS path now the primary user request path; kubectl port-forward retained as ops fallback for debugging.

2026-05-01 — Phase 01 closed. VPC + EKS + Datadog DaemonSet + payment-service deployed; end-to-end trace + log correlation verified via curl POST /pay.
