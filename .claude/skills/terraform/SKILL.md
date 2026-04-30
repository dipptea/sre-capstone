---
name: terraform
description: |-
  Opinionated Terraform skill for this capstone — prescribes the *one right way* to author IaC against this exact stack so common authentication, provider, and EKS-module footguns never reach `terraform apply`. Verified against current GitHub docs (NOT training-data memory) for terraform-aws-modules/eks/aws v20.37.x, hashicorp/aws ~> 5, hashicorp/kubernetes 2.38.0, hashicorp/helm 2.17.0.
  TRIGGER when: editing/reading `.tf`, `.tfvars`, `.hcl`; writing new EKS / k8s / helm / Datadog Terraform; before any `terraform init/plan/apply/destroy`; questions about provider config, EKS access entries, IRSA/OIDC, AWS SSO ARNs, kubeconfig from Terraform, or k8s/helm resource shapes.
  SKIP for: non-Terraform IaC (Pulumi, CDK, CloudFormation); pure aws/kubectl/helm CLI questions with no `.tf` change involved; generic Kubernetes/Helm questions not touching Terraform code.
---

# Terraform skill — the one right way for this stack

This skill is **prescriptive**: it specifies the canonical pattern for every Terraform concern in this repo. When asked to write or modify Terraform, follow these patterns by default. Don't invent alternatives unless the user explicitly asks.

If the patterns below conflict with something you remember from training, **the patterns win**. They're verified against current GitHub source for the pinned versions:

- `terraform-aws-modules/eks/aws` v20 (latest tag at write time: **v20.37.2**)
- `hashicorp/terraform-provider-helm` **v2.17.0**
- `hashicorp/terraform-provider-kubernetes` **v2.38.0**
- `hashicorp/aws` ~> 5

---

## Pinned versions in this repo

| Component | Version |
|---|---|
| EKS module | `terraform-aws-modules/eks/aws` ~> 20.0 |
| AWS provider | hashicorp/aws ~> 5.0 |
| Kubernetes provider | hashicorp/kubernetes 2.38.0 |
| Helm provider | hashicorp/helm 2.17.0 |
| Region / Account | `us-east-1` / `591316258137` |
| Cluster name | `capstone-sre-cluster` |
| AWS auth | SSO via `capstone-admin` profile |

---

## How to approach any Terraform task in this repo

In order, every time:

1. **Read the spec's Implementation outline.** Don't author resources that aren't in the current milestone.
2. **Read the existing `.tf`** that surrounds your change. Match its style.
3. **Run pre-flight (next section)** before suggesting an `apply`.
4. **Write the resource using the canonical pattern below** for that concern.
5. **Predict before apply** — state expected `+ N to add / ~ M to change / - K to destroy`. Wrong predictions = stop and read the plan, don't apply.
6. **Hands rule (CLAUDE.md):** I write the `.tf`. The user runs `terraform init/plan/apply`. I never `apply` for them.

---

## Pre-flight (do these before *any* `terraform apply`)

These are not optional. Skipping them is the #1 source of repeat errors.

```bash
# 1. Confirm you're acting as the right identity in the right account.
export AWS_PROFILE=capstone-admin
aws sts get-caller-identity
# Expect: account "591316258137", arn ending with the SSO role.
# If the account is wrong → change AWS_PROFILE before doing anything else.

# 2. SSO token is fresh (~12h lifetime).
aws sso login --profile capstone-admin
# Skip if already logged in this session.

# 3. Kubeconfig points at the right cluster (only needed if the providers use config_path).
aws eks update-kubeconfig --region us-east-1 --name capstone-sre-cluster --profile capstone-admin

# 4. If anything in versions.tf or providers.tf changed, OR AWS_PROFILE changed:
terraform init -upgrade
# Provider auth is captured at init time. Env-var changes after init don't take effect.
```

**Hard rule:** Set `AWS_PROFILE` *before* `terraform init`. After-the-fact env changes are silently ignored by cached provider state.

