# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  count               = var.enable_log_analytics ? 1 : 0
  name                = local.resource_names.log_analytics
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
  tags                = local.common_tags
}

# Container Registry
resource "azurerm_container_registry" "main" {
  name                = local.resource_names.container_registry
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  sku                 = var.acr_sku
  admin_enabled       = var.acr_admin_enabled
  tags                = local.common_tags

  # Enable system-assigned managed identity
  identity {
    type = "SystemAssigned"
  }

  # Network access configuration
  public_network_access_enabled = true
  network_rule_bypass_option    = "AzureServices"
}

# Multi-Application Monitoring and Observability Configuration
# This extends the monitoring capabilities for multiple applications

# Azure Monitor and Container Insights
# Note: Diagnostic settings are automatically created by Container Insights (oms_agent)
# when enabled in the AKS cluster configuration. No explicit diagnostic setting needed.

# Commented out to prevent conflict with auto-created diagnostic setting
# resource "azurerm_monitor_diagnostic_setting" "aks_diagnostics" {
#   name                       = "aks-diagnostics"
#   target_resource_id         = azurerm_kubernetes_cluster.main.id
#   log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id
#
#   # Enable all available log categories
#   enabled_log {
#     category = "kube-apiserver"
#   }
#
#   enabled_log {
#     category = "kube-controller-manager"
#   }
#
#   enabled_log {
#     category = "kube-scheduler"
#   }
#
#   enabled_log {
#     category = "kube-audit"
#   }
#
#   enabled_log {
#     category = "kube-audit-admin"
#   }
#
#   enabled_log {
#     category = "guard"
#   }
#
#   enabled_log {
#     category = "cluster-autoscaler"
#   }
#
#   # Enable metrics
#   metric {
#     category = "AllMetrics"
#     enabled  = true
#   }
#
#   depends_on = [azurerm_kubernetes_cluster.main]
# }

# Container Insights solution
resource "azurerm_log_analytics_solution" "container_insights" {
  count                 = var.enable_log_analytics ? 1 : 0
  solution_name         = "ContainerInsights"
  location              = var.location
  resource_group_name   = data.azurerm_resource_group.main.name
  workspace_resource_id = azurerm_log_analytics_workspace.main[0].id
  workspace_name        = azurerm_log_analytics_workspace.main[0].name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }

  depends_on = [azurerm_log_analytics_workspace.main]
}

# Application Insights for APM
resource "azurerm_application_insights" "main" {
  count               = var.enable_application_insights ? 1 : 0
  name                = "ai-${local.devops_naming_suffix}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main[0].id
  application_type    = "web"
  retention_in_days   = var.application_insights_retention_days

  tags = local.common_tags
}
