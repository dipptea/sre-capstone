# Inventory — what's running, what it costs, how to stop it

The single source of truth for **resources currently provisioned** by this capstone. Updated at every `/phase-close` (and any time resources are added/removed mid-phase).

This file exists because spec-driven work doesn't, by itself, prevent budget surprise. A spec tells you what to build; this file tells you what's still running and what it's costing — *between sessions, between phases, and between weeks of inactivity*.

## Cumulative monthly cost (estimate)

**~$160.50/mo** — Phase 04 complete (HA primitives on both services). Phase 03b baseline ~$160.50/mo unchanged. **Phase 04 added $0/mo** — `metrics-server` runs as a single small pod on existing nodes (negligible CPU/memory); HPA, PDB, and probes are free Kubernetes resources; replicas 1→2 bump fits within existing node capacity (no new EC2); ALB was recreated mid-phase but is the same hourly cost as the prior one. **ALB still scheduled for teardown after 2-week test horizon.** Domain `payservice.click` $3 one-time, auto-renew DISABLED.

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

### Domain Registration: payservice.click
- **Type:** Route 53 domain registration (1-year)
- **Region / account:** Global / 591316258137
- **Provisioned in:** Phase 02, Milestone 1
- **Why it exists:** Public hostname for payment-service; capstone needs a domain we control to issue ACM certs and create Route 53 alias records
- **Estimated cost:** $3 one-time for 1 year (paid 2026-05-04, expires 2027-05-04, **auto-renew DISABLED** — will lapse with no further action)
- **Teardown command:** Auto-renew is off → will lapse 2027-05-04 with no further charges. To release earlier: AWS Console → Route 53 → Domains → select domain → Delete (will fail if any records other than NS/SOA exist; remove them first).
- **Dependencies:** None
- **Details:** Registered in capstone-sre-v2 SSO account after wrong-account mishap with `srelab.click` (see Decision log entry 2026-05-05 in [specs/phase-02.md](specs/phase-02.md))

### Route 53 Hosted Zone: payservice.click
- **Type:** AWS Route 53 public hosted zone (auto-created with the domain registration)
- **Region / account:** Global / 591316258137
- **Provisioned in:** Phase 02, Milestone 1 (auto-created with domain)
- **Why it exists:** Authoritative DNS for `payservice.click`; holds the ACM validation CNAME and the alias record for the ALB
- **Estimated cost:** $0.50/mo per hosted zone + ~$0.40 per million queries (alias queries to AWS targets are FREE; only non-alias queries are billed)
- **Teardown command:** `aws route53 delete-hosted-zone --id Z02200631UNGHSRBPV9WQ --profile capstone-admin` (after deleting all non-default records). Only delete if also releasing the domain — orphans the registration otherwise.
- **Dependencies:** Domain registration `payservice.click`
- **Zone ID:** Z02200631UNGHSRBPV9WQ

### ACM Certificate: payment.payservice.click
- **Type:** AWS Certificate Manager public TLS cert (DNS-validated)
- **Region / account:** us-east-1 / 591316258137
- **Provisioned in:** Phase 02, Milestone 2
- **Why it exists:** TLS termination at the ALB so `curl https://payment.payservice.click` works without `--insecure`
- **Estimated cost:** $0/mo (free for AWS-resident workloads — ALB, CloudFront, API Gateway)
- **Teardown command:** `terraform destroy -target=aws_acm_certificate_validation.payment -target=aws_acm_certificate.payment` (only after the ALB no longer references the cert — destroy will fail otherwise)
- **Dependencies:** Route 53 hosted zone (for DNS validation CNAME); ALB (consumer)
- **Details:** Validity 2026-05-05 to 2026-11-18 (~6.5 months); ACM auto-renews 60 days before expiry **only if attached to an AWS resource** (`InUseBy` non-empty)
- **ARN:** arn:aws:acm:us-east-1:591316258137:certificate/a17fa89c-5e52-41df-ae72-c5d700b7c3dc

