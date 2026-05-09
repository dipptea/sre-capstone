# Phase 04 Milestone 1 — metrics-server
#
# Why metrics-server: HPA on resource metrics (CPU/memory) requires the
# metrics.k8s.io API. metrics-server is the canonical implementation; without
# it, every HPA sits at `<unknown>/70%` forever. See specs/phase-04.md
# Decision 1.
#
# Why helm_release (vs null_resource + local-exec used by Datadog and LBC):
# helm_release is a proper Terraform resource — chart, version, namespace, and
# values are tracked as resource attributes, so `terraform plan` shows real
# drift and `terraform apply` upgrades on version bumps without manual taints.
# Datadog and LBC will migrate to this pattern when next touched. See spec
# Decision log entry dated 2026-05-08.

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"

  # Pinned for reproducibility. Verify the latest stable before bumping:
  #   helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
  #   helm repo update
  #   helm search repo metrics-server/metrics-server --versions | head
  version = "3.12.2"

  # If `kubectl top nodes` returns x509 errors against kubelet after apply,
  # uncomment the block below. EKS managed clusters sometimes ship kubelet
  # serving certs not signed by the cluster CA — common workaround. See
  # spec Open question 2.
  #
  # set {
  #   name  = "args[0]"
  #   value = "--kubelet-insecure-tls"
  # }

  depends_on = [
    module.eks,
    aws_eks_access_policy_association.capstone_admin,
  ]
}

output "metrics_server_verification" {
  value       = "kubectl top nodes && kubectl top pods -A"
  description = "Commands to confirm metrics-server is feeding the metrics API."
}