---

## Canonical patterns (use these exactly)

### 1. AWS provider

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Phase     = var.phase
    }
  }
}
```

Credentials come from `AWS_PROFILE` set in the shell. Do not embed access keys, role ARNs, or `assume_role` blocks unless the user explicitly asks for cross-account work.

**Why `default_tags`?** Every resource gets consistent tags for cost attribution, resource tracking, and automation (no need to repeat tags on each resource).

### 2. Discovering the SSO role ARN — always query, never construct

SSO roles live at a special path: `:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_<Name>_<hash>`. Constructing this string from memory will produce an invalid ARN.

**Use a `data` source:**

```hcl
data "aws_iam_role" "sso_admin" {
  name = "AWSReservedSSO_CapstoneAdmin_5211c2f501907eff"
}

# Reference it as: data.aws_iam_role.sso_admin.arn
```

Or for one-offs at the shell:

```bash
aws iam get-role \
  --role-name AWSReservedSSO_CapstoneAdmin_5211c2f501907eff \
  --query 'Role.Arn' \
  --profile capstone-admin
```

Same rule for any other ARN you don't have a literal source for: query, don't construct.

### 3. Kubernetes provider — exec auth with portable env

Use `exec` auth with AWS profile passed via **environment variable**, not as an arg. This keeps args portable and lets the profile be swapped without rewriting the args.

```hcl
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region",       var.aws_region,
    ]
    env = {
      AWS_PROFILE = "capstone-admin"
    }
  }
}
```

This is verified valid in kubernetes provider v2.38.0.

**Hard rules:**
- **Never `provider "kubernetes" {}` empty.** It defaults to in-cluster auth, fails, falls back to `localhost:80`, and you'll spend an hour debugging. Always configure explicitly.
- **Never embed `--profile` as an arg.** Use the `env` block instead — it's more portable and doesn't expose the profile in the args list.
- **Never use a literal `~` in a path string.** Terraform doesn't expand tilde. Use `pathexpand("~/.kube/config")` if you must use kubeconfig (but prefer exec).

### 4. Helm provider — explicit `kubernetes` block

The helm provider does **not** inherit from the kubernetes provider. It has its own auth.

#### For local development (recommended):

```hcl
provider "helm" {
  kubernetes {
    config_path = pathexpand("~/.kube/config")
  }
}
```

Simpler, relies on the kubeconfig that `kubectl` and `aws eks update-kubeconfig` already manage.

#### For CI (if needed):

```hcl
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", module.eks.cluster_name,
        "--region",       var.aws_region,
      ]
      env = {
        AWS_PROFILE = "capstone-admin"
      }
    }
  }
}
```

**Hard rules:**
- **Never `provider "helm" {}` empty.** Per the v2.17.0 docs: "The provider does not use the KUBECONFIG environment variable by default." Empty blocks have version-dependent fallbacks that bite in CI.
- The block name **inside** is `kubernetes` (not `kubernetes_provider` or anything else). Block name is valid; if Terraform complains about it, the *contents* are misspelled.

### 5. EKS cluster & access entries — module + standalone resources

The EKS module handles the cluster and IRSA/OIDC. Grant additional principals access via **standalone `aws_eks_access_entry` + `aws_eks_access_policy_association` resources** (not module-native `access_entries` map — that's theoretically cleaner but standalone resources are validated working).

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "capstone-sre-cluster"
  cluster_version = "1.34"

  vpc_id     = module.vpc.vpc_id              # required — don't omit
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  # Module creates the IAM OIDC provider for IRSA. Do NOT create one manually.
  enable_irsa = true

  eks_managed_node_groups = {
    main = {
      name           = "main"               # short literal name
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"          # uppercase enum
      min_size       = 2
      max_size       = 4
      desired_size   = 2
    }
  }
}

# Grant additional principals access via standalone resources
resource "aws_eks_access_entry" "capstone_admin" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = data.aws_iam_role.sso_admin.arn
  type              = "STANDARD"
}

resource "aws_eks_access_policy_association" "capstone_admin" {
  cluster_name       = module.eks.cluster_name
  policy_arn         = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn      = data.aws_iam_role.sso_admin.arn
  access_scope {
    type = "cluster"
  }

  # CRITICAL: Refresh kubeconfig immediately after access is granted.
  # Without this, Terraform's Kubernetes provider sees stale credentials
  # and subsequent kubectl/helm resources fail with auth errors.
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name} --profile capstone-admin && sleep 5"
  }
}
```