### Subnet Tags (LBC discovery)
- **Type:** AWS resource tags (metadata on existing Phase 01 subnets — not separately billable)
- **Region / account:** us-east-1 / 591316258137
- **Provisioned in:** Phase 02, Milestone 3
- **Why it exists:** AWS Load Balancer Controller scans subnets by these specific tag strings to decide where to provision ALBs (public for internet-facing, private for internal-only)
- **Estimated cost:** $0/mo
- **Teardown command:** Remove `public_subnet_tags` and `private_subnet_tags` blocks from `infra/vpc.tf`, then `terraform apply`
- **Dependencies:** VPC subnets (Phase 01)
- **Details:** Public subnets (`10.0.101.0/24`, `10.0.102.0/24`) tagged `kubernetes.io/role/elb=1`. Private subnets (`10.0.1.0/24`, `10.0.2.0/24`) tagged `kubernetes.io/role/internal-elb=1`.

### IRSA IAM Role + Policy: capstone-sre-lbc-irsa
- **Type:** IAM Role + AWS-published Load Balancer Controller IAM policy (via `terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks` submodule)
- **Region / account:** Global / 591316258137
- **Provisioned in:** Phase 02, Milestone 4
- **Why it exists:** Grants the LBC pod permissions to call ELB APIs (`CreateLoadBalancer`, `RegisterTargets`, etc.) via short-lived OIDC-issued tokens — no static AWS keys in the cluster
- **Estimated cost:** $0/mo (IAM roles + policies are free)
- **Teardown command:** `terraform destroy -target=module.lbc_irsa` (after LBC Helm release is uninstalled — IAM role destroy fails if policy attachment exists)
- **Dependencies:** EKS OIDC provider (Phase 01), `kube-system/aws-load-balancer-controller` ServiceAccount (created by LBC chart)
- **Trust policy condition:** `sub = system:serviceaccount:kube-system:aws-load-balancer-controller` — locks role to that *exact* (namespace, SA) pair
- **ARN:** arn:aws:iam::591316258137:role/capstone-sre-lbc-irsa

### AWS Load Balancer Controller (Helm release in Kubernetes)
- **Type:** Helm release (`aws-load-balancer-controller`) deploying the LBC Deployment in `kube-system`
- **Region / account:** Cluster: capstone-sre-cluster (us-east-1) / 591316258137
- **Provisioned in:** Phase 02, Milestone 4
- **Why it exists:** Watches Kubernetes Ingress objects and provisions matching ALBs + listeners + target groups + listener rules via AWS APIs
- **Estimated cost:** $0/mo incremental (runs on existing t3.medium nodes already counted)
- **Teardown command:** `helm uninstall aws-load-balancer-controller -n kube-system` (any ALBs created by this controller will become orphans — delete Ingress objects FIRST so the controller cleans up the ALBs while it can still reach AWS APIs)
- **Dependencies:** EKS cluster, IRSA IAM role + policy, EKS OIDC provider, subnet tags
- **Details:** Helm chart `eks/aws-load-balancer-controller` v1.11.0, controller v2.11.0, **2 replicas (HA via leader election)**, ServiceAccount annotated with IRSA role ARN

### ALB: k8s-payment-payment-490cbbb298
- **Type:** AWS Application Load Balancer (provisioned by AWS Load Balancer Controller from the payment-service Ingress)
- **Region / account:** us-east-1 / 591316258137
- **Provisioned in:** Phase 02, Milestone 6
- **Why it exists:** Public HTTPS entry point for payment-service per spec — terminates TLS, routes to pod IP via `target-type: ip`
- **Estimated cost:** ~$25/mo while running (~$16 base ALB charge + ~$9 LCU for light traffic). **Plan: tear down after 2-week test horizon → ~$12 total Phase 02 ALB spend.**
- **Teardown command:** `kubectl delete ingress payment -n payment` (LBC tears down ALB within ~2 min) OR `helm upgrade payment ./helm/payment --reset-then-reuse-values --set ingress.enabled=false -n payment`. Verify with `aws elbv2 describe-load-balancers --profile capstone-admin --region us-east-1` (should not show `k8s-payment-*`).
- **Dependencies:** EKS cluster, AWS Load Balancer Controller (Helm), ACM cert, payment-service Service, public subnets (with `elb` tag)
- **Details:** internet-facing scheme, HTTP :80 listener (redirect to :443), HTTPS :443 listener with ACM cert + 404 fixed-response default action, target group `target-type: ip` with `/health` health check, 2 AZs (us-east-1a + us-east-1b)
- **DNS name:** k8s-payment-payment-490cbbb298-839711176.us-east-1.elb.amazonaws.com

