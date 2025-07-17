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
  sku                 = "Standard"
  admin_enabled       = false
  tags                = local.common_tags

  # Enable system-assigned managed identity
  identity {
    type = "SystemAssigned"
  }

  # Network access configuration
  public_network_access_enabled = true
  network_rule_bypass_option    = "AzureServices"
}
