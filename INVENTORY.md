# Inventory — what's running, what it costs, how to stop it

The single source of truth for **resources currently provisioned** by this capstone. Updated at every `/phase-close` (and any time resources are added/removed mid-phase).

This file exists because spec-driven work doesn't, by itself, prevent budget surprise. A spec tells you what to build; this file tells you what's still running and what it's costing — *between sessions, between phases, and between weeks of inactivity*.

## Cumulative monthly cost (estimate)

**~$135/mo** — Phase 01 complete (Milestones 1–7). Breakdown: NAT Gateway ~$33/mo + 2 t3.medium nodes ~$60/mo + EBS ~$6/mo + EKS control plane ~$36/mo. ECR storage ~$0/mo (image <500 MB free tier). Datadog SaaS ingestion still on free trial. VPC, subnets, IGW, route tables, ServiceAccounts, ConfigMaps, K8s objects all free. Scaling costs will grow when CI/CD adds image churn (Phase 3) and additional services are deployed.

Budget targets (from `README.md`):
- Soft alert: **$200/mo**
- Hard cap: **$500/mo**
- Total capstone budget: **~$5,000**

Update this number whenever resources change. Treat the soft alert as "investigate" and the hard cap as "tear something down before continuing."

## Currently running

### AWS Account: capstone-sre-v2
- **Type:** AWS Management Account + IAM Identity Center
- **Region / account:** us-east-1 / 591316258137
- **Provisioned in:** Phase 01, Milestone 1 (Cluster Foundation)
- **Why it exists:** Management account for workload deployment; Identity Center provides SSO + short-lived credentials per DECISIONS.md
- **Estimated cost:** $0/mo (included in AWS Organizations)
- **Teardown command:** Not during capstone. If decommissioning entire capstone, delete AWS Organization (will fail if member accounts exist — delete those first)
- **Dependencies:** None within capstone (but organizational parent of the member account will exist when Phase 2+ adds separate deployment accounts)

### AWS Budget Alarm
- **Type:** AWS Budgets alert
- **Region / account:** us-east-1 / 591316258137
- **Provisioned in:** Phase 01, Milestone 1
- **Why it exists:** Alert at $100 (soft) and $200 (hard) to prevent budget surprise per ROADMAP
- **Estimated cost:** $0/mo (AWS Budgets alerts are free)
- **Teardown command:** AWS Console → Budgets → Delete budget
- **Dependencies:** None

