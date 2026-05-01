# Read Datadog API key from local .env file
# TODO (Phase 3): Migrate to `sensitive = true` variable or AWS Secrets Manager.
# Current approach (.env file) is a learning-capstone compromise for fast iteration.
# Before Phase 3 (CI/CD), move this to a proper secret store to avoid:
# - Accidental .env commits (add to .gitignore if not already there)
# - Leaks through plan output (use sensitive = true on variables)
# - Exposure in local-exec command lines
locals {
  datadog_api_key = file("${path.module}/../.env") != "" ? regex("DATADOG_API_KEY=([^\n]+)", file("${path.module}/../.env"))[0] : ""
}

# Kubernetes namespace for Datadog
resource "kubernetes_namespace" "datadog" {
  metadata {
    name = "datadog"
    labels = {
      "app.kubernetes.io/name" = "datadog"
    }
  }
  depends_on = [
    module.eks,
    aws_eks_access_policy_association.capstone_admin
  ]
}

# Deploy Datadog agent via Helm using local-exec
resource "null_resource" "datadog_helm_release" {
  depends_on = [kubernetes_namespace.datadog]

  provisioner "local-exec" {
    command = <<-EOT
      export AWS_PROFILE=capstone-admin
      helm repo add datadog https://helm.datadoghq.com --force-update
      helm repo update
      helm upgrade --install datadog datadog/datadog \
        --namespace datadog \
        --version 3.62.0 \
        --set datadog.apiKey=${local.datadog_api_key} \
        --set datadog.site=us5.datadoghq.com \
        --set agents.enabled=true \
        --set agents.rbac.create=true \
        --set agents.tolerations[0].operator=Exists \
        --set apm.enabled=true \
        --set logs.enabled=true \
        --set clusterAgent.enabled=false \
        --set processAgent.enabled=false
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "helm uninstall datadog --namespace datadog 2>/dev/null || true"
  }
}

# Output for verification
output "datadog_namespace" {
  value       = kubernetes_namespace.datadog.metadata[0].name
  description = "Datadog namespace"
}

output "datadog_deployment_status" {
  value       = "Verify with: kubectl get pods -n ${kubernetes_namespace.datadog.metadata[0].name}"
  description = "Command to check Datadog agent pods"
}
