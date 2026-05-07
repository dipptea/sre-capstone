# Phase 03 Milestone 1 — GitHub Actions OIDC trust to AWS.
#
# Adds an IAM OIDC identity provider so GitHub-hosted Actions runners can
# authenticate to AWS via short-lived OIDC tokens — no static AWS keys
# stored in GitHub repository secrets.
#
# This provider sits ALONGSIDE the existing EKS OIDC provider (Phase 01).
# They're separate AWS resources because each issues tokens with a different
# `iss` claim:
#   - EKS:    oidc.eks.us-east-1.amazonaws.com/id/<cluster-id>
#   - GitHub: token.actions.githubusercontent.com
#
# Subsequent milestones add: the IAM Role that trusts this provider (M2),
# and the EKS access entry that grants Kubernetes RBAC to that role (M3).

# Fetch GitHub's TLS certificate at plan time so we always pin to the
# CURRENT thumbprint. If GitHub rotates their cert, a `terraform apply`
# refreshes this — without that refresh, all GitHub Actions auth would
# silently break (see Phase 03 spec Failure-mode notes).
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

output "github_oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.github.arn
  description = "ARN of the GitHub Actions OIDC provider — referenced by the gh-actions-deployer IAM Role's trust policy in Milestone 2."
}

# ----------------------------------------------------------------------------
# Phase 03 Milestone 2 — IAM Role for GitHub Actions to assume.
# ----------------------------------------------------------------------------
# Trust policy:
#   - Federated principal = the GitHub OIDC provider from M1.
#   - Conditions (BOTH must match for AssumeRoleWithWebIdentity to succeed):
#       aud: sts.amazonaws.com     (AWS standard audience claim)
#       sub: repo:dipptea/sre-capstone:ref:refs/heads/main
#            ↑ locks role to main-branch pushes ONLY
#            PRs from forks, feature branches, etc. cannot assume this role.

data "aws_iam_policy_document" "gh_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:dipptea/sre-capstone:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "gh_actions_deployer" {
  name               = "gh-actions-deployer"
  assume_role_policy = data.aws_iam_policy_document.gh_actions_assume_role.json
  description        = "Assumed by GitHub Actions on push to main. Used to push images to ECR and deploy to EKS via Helm."
}

# ----------------------------------------------------------------------------
# Inline policy — minimum-scope permissions for ECR push + EKS describe.
# ----------------------------------------------------------------------------
# K8s-side RBAC (the actual `helm upgrade` permission) is granted via the
# EKS access entry in Milestone 3, NOT in this IAM policy.

data "aws_iam_policy_document" "gh_actions_permissions" {
  # ECR push verbs — scoped to the project's service repos.
  # Phase 03 added payment; Phase 03b extended to risk-check.
  statement {
    sid    = "EcrPushToServiceRepos"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [
      aws_ecr_repository.payment.arn,
      aws_ecr_repository.risk_check.arn,
    ]
  }

  # ECR GetAuthorizationToken — cannot be scoped to a repo (AWS API limitation).
  # Token returned only allows pulling/pushing to repos this role already has
  # access to via the statement above.
  statement {
    sid       = "EcrAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # EKS DescribeCluster — needed by `aws eks update-kubeconfig` and
  # `aws eks get-token` (used by helm to authenticate to the K8s API).
  # Scoped to capstone-sre-cluster only.
  statement {
    sid       = "EksDescribeCluster"
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = [module.eks.cluster_arn]
  }
}

resource "aws_iam_role_policy" "gh_actions_deployer" {
  name   = "gh-actions-deployer-permissions"
  role   = aws_iam_role.gh_actions_deployer.id
  policy = data.aws_iam_policy_document.gh_actions_permissions.json
}

output "gh_actions_deployer_role_arn" {
  value       = aws_iam_role.gh_actions_deployer.arn
  description = "ARN of the IAM Role assumed by GitHub Actions — referenced by .github/workflows/deploy.yml in Milestone 4."
}

# ----------------------------------------------------------------------------
# Phase 03 Milestone 3 — EKS access entry for the GH Actions role.
# ----------------------------------------------------------------------------
# AWS-side IAM permissions (M2) let the role talk to AWS APIs, but they
# don't grant it any access to the *Kubernetes* API. `helm upgrade` calls
# the K8s API, which has its own RBAC system that EKS bridges via access
# entries.
#
# AmazonEKSClusterAdminPolicy: broad (cluster-admin equivalent), same scope
# as the CapstoneAdmin SSO role's existing access entry. Tighter scoping
# (e.g., per-namespace) deferred to Phase 07 per resolved Open question #1.
#
# No kubeconfig-refresh provisioner here — that's only needed when granting
# access to the principal that operates the LOCAL kubectl, which is the
# CapstoneAdmin SSO role (handled in eks.tf). GH Actions builds its own
# kubeconfig fresh in each workflow run via `aws eks update-kubeconfig`.

resource "aws_eks_access_entry" "gh_actions" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.gh_actions_deployer.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "gh_actions" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.gh_actions_deployer.arn

  access_scope {
    type = "cluster"
  }
}