**Hard rules:**
1. **Never use `kubernetes_groups = ["system:masters"]`.** EKS rejects any group starting with `system:`. Use `AmazonEKSClusterAdminPolicy` instead.
2. **Never create a manual `aws_iam_openid_connect_provider` for EKS.** `enable_irsa = true` makes the module create it.
3. **Node-group naming:** Use either `name = "main"` (short literal) or `name_prefix = "capstone-sre-nodes-"` (auto-generated suffix). Both work; IAM `name_prefix` has a 38-char limit if using `name_prefix`.
4. **Never use `manage_aws_auth_configmap` or aws-auth ConfigMap.** That's pre-v20 style. v20 uses API-level `access_entries` (standalone or module-native both work).
5. **Pass `vpc_id` explicitly.** Without it the module creates security groups in the wrong VPC.
6. **Always refresh kubeconfig after granting access.** Add the provisioner shown above to prevent "Kubernetes cluster unreachable" errors on the same `apply`.

### 6. Kubernetes resources — naming conventions

Prefer the `_v1` (stable) variants with underscores between words, but legacy names (without `_v1`) also work. Many K8s objects look like one word but are two:

| K8s object | Preferred (Terraform 2.38+) | Legacy (still works) |
|---|---|---|
| Namespace | `kubernetes_namespace_v1` | `kubernetes_namespace` |
| ConfigMap | `kubernetes_config_map_v1` | `kubernetes_config_map` |
| Secret | `kubernetes_secret_v1` | `kubernetes_secret` |
| ServiceAccount | `kubernetes_service_account_v1` | `kubernetes_service_account` |
| Deployment | `kubernetes_deployment_v1` | `kubernetes_deployment` |
| StatefulSet | `kubernetes_stateful_set_v1` | `kubernetes_stateful_set` |
| DaemonSet | `kubernetes_daemon_set_v1` | (legacy: `kubernetes_daemonset` is wrong) |
| Service | `kubernetes_service_v1` | `kubernetes_service` |
| Ingress | `kubernetes_ingress_v1` | `kubernetes_ingress` |
| PVC | `kubernetes_persistent_volume_claim_v1` | `kubernetes_persistent_volume_claim` |

**Preferred approach:** Use `_v1` for new resources. **Migration note:** If you encounter legacy names in existing code, they work fine; migrate incrementally when touching that resource.

When unsure, list the docs directory for the pinned tag:

```bash
gh api "repos/hashicorp/terraform-provider-kubernetes/contents/docs/resources?ref=v2.38.0" \
  --jq '.[].name' | grep -i <thing>
```

### 7. Helm chart deployment — `null_resource` provisioner (validated pattern)

The helm provider (either `helm_release` resource or via `local-exec`) requires the helm repo to be indexed locally before deployment. The most reliable pattern is **`null_resource` with a local-exec provisioner that runs `helm upgrade --install`** — this handles repo setup and deployment in one atomic operation and includes clean destroy.

#### Primary pattern: null_resource shell-out (validated working)

