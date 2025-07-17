# User-Assigned Managed Identity for AKS
resource "azurerm_user_assigned_identity" "aks" {
  name                = local.resource_names.identity
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = local.common_tags
}

# Built-in Azure role definitions
data "azurerm_role_definition" "contributor" {
  name = "Contributor"
}

data "azurerm_role_definition" "acr_pull" {
  name = "AcrPull"
}

data "azurerm_role_definition" "network_contributor" {
  name = "Network Contributor"
}

# AKS Managed Identity role assignments (conditional)
resource "azurerm_role_assignment" "aks_identity_contributor" {
  count                = var.create_role_assignments ? 1 : 0
  scope                = data.azurerm_resource_group.main.id
  role_definition_id   = data.azurerm_role_definition.contributor.id
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "aks_identity_network_contributor" {
  count                = var.create_role_assignments ? 1 : 0
  scope                = azurerm_virtual_network.main.id
  role_definition_id   = data.azurerm_role_definition.network_contributor.id
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "aks_identity_acr_pull" {
  count                = var.create_role_assignments ? 1 : 0
  scope                = azurerm_container_registry.main.id
  role_definition_id   = data.azurerm_role_definition.acr_pull.id
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
  principal_type       = "ServicePrincipal"
}

# User role assignment for management (only if principal_id is provided)
resource "azurerm_role_assignment" "user_contributor" {
  count                = var.principal_id != "" ? 1 : 0
  scope                = data.azurerm_resource_group.main.id
  role_definition_id   = data.azurerm_role_definition.contributor.id
  principal_id         = var.principal_id
  principal_type       = "User"
}
