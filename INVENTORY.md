# Inventory — what's running, what it costs, how to stop it

The single source of truth for **resources currently provisioned** by this capstone. Updated at every `/phase-close` (and any time resources are added/removed mid-phase).

This file exists because spec-driven work doesn't, by itself, prevent budget surprise. A spec tells you what to build; this file tells you what's still running and what it's costing — *between sessions, between phases, and between weeks of inactivity*.

## Cumulative monthly cost (estimate)

**~$0/mo** — nothing deployed yet (pre-Phase-01).

Budget targets (from `README.md`):
- Soft alert: **$200/mo**
- Hard cap: **$500/mo**
- Total capstone budget: **~$5,000**

Update this number whenever resources change. Treat the soft alert as "investigate" and the hard cap as "tear something down before continuing."

## Currently running

_(empty — pre-Phase-01)_

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

2026-04-28 — Inventory created (pre-Phase-01 baseline, nothing deployed).