```hcl
resource "null_resource" "datadog_helm_release" {
  depends_on = [module.eks, kubernetes_namespace_v1.datadog]

  provisioner "local-exec" {
    command = <<-EOT
      export AWS_PROFILE=capstone-admin
      helm repo add datadog https://helm.datadoghq.com --force-update
      helm repo update
      helm upgrade --install datadog datadog/datadog \
        --namespace datadog \
        --version 3.62.0 \
        --set datadog.apiKey=${var.datadog_api_key} \
        --set datadog.site=datadoghq.com \
        --set agents.enabled=true
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "helm uninstall datadog --namespace datadog 2>/dev/null || true"
  }
}
```

**Why this pattern?** Bypasses helm provider auth complexities, handles repo setup, and includes clean destroy.

#### Alternative: User adds repo at shell + `helm_release` resource

If you prefer the `helm_release` Terraform resource, document in `runbook.md`:

```bash
brew install helm   # if not already installed
helm repo add datadog https://helm.datadoghq.com
helm repo update
```

Then use the `helm_release` resource:

```hcl
resource "helm_release" "datadog_agent" {
  name       = "datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  namespace  = kubernetes_namespace_v1.datadog.metadata[0].name
  version    = "3.62.0"
  values     = [yamlencode({ ... })]
  depends_on = [module.eks]
}
```

**Caveat:** Requires helm provider auth to be configured (kubeconfig or exec). If auth fails, you hit the whole debugging loop we avoided with null_resource.

**Hard rule:** Document helm repo setup in `runbook.md` or handle it via provisioner. Never assume the repo is pre-indexed.

### 8. Secrets — `sensitive = true` at declaration (best practice)

```hcl
variable "datadog_api_key" {
  type        = string
  sensitive   = true   # required — prevents value being printed in plan/apply output
  description = "Datadog API key for the agent. Source via TF_VAR_datadog_api_key env var."
}
```

For the source of the value, in order of preference:
1. **AWS Secrets Manager / Parameter Store** via a `data` block (the data attribute is also marked sensitive).
2. **`TF_VAR_<name>` environment variable** set in the shell — never tracked.
3. **Gitignored `.tfvars`** — last resort.

#### Current repo compromise (documented, with TODO)

This repo currently reads the Datadog API key from a **`.env`** file via `file()` + `regex()`:

```hcl
locals {
  datadog_api_key = file("${path.module}/../.env") != "" ? regex("DATADOG_API_KEY=([^\n]+)", file("${path.module}/../.env"))[0] : ""
}
```

**Why:** Fast iteration for a learning capstone. **TODO:** Migrate to a `sensitive` variable or Secrets Manager before Phase 3 (CI/CD).

**Warning:** Even with `sensitive = true`, the value can leak through `local-exec` command lines, `output` blocks without `sensitive = true`, or `echo`. Treat sensitive as display protection, not handling protection.

### 9. State backend (S3) — use the new lockfile, not DynamoDB

```hcl
terraform {
  backend "s3" {
    bucket       = "<your-state-bucket>"
    key          = "capstone/phase-01/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true   # native S3 lockfile; replaces deprecated dynamodb_table
    encrypt      = true
  }
}
```

After flipping from `dynamodb_table` to `use_lockfile`: `terraform init -reconfigure`.

---

## Things this skill refuses to write (anti-patterns)

If asked to do any of these, push back and offer the canonical pattern instead:

