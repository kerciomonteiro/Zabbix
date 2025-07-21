# Kubernetes Provider Configuration
# This file contains the Kubernetes and Helm provider configurations
# Updated to handle AKS cluster readiness and prevent connectivity issues

# Configure Kubernetes provider with proper dependency management
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.main.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate)
  
  # Ensure provider waits for cluster to be fully ready
  depends_on = [
    azurerm_kubernetes_cluster.main,
    time_sleep.wait_for_cluster
  ]
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.main.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate)
  }
  
  # Ensure provider waits for cluster to be fully ready
  depends_on = [
    azurerm_kubernetes_cluster.main,
    time_sleep.wait_for_cluster
  ]
}

# Wait for AKS cluster to be fully ready before configuring Kubernetes resources
resource "time_sleep" "wait_for_cluster" {
  depends_on = [azurerm_kubernetes_cluster.main]
  
  create_duration = "30s"
}
