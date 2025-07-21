# Kubernetes Resource Idempotency Management
# This file ensures Kubernetes resources are properly managed by Terraform

# Note: This null resource is a placeholder that ensures proper dependency ordering
# All Kubernetes resources depend on this to ensure cluster readiness before creation
resource "null_resource" "k8s_resources_ready" {
  # This resource indicates that the cluster is ready for Kubernetes resource management
  triggers = {
    cluster_id    = azurerm_kubernetes_cluster.main.id
    cluster_ready = null_resource.verify_cluster_ready.id
  }

  depends_on = [
    azurerm_kubernetes_cluster.main,
    time_sleep.wait_for_cluster,
    null_resource.verify_cluster_ready
  ]
}