1. `provider "kubernetes" {}` or `provider "helm" {}` — empty blocks. Always configure explicitly.
2. `kubernetes_groups = ["system:masters"]` — use `AmazonEKSClusterAdminPolicy` instead.
3. `manage_aws_auth_configmap = true` or any `kubernetes_config_map.aws_auth` resource — that's pre-v20 style. Use `access_entries` (module-native or standalone).
4. A standalone `aws_iam_openid_connect_provider` for EKS while `enable_irsa = true` — duplicate.
5. SSO role ARNs constructed from name (`role/AWSReservedSSO_X_Y`) — must use `data "aws_iam_role"` or `aws iam get-role` output (path includes `aws-reserved/sso.amazonaws.com/`). **Migration note:** Hardcoded ARNs work but should be refactored.
6. Literal `~` in path strings — use `pathexpand("~/.kube/config")`.
7. Mutable image tags (`:latest`, `:main`, `:stable`) in any container reference — always immutable (git short SHA, semver, or content digest).
8. `capacity_type = "on_demand"` (lowercase) — must be `"ON_DEMAND"`.
9. Forget to refresh kubeconfig after granting EKS access — add the provisioner from §5 to prevent "Kubernetes cluster unreachable" errors.
10. Hardcoded older Kubernetes versions without checking regional AMI availability — default to the version pinned in this repo (`1.34`) unless there's a specific reason to differ.
11. `apply -auto-approve` in a recommendation — always make the user read the plan first.
12. Variable holding a real secret without `sensitive = true`.
13. New `provider` blocks added without a corresponding `terraform init` step in the recommendation.
14. Assume the helm repo is pre-indexed — use null_resource provisioner or document shell setup in runbook.md.

---

## Workflow rules (Hands rule applied)

| Step | Who runs it |
|---|---|
| Authoring `.tf` files | Claude |
| `terraform fmt` / `terraform validate` | Claude |
| Reading docs / module sources | Claude |
| `aws sts get-caller-identity` | User |
| `aws sso login` | User |
| `aws eks update-kubeconfig` | User (and only when needed for `kubectl`, not for terraform if exec auth is used) |
| `terraform init` / `init -upgrade` | User |
| `terraform plan` | User (Claude must ask a Predict question first) |
| `terraform apply` | User |
| Reading and interpreting the plan output | Both — Claude explains, user catches anything that looks wrong |

Before each `terraform apply`, Claude asks one **Predict** question (CLAUDE.md comprehension rotation). Examples:
- "How many resources should this plan want to add? Which one will take longest?"
- "If we apply this and the OIDC provider creation races with cluster tagging, what's the symptom?"

---

## Rapid-reference: which pattern to use for which task

When the user asks for X, jump straight to:

| Task | Pattern section |
|---|---|
| Configure AWS / SSO auth | §1, §Pre-flight |
| Reference an SSO role ARN | §2 |
| Configure kubernetes provider | §3 |
| Configure helm provider | §4 |
| Create or modify the EKS cluster / node group | §5 |
| Grant a principal cluster RBAC | §5 (`access_entries`) |
| Create a k8s resource via Terraform | §6 |
| Deploy a Helm chart | §7 |
| Pass a secret to a resource | §8 |
| Set up state backend | §9 |
| Anything else | Search docs for the pinned version, then write a new section here |

---

## Validation & sourcing

**These patterns are validated in `/Users/deepti/Optum/infra/` — they are working code from real deployments, not theory.**

Key validated findings that override GitHub docs / training data:
- **§1 (AWS provider):** Add `default_tags` block for consistent resource tagging (better cost tracking).
- **§3 (Kubernetes exec auth):** Use `env { AWS_PROFILE }` block instead of `--profile` arg (more portable).
- **§4 (Helm provider):** Lead with kubeconfig for local dev; offer exec as CI alternative (simpler for single-developer work).
- **§5 (EKS access entries):** Standalone resources work; always add kubeconfig refresh provisioner immediately after policy association created.
- **§6 (K8s resource naming):** Both `_v1` and legacy names work; migrate incrementally.
- **§7 (Helm deployment):** `null_resource` provisioner is the validated pattern; avoids helm provider auth complexity.
- **§8 (Secrets):** `.env` file approach is current compromise (documented, with TODO for migration to Secrets Manager in Phase 3).

If contradictions arise between this skill and the validated code in `/infra/`, the **code wins**. Update the skill.

## Done well when

- Code applies on the first try (no iteration loop).
- The user can explain *why* the configuration is shaped that way.
- The recommendation cites the specific doc / module file path it came from.
- Nothing was added that isn't in the spec's Implementation outline.
- If a new pattern emerged that isn't in this skill yet, it gets *added* here so future Claude doesn't re-derive it.
