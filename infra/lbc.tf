# Phase 02 Milestone 4 — AWS Load Balancer Controller (LBC) install
#
# Three concerns wired together:
#   1. IRSA — IAM role + AWS-published LBC policy. Trust policy allows ONLY
#      the kube-system/aws-load-balancer-controller ServiceAccount to assume
#      the role, via the EKS cluster's OIDC provider (created in Phase 01 by
#      `enable_irsa = true` on the EKS module).
#   2. Helm install of the LBC chart into kube-system. The chart creates its
#      own ServiceAccount; we annotate it with the IRSA role ARN — that
#      annotation is the magic that completes the IRSA wiring.
#   3. Outputs for verification.

# IAM role + AWS-published LBC policy via the IRSA submodule from
# terraform-aws-modules/iam. The submodule maintains the latest LBC policy
# JSON internally, so we don't hand-pin a stale copy that would silently miss
# new permissions when the LBC chart is upgraded.
module "lbc_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.project_name}-lbc-irsa"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# Helm install the LBC chart. The serviceAccount.annotations.* setting is what
# binds the chart's auto-created ServiceAccount to the IRSA role above.
resource "null_resource" "lbc_helm_release" {
  depends_on = [
    module.lbc_irsa,
    aws_eks_access_policy_association.capstone_admin,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      export AWS_PROFILE=capstone-admin
      helm repo add eks https://aws.github.io/eks-charts --force-update
      helm repo update
      helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
        --namespace kube-system \
        --version 1.11.0 \
        --set clusterName=${module.eks.cluster_name} \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=${module.lbc_irsa.iam_role_arn}" \
        --set region=${var.aws_region} \
        --set vpcId=${module.vpc.vpc_id}
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "helm uninstall aws-load-balancer-controller --namespace kube-system 2>/dev/null || true"
  }
}

output "lbc_iam_role_arn" {
  value       = module.lbc_irsa.iam_role_arn
  description = "IAM role ARN assumed by the LBC ServiceAccount via IRSA — used to verify the trust policy is correct."
}

output "lbc_verification" {
  value       = "kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller"
  description = "Command to check LBC pod status — should show Running 1/1 once the Helm release converges."
}