### Datadog Trial Organization
- **Type:** Datadog SaaS (observability platform)
- **Region / account:** Datadog US (https://app.datadoghq.com)
- **Provisioned in:** Phase 01, Milestone 1
- **Why it exists:** APM, logs, infrastructure metrics, and synthetics per ROADMAP; observability-first principle
- **Estimated cost:** $0 (14-day trial), then ~$50–150/mo depending on ingestion (can be deferred or deprioritized if budget tight)
- **Teardown command:** Datadog Account Settings → Delete Organization (data is permanently lost)
- **Dependencies:** None (standalone SaaS)
- **API key location:** Datadog → Org Settings → API Keys (retrieve and store in password manager for Milestone 5 use)

### Jira Free Tier Project
- **Type:** Jira Cloud (project management / incident ticketing)
- **Region / account:** https://capstone-sre.atlassian.net
- **Provisioned in:** Phase 01, Milestone 1
- **Why it exists:** Incident tickets + runbook links per ROADMAP; alert routing in Phase 7
- **Estimated cost:** $0/mo (free tier, up to 10 users)
- **Teardown command:** Jira Settings → Delete Project (then delete Organization if no other projects remain)
- **Dependencies:** None (standalone SaaS)

### VPC: capstone-sre-vpc
- **Type:** AWS VPC (Virtual Private Cloud)
- **Region / account:** us-east-1 / 591316258137
- **Provisioned in:** Phase 01, Milestone 3
- **Why it exists:** Network isolation for EKS cluster and workloads per spec design; foundation for all subsequent infrastructure
- **Estimated cost:** $0/mo (VPC itself is free; subnets, route tables, IGW are free)
- **Teardown command:** `terraform destroy -target=module.vpc`
- **Dependencies:** None (but EKS cluster will depend on it)
- **ID:** vpc-068eebd69a8151098

### NAT Gateway: capstone-sre-vpc-us-east-1a
- **Type:** AWS NAT Gateway + Elastic IP
- **Region / account:** us-east-1a / 591316258137
- **Provisioned in:** Phase 01, Milestone 3
- **Why it exists:** Enables private subnets to reach the internet (outbound only) for Datadog telemetry. Shared per Phase 1 spec; upgrades to per-AZ in Phase 5
- **Estimated cost:** $33/mo (NAT GW) + ~$0.045/GB egress (Datadog telemetry)
- **Teardown command:** `terraform destroy -target=module.vpc` (NAT destroyed with VPC)
- **Dependencies:** VPC, Elastic IP, public subnet
- **ID:** nat-0b9ff9ccb189b2b0b

### Subnets & Route Tables
- **Type:** AWS Subnets (2 public, 2 private) + Route Tables
- **Region / account:** us-east-1 / 591316258137
- **Provisioned in:** Phase 01, Milestone 3
- **Why it exists:** Public subnets hold ALB + NAT; private subnets hold EKS nodes and pods
- **Estimated cost:** $0/mo (free)
- **Teardown command:** `terraform destroy -target=module.vpc`
- **Dependencies:** VPC
- **Details:** Public: 10.0.101.0/24 (us-east-1a), 10.0.102.0/24 (us-east-1b) | Private: 10.0.1.0/24 (us-east-1a), 10.0.2.0/24 (us-east-1b)

### EKS Cluster: capstone-sre-cluster
- **Type:** AWS EKS (Elastic Kubernetes Service)
- **Region / account:** us-east-1 / 591316258137
- **Provisioned in:** Phase 01, Milestone 4
- **Why it exists:** Kubernetes control plane for running containerized payment service and observability workloads per spec
- **Estimated cost:** ~$36–44/mo (EKS control plane fee, fixed per cluster)
- **Teardown command:** `terraform destroy -target=module.eks`
- **Dependencies:** VPC, private subnets, security groups
- **Details:** Kubernetes 1.34, private + public API endpoint access, IRSA enabled (OIDC configured)
- **Cluster name:** capstone-sre-cluster
- **OIDC provider ARN:** arn:aws:iam::591316258137:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EBF1374F7317CC67C05A9922EB43FB65

### EKS Managed Node Group
- **Type:** AWS EKS Managed Node Group (EC2 worker nodes)
- **Region / account:** us-east-1 / 591316258137
- **Provisioned in:** Phase 01, Milestone 4
- **Why it exists:** Worker nodes run pods (payment service, Datadog agent, ingress controller, etc.)
- **Estimated cost:** ~$60/mo (2 × t3.medium ~$30/mo each) + ~$6/mo (30GB gp3 EBS × 2)
- **Teardown command:** `terraform destroy -target=module.eks`
- **Dependencies:** EKS cluster, VPC, private subnets
- **Details:** 2 t3.medium nodes (2 vCPU, 4 GB RAM each), 1 per AZ (us-east-1a, us-east-1b), 30GB gp3 EBS per node, ON_DEMAND capacity type
- **Node group name:** main-20260429215502793800000010 (auto-generated)
- **Status:** ACTIVE

### Datadog Agent (Helm release in Kubernetes)
- **Type:** Helm release (`datadog`) deploying the Datadog DaemonSet (agent + trace-agent + process-agent per node)
- **Region / account:** Cluster: capstone-sre-cluster (us-east-1) / 591316258137 — telemetry ships to us5.datadoghq.com
- **Provisioned in:** Phase 01, Milestone 5
- **Why it exists:** Ships node + pod + container metrics, logs, and APM traces to Datadog SaaS — the observability foundation every later phase depends on
- **Estimated cost:** $0 during Datadog trial (~14 days remaining); afterwards depends on host count + log volume — typically ~$50–150/mo at this scale, can be deferred or downgraded if budget tight
- **Teardown command:** `helm uninstall datadog -n datadog && kubectl delete namespace datadog` (or `terraform destroy -target=null_resource.datadog_helm_release`)
- **Dependencies:** EKS cluster, Datadog API key in `.env`, internet egress via NAT GW
- **Details:** Helm chart `datadog/datadog` v3.62.0, site=`us5.datadoghq.com`, APM enabled, logs.containerCollectAll=true, cluster_agent disabled

### ECR Repository: payment-service
- **Type:** AWS ECR (Elastic Container Registry)
- **Region / account:** us-east-1 / 591316258137
- **Provisioned in:** Phase 01, Milestone 6
- **Why it exists:** Stores the payment-service container image with immutable git-SHA tags so EKS can pull a known-exact version (no `latest` drift)
- **Estimated cost:** $0/mo (free under 500 MB; current image ~340 MB; lifecycle policy keeps only last 10 images)
- **Teardown command:** `terraform destroy -target=aws_ecr_lifecycle_policy.payment -target=aws_ecr_repository.payment` (lifecycle policy goes first; ECR repo destroy fails if images exist — `aws ecr batch-delete-image` first if needed)
- **Dependencies:** None (standalone)
- **Details:** IMMUTABLE tag mutability, scan-on-push enabled, AES256 encryption, lifecycle policy: `imageCountMoreThan 10 → expire`
- **URL:** 591316258137.dkr.ecr.us-east-1.amazonaws.com/payment-service

### Payment Service (Helm release in Kubernetes)
- **Type:** Helm release (`payment`) deploying FastAPI service (Deployment + Service + ServiceAccount + ConfigMap)
- **Region / account:** Namespace `payment` in cluster capstone-sre-cluster (us-east-1) / 591316258137
- **Provisioned in:** Phase 01, Milestone 6
- **Why it exists:** The single service traced end-to-end in Phase 01 — proves the observability pipeline (curl → trace → log correlation) works
- **Estimated cost:** $0/mo incremental (runs on existing t3.medium nodes already counted; pulls existing ECR image)
- **Teardown command:** `helm uninstall payment -n payment && kubectl delete namespace payment`
- **Dependencies:** EKS cluster, ECR image `payment-service:<git-sha>`, Datadog agent (for trace shipping)
- **Details:** 1 replica, port 80→8080, `/health` readiness+liveness probes, `ddtrace-run` entrypoint, `DD_LOGS_INJECTION=true` for trace_id in JSON logs
- **Image tag deployed:** `f6df6dd`

Format for each entry, when populated:

```
### <resource-name>
- **Type:** e.g., EKS cluster, NAT Gateway, ALB, RDS, ECR repo
- **Region / account:** us-east-1 / <aws-account-id>
- **Provisioned in:** Phase NN
- **Why it exists:** one line linking to the spec's Goal or Decisions section
- **Estimated cost:** $X/mo (cite the source: AWS pricing calc, console estimate, terraform plan output)
- **Teardown command:** `terraform destroy -target=module.<x>` *or* `aws <service> delete-<thing> ...`
- **Dependencies:** other resources that would also need to come down
```

## Torn down

Historical record of resources that have been removed. Helps you see the *churn* of what you've been provisioning + destroying.

_(empty)_

Format:
```
- YYYY-MM-DD — <resource-name> torn down (Phase NN, reason: <one line>)
```

## Tear-everything-down (full-stop)

If the budget is breached or you're stepping away for >2 weeks, this is the safe-stop sequence. Maintain it as you go — at every phase close, verify the steps below would actually take the system to zero spend.

```
# 1. Apps & ingress (top of stack first)
helm uninstall <release> -n <ns>      # repeat per release
kubectl delete ingress --all -A       # ALB Controller will deprovision the ALB

# 2. Cluster
terraform destroy -target=module.eks
# wait for nodes/cluster to fully delete

# 3. Networking (last — other things depend on it)
terraform destroy -target=module.vpc

# 4. Datadog: the agent stops billing once the cluster is gone, but the org/account stays
# 5. ECR repos: free unless storing >500MB
# 6. S3 buckets used by terraform state: keep (cheap, valuable)
```

After running this: re-check the AWS console for any resources that survived (orphaned ENIs, EBS volumes, EIPs are common stragglers).

## Pre-flight cost check (every Phase)

Before running `terraform apply` at the start of a phase, ask:

1. What does the Implementation outline of the spec add to monthly spend?
2. Will the **new** cumulative monthly cost stay under the soft alert ($200)?
3. If not, is this phase worth the spend, or should it be deferred / shrunk?

If the answer to #2 is "no" and #3 is "not sure," **stop and ask the user before applying.** Hitting the soft alert silently is a framework failure, not the user's responsibility.

## Last updated

2026-05-01 — Phase 01 closed. Added: Datadog Helm release (M5), ECR repo for payment-service (M6), payment-service Helm release (M6). Cumulative cost ~$135/mo (still well under $200 soft alert).
