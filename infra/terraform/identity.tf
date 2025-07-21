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
  count              = var.create_role_assignments ? 1 : 0
  scope              = data.azurerm_resource_group.main.id
  role_definition_id = data.azurerm_role_definition.contributor.id
  principal_id       = azurerm_user_assigned_identity.aks.principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "aks_identity_network_contributor" {
  count              = var.create_role_assignments ? 1 : 0
  scope              = azurerm_virtual_network.main.id
  role_definition_id = data.azurerm_role_definition.network_contributor.id
  principal_id       = azurerm_user_assigned_identity.aks.principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "aks_identity_acr_pull" {
  count              = var.create_role_assignments ? 1 : 0
  scope              = azurerm_container_registry.main.id
  role_definition_id = data.azurerm_role_definition.acr_pull.id
  principal_id       = azurerm_user_assigned_identity.aks.principal_id
  principal_type     = "ServicePrincipal"
}

# User role assignment for management (only if principal_id is provided)
resource "azurerm_role_assignment" "user_contributor" {
  count              = var.principal_id != "" ? 1 : 0
  scope              = data.azurerm_resource_group.main.id
  role_definition_id = data.azurerm_role_definition.contributor.id
  principal_id       = var.principal_id
  principal_type     = "User"
}

# Application Gateway Ingress Controller (AGIC) role assignments
# These are needed for the AGIC to manage the Application Gateway
# Note: The AGIC identity is created automatically by AKS when ingress_application_gateway is configured

# Reader role for AGIC on the resource group
resource "azurerm_role_assignment" "agic_reader" {
  count                = var.create_role_assignments ? 1 : 0
  scope                = data.azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_id         = "1db234fc-dabc-4ead-a0a4-6fdc08cdb0aa"  # AGIC identity object ID
  principal_type       = "ServicePrincipal"
}

# Contributor role for AGIC on the Application Gateway
resource "azurerm_role_assignment" "agic_contributor" {
  count                = var.create_role_assignments ? 1 : 0
  scope                = azurerm_application_gateway.main.id
  role_definition_name = "Contributor"
  principal_id         = "1db234fc-dabc-4ead-a0a4-6fdc08cdb0aa"  # AGIC identity object ID
  principal_type       = "ServicePrincipal"
}

# Wait for managed identity principal to be fully propagated
resource "time_sleep" "wait_for_identity" {
  depends_on = [
    azurerm_user_assigned_identity.aks,
    azurerm_role_assignment.aks_identity_contributor,
    azurerm_role_assignment.aks_identity_network_contributor,
    azurerm_role_assignment.aks_identity_acr_pull,
  ]
  
  create_duration = "60s"
}
