# Output values for integration with other systems and CI/CD pipelines

# Azure Information
output "AZURE_LOCATION" {
  description = "Azure region where resources are deployed"
  value       = var.location
}

output "AZURE_TENANT_ID" {
  description = "Azure AD Tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

output "AZURE_SUBSCRIPTION_ID" {
  description = "Azure Subscription ID"
  value       = data.azurerm_client_config.current.subscription_id
}

output "AZURE_RESOURCE_GROUP" {
  description = "Azure Resource Group name"
  value       = data.azurerm_resource_group.main.name
}

output "RESOURCE_GROUP_ID" {
  description = "Azure Resource Group ID"
  value       = data.azurerm_resource_group.main.id
}

# AKS Cluster Information
output "AKS_CLUSTER_NAME" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "AKS_CLUSTER_ID" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.id
}

output "AKS_CLUSTER_FQDN" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "AKS_CLUSTER_PORTAL_FQDN" {
  description = "Portal FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.portal_fqdn
}

output "AKS_CLUSTER_NODE_RESOURCE_GROUP" {
  description = "Node resource group of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}

output "AKS_CLUSTER_KUBE_CONFIG" {
  description = "Raw Kubernetes configuration for the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

# Container Registry Information
output "CONTAINER_REGISTRY_ENDPOINT" {
  description = "Login server endpoint for the container registry"
  value       = azurerm_container_registry.main.login_server
}

output "CONTAINER_REGISTRY_NAME" {
  description = "Name of the container registry"
  value       = azurerm_container_registry.main.name
}

output "CONTAINER_REGISTRY_ID" {
  description = "ID of the container registry"
  value       = azurerm_container_registry.main.id
}

# Network Information
output "VNET_ID" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "VNET_NAME" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "AKS_SUBNET_ID" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.aks.id
}

output "APPGW_SUBNET_ID" {
  description = "ID of the Application Gateway subnet"
  value       = azurerm_subnet.appgw.id
}

# Application Gateway Information
output "APPLICATION_GATEWAY_NAME" {
  description = "Name of the Application Gateway"
  value       = azurerm_application_gateway.main.name
}

output "APPLICATION_GATEWAY_ID" {
  description = "ID of the Application Gateway"
  value       = azurerm_application_gateway.main.id
}

# Public IP Information
output "PUBLIC_IP_ADDRESS" {
  description = "Public IP address of the Application Gateway"
  value       = azurerm_public_ip.appgw.ip_address
}

output "PUBLIC_IP_FQDN" {
  description = "FQDN of the public IP"
  value       = azurerm_public_ip.appgw.fqdn
}

# Log Analytics Information
output "LOG_ANALYTICS_WORKSPACE_ID" {
  description = "ID of the Log Analytics workspace"
  value       = var.enable_log_analytics ? azurerm_log_analytics_workspace.main[0].id : null
}

output "LOG_ANALYTICS_WORKSPACE_NAME" {
  description = "Name of the Log Analytics workspace"
  value       = var.enable_log_analytics ? azurerm_log_analytics_workspace.main[0].name : null
}

# User-Assigned Identity Information
output "USER_ASSIGNED_IDENTITY_ID" {
  description = "ID of the user-assigned managed identity"
  value       = azurerm_user_assigned_identity.aks.id
}

output "USER_ASSIGNED_IDENTITY_CLIENT_ID" {
  description = "Client ID of the user-assigned managed identity"
  value       = azurerm_user_assigned_identity.aks.client_id
}

output "USER_ASSIGNED_IDENTITY_PRINCIPAL_ID" {
  description = "Principal ID of the user-assigned managed identity"
  value       = azurerm_user_assigned_identity.aks.principal_id
}

# Additional useful outputs for automation
output "KUBECONFIG_CONTEXT_NAME" {
  description = "Kubectl context name for the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "RESOURCE_NAMES" {
  description = "Map of all resource names using DevOps naming convention"
  value       = local.resource_names
}

output "DEVOPS_NAMING_SUFFIX" {
  description = "DevOps naming suffix used for all resources"
  value       = local.devops_naming_suffix
}