### Route 53 Alias Record: payment.payservice.click → ALB
- **Type:** Route 53 A-alias record (resolves dynamically to ALB's public IPs)
- **Region / account:** Global / 591316258137
- **Provisioned in:** Phase 02, Milestone 7
- **Why it exists:** Maps friendly hostname `payment.payservice.click` to the ALB's auto-generated DNS name; alias type allows zero-cost resolution for AWS targets (CNAME would charge per query)
- **Estimated cost:** $0/mo (alias queries to AWS-owned targets are not billed by Route 53)
- **Teardown command:** `terraform destroy -target=aws_route53_record.payment`
- **Dependencies:** Route 53 hosted zone `payservice.click`, ALB (data source lookup via tag filter)
- **Details:** Type A, alias to ALB DNS, `evaluate_target_health = true` (Route 53 returns NXDOMAIN if all ALB targets are unhealthy)

### GitHub Actions OIDC provider in AWS IAM
- **Type:** IAM OIDC identity provider (`aws_iam_openid_connect_provider`)
- **Region / account:** Global / 591316258137
- **Provisioned in:** Phase 03, Milestone 1
- **Why it exists:** Lets GitHub-hosted Actions runners assume an AWS IAM Role via short-lived OIDC tokens — no static AWS keys stored in GitHub repository secrets. Sits alongside the existing EKS OIDC provider (Phase 01). Different issuer URL: `token.actions.githubusercontent.com` (vs EKS's `oidc.eks.us-east-1.amazonaws.com/id/<cluster-id>`).
- **Estimated cost:** $0/mo (IAM OIDC providers are free)
- **Teardown command:** `terraform destroy -target=aws_iam_openid_connect_provider.github` (only after the IAM Role that trusts it has been destroyed)
- **Dependencies:** None (but the gh-actions-deployer IAM Role's trust policy references this provider's ARN)
- **Details:** Thumbprint pinned dynamically via `tls_certificate` data source — re-runs at every `terraform apply` so cert rotations on GitHub's side auto-refresh. **Failure-mode worth knowing:** if GitHub rotates their cert and you don't re-apply, all GH Actions auth silently breaks until next `terraform apply`.
- **ARN:** arn:aws:iam::591316258137:oidc-provider/token.actions.githubusercontent.com

### IAM Role: gh-actions-deployer
- **Type:** IAM Role + inline policy (`aws_iam_role` + `aws_iam_role_policy`)
- **Region / account:** Global / 591316258137
- **Provisioned in:** Phase 03, Milestone 2
- **Why it exists:** Assumed by GitHub Actions on push to main. Permissions: ECR push to `payment-service` repo + `eks:DescribeCluster` on `capstone-sre-cluster`. Trust policy locks `AssumeRoleWithWebIdentity` to `repo:dipptea/sre-capstone:ref:refs/heads/main` only — pushes from feature branches and PRs from forks cannot assume this role.
- **Estimated cost:** $0/mo (IAM roles + inline policies are free)
- **Teardown command:** `terraform destroy -target=aws_iam_role_policy.gh_actions_deployer -target=aws_iam_role.gh_actions_deployer` (policy first, then role — IAM dependency order)
- **Dependencies:** GitHub OIDC provider (trust policy `Federated` principal); ECR repo `payment-service`; EKS cluster `capstone-sre-cluster` (resource ARN scopes)
- **Details:** Inline policy `gh-actions-deployer-permissions` with 3 statements: ECR push verbs (scoped to one repo), `ecr:GetAuthorizationToken` (resource: `*` per AWS API limitation), `eks:DescribeCluster` (scoped to one cluster). No S3, no Secrets Manager, no general read.
- **ARN:** arn:aws:iam::591316258137:role/gh-actions-deployer

### EKS access entry for gh-actions-deployer
- **Type:** EKS access entry + cluster access policy association (`aws_eks_access_entry` + `aws_eks_access_policy_association`)
- **Region / account:** us-east-1 / 591316258137
- **Provisioned in:** Phase 03, Milestone 3
- **Why it exists:** Grants the `gh-actions-deployer` IAM Role Kubernetes RBAC inside the cluster — without it, AssumeRole succeeds but `helm upgrade` fails with `Unauthorized` from the K8s API. Uses `AmazonEKSClusterAdminPolicy` (broad — same scope as the CapstoneAdmin SSO role's existing access entry); tighter scoping deferred to Phase 07 per the spec's resolved Open question #1.
- **Estimated cost:** $0/mo
- **Teardown command:** `terraform destroy -target=aws_eks_access_policy_association.gh_actions -target=aws_eks_access_entry.gh_actions` (association first, then entry)
- **Dependencies:** EKS cluster, gh-actions-deployer IAM Role
- **Details:** STANDARD type; access scope is `cluster` (not namespace-scoped). No kubeconfig-refresh provisioner needed here — local kubectl access is unaffected; GH Actions builds its own kubeconfig fresh each workflow run.

### GitHub Actions workflow: deploy-payment.yml
- **Type:** GitHub Actions workflow YAML (in repo, not an AWS resource)
- **Region / account:** GitHub-hosted runners (ubuntu-latest, amd64) / dipptea/sre-capstone repo
- **Provisioned in:** Phase 03 Milestone 4 (originally `deploy.yml`); renamed in **Phase 03b Milestone 5** with path filters added
- **Why it exists:** CI/CD pipeline for `payment-service` — `test` job (always), `build-and-push` + `deploy` (push to main only, gated by path filter)
- **Estimated cost:** $0/mo (free minutes for public repos)
- **Teardown command:** `git rm .github/workflows/deploy-payment.yml && git commit && git push`
- **Dependencies:** gh-actions-deployer IAM Role + access entry; ECR `payment-service` repo; EKS cluster; payment Helm chart
- **Path filter (Phase 03b):** triggers on `services/payment/**`, `helm/payment/**`, `.github/workflows/deploy-payment.yml`. A change scoped to `services/risk-check/**` does NOT trigger this workflow.

### ECR Repository: risk-check-service
- **Type:** AWS ECR (Elastic Container Registry)
- **Region / account:** us-east-1 / 591316258137
- **Provisioned in:** Phase 03b, Milestone 2
- **Why it exists:** Stores the `risk-check-service` container image with IMMUTABLE git-SHA tags. Mirrors `payment-service` repo's pattern. Per-service repos give each service its own image lifecycle.
- **Estimated cost:** $0/mo (well under 500MB free tier for ECR storage; lifecycle policy keeps last 10 images)
- **Teardown command:** `terraform destroy -target=aws_ecr_lifecycle_policy.risk_check -target=aws_ecr_repository.risk_check` (lifecycle policy first; ECR repo destroy fails if images exist — `aws ecr batch-delete-image` first if needed)
- **Dependencies:** None (standalone)
- **Details:** IMMUTABLE tag mutability, scan-on-push enabled, AES256 encryption, lifecycle policy: `imageCountMoreThan 10 → expire`
- **URL:** 591316258137.dkr.ecr.us-east-1.amazonaws.com/risk-check-service

### risk-check-service (Helm release in Kubernetes)
- **Type:** Helm release (`risk-check-service`) deploying FastAPI service (Deployment + Service + ServiceAccount + ConfigMap)
- **Region / account:** Namespace `risk-check` in cluster capstone-sre-cluster (us-east-1) / 591316258137
- **Provisioned in:** Phase 03b, Milestones 3 + 6
- **Why it exists:** Synchronous downstream service called by `payment-service` during `/pay`. Demonstrates cross-service distributed tracing in Datadog APM (parent-child span relationship). Foundation for Phase 06's "slow downstream service" failure drill.
- **Estimated cost:** $0/mo incremental (runs on existing t3.medium nodes; uses existing ECR repo storage)
- **Teardown command:** `helm uninstall risk-check-service -n risk-check && kubectl delete namespace risk-check`
- **Dependencies:** EKS cluster, ECR image `risk-check-service:<git-sha>`, Datadog agent (for trace shipping); deployed via `deploy-risk-check.yml` workflow
- **Details:** 1 replica, port 80→8080, ClusterIP service (internal-only — no Ingress), `/health` readiness+liveness probes, `ddtrace-run` entrypoint with `DD_SERVICE=risk-check-service`, synthetic always-`low` risk decision (per Phase 03b resolved Open Q #1)
- **Cluster DNS:** `risk-check-service.risk-check.svc.cluster.local:80`

### GitHub Actions workflow: deploy-risk-check.yml
- **Type:** GitHub Actions workflow YAML (in repo, not an AWS resource)
- **Region / account:** GitHub-hosted runners / dipptea/sre-capstone repo
- **Provisioned in:** Phase 03b, Milestone 5
- **Why it exists:** CI/CD pipeline for `risk-check-service`, mirroring `deploy-payment.yml`. Per-service workflow + path filter = independent deploys (a payment-only change doesn't redeploy risk-check, and vice versa).
- **Estimated cost:** $0/mo (free minutes for public repos)
- **Teardown command:** `git rm .github/workflows/deploy-risk-check.yml && git commit && git push`
- **Dependencies:** gh-actions-deployer IAM Role + access entry (extended in Phase 03b to cover `risk-check-service` ECR repo); risk-check Helm chart; EKS cluster
- **Path filter (Phase 03b):** triggers on `services/risk-check/**`, `helm/risk-check/**`, `.github/workflows/deploy-risk-check.yml`.

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

- 2026-05-04 — Route 53 hosted zone `srelab.click` (in capstone-sre-v2) torn down (Phase 02 Milestone 1, reason: orphan zone left behind when domain was registered in the wrong AWS account; cleaned up before registering `payservice.click` correctly).

Format:
```
- YYYY-MM-DD — <resource-name> torn down (Phase NN, reason: <one line>)
```

## Tear-everything-down (full-stop)

If the budget is breached or you're stepping away for >2 weeks, this is the safe-stop sequence. Maintain it as you go — at every phase close, verify the steps below would actually take the system to zero spend.

```
# 0. Disable the CI pipeline first — stops new pipeline runs while we tear down
git rm .github/workflows/deploy.yml
git commit -m "Tear-down: disable CI pipeline" && git push

# 1. Public DNS first — users get clean NXDOMAIN instead of a half-broken ALB
terraform destroy -target=aws_route53_record.payment

# 2. Ingress objects — LBC tears down ALB + listeners + target group
kubectl delete ingress --all -A
# wait ~2 min, verify with: aws elbv2 describe-load-balancers --profile capstone-admin --region us-east-1

# 3. ACM cert (only after ALB is gone, otherwise destroy fails)
terraform destroy -target=aws_acm_certificate_validation.payment -target=aws_acm_certificate.payment

# 4. Helm releases (apps, LBC, observability)
helm uninstall payment -n payment
helm uninstall risk-check-service -n risk-check
helm uninstall aws-load-balancer-controller -n kube-system
helm uninstall datadog -n datadog
kubectl delete namespace payment risk-check datadog

# 5a. IRSA role for LBC (Phase 02)
terraform destroy -target=module.lbc_irsa

# 5b. GitHub Actions IAM resources (Phase 03)
terraform destroy -target=aws_eks_access_policy_association.gh_actions \
                  -target=aws_eks_access_entry.gh_actions \
                  -target=aws_iam_role_policy.gh_actions_deployer \
                  -target=aws_iam_role.gh_actions_deployer \
                  -target=aws_iam_openid_connect_provider.github

# 6. Cluster
terraform destroy -target=module.eks
# wait for nodes/cluster to fully delete

# 7. Networking (last — other things depend on it)
terraform destroy -target=module.vpc

# 8. Route 53 hosted zone (optional — costs $0.50/mo to keep, useful for next phase if reusing the domain)
# aws route53 delete-hosted-zone --id Z02200631UNGHSRBPV9WQ --profile capstone-admin

# 9. Domain registration: auto-renew is OFF; lapses 2027-05-04. To release sooner, AWS Console → Route 53 → Domains
# 10. Datadog: the agent stops billing once the cluster is gone, but the org/account stays
# 11. ECR repos: free unless storing >500MB
# 12. S3 buckets used by terraform state: keep (cheap, valuable)
```

After running this: re-check the AWS console for any resources that survived (orphaned ENIs, EBS volumes, EIPs are common stragglers).

## Pre-flight cost check (every Phase)

Before running `terraform apply` at the start of a phase, ask:

1. What does the Implementation outline of the spec add to monthly spend?
2. Will the **new** cumulative monthly cost stay under the soft alert ($200)?
3. If not, is this phase worth the spend, or should it be deferred / shrunk?

If the answer to #2 is "no" and #3 is "not sure," **stop and ask the user before applying.** Hitting the soft alert silently is a framework failure, not the user's responsibility.

## Last updated

2026-05-10 — Phase 04 closed. Added: `metrics-server` Helm release (chart 3.12.2 / app 0.7.2) in `kube-system` namespace, installed via Terraform `helm_release` resource in [infra/metrics-server.tf](infra/metrics-server.tf) — **new Helm-install pattern** (declarative, drift-detected; Datadog and AWS LBC remain on the older `null_resource + local-exec` pattern). Added per-service `HorizontalPodAutoscaler` (`autoscaling/v2`, min 2 / max 6 / 70% CPU target) and `PodDisruptionBudget` (`policy/v1`, `minAvailable: 1`) on both `payment` and `risk-check` Helm charts. Added three-probe stack (startup + readiness + liveness on `/health`) parameterized in `values.yaml`. Bumped replicas from 1 to 2 on both services. Restored `ingress.enabled: true` + `certificateArn` as chart defaults in `helm/payment/values.yaml` (were previously held implicitly by `--reuse-values` in the workflow). Removed `--reuse-values` from `deploy-payment.yml`. Re-applied Terraform to refresh `aws_route53_record.payment` alias after Ingress recreation gave the ALB a new DNS name. **Cumulative cost unchanged at ~$160.50/mo** — all Phase 04 additions are free Kubernetes resources; `metrics-server` runs as a single small pod on existing nodes (negligible CPU/memory). No new AWS resources, no new EC2, no new ALB beyond the one that was recreated (same hourly cost). ALB still scheduled for teardown after the 2-week test horizon.

2026-05-07 — Phase 03b closed. Added: `risk-check-service` ECR repo, `risk-check-service` Helm release in `risk-check` namespace, `deploy-risk-check.yml` workflow. Renamed `deploy.yml` → `deploy-payment.yml` and added path filters to both workflows. Extended `gh-actions-deployer` inline policy to cover both ECR repos. Cumulative cost unchanged at ~$160.50/mo (new service runs on existing nodes; ECR storage adds <$0.10/mo).

2026-05-06 — Phase 03 closed. Added: GitHub Actions OIDC provider, IAM Role `gh-actions-deployer` with minimum-scope inline policy (ECR push + EKS DescribeCluster), EKS access entry granting AmazonEKSClusterAdminPolicy to that role, GitHub Actions workflow `.github/workflows/deploy.yml` with test → build → deploy jobs and `helm --atomic` auto-rollback. All Phase 03 resources $0/mo. ECR storage grew slightly past free-tier 500MB → ~$0.15-0.30/mo. Cumulative cost unchanged at ~$160.50/mo.

2026-05-05 — Phase 02 closed. Added: domain `payservice.click` registration (M1), Route 53 hosted zone (M1), ACM cert (M2), subnet tags (M3), IRSA IAM role + LBC Helm release (M4), ALB via Ingress (M6), Route 53 alias record (M7). Removed: orphan `srelab.click` hosted zone in capstone account (wrong-account cleanup). Cumulative cost ~$160.50/mo while ALB is up; returns to ~$135.50/mo after planned 2-week ALB teardown. Still under $200 soft alert.

2026-05-01 — Phase 01 closed. Added: Datadog Helm release (M5), ECR repo for payment-service (M6), payment-service Helm release (M6). Cumulative cost ~$135/mo (still well under $200 soft alert).
