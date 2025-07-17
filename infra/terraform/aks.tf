# Azure Kubernetes Service (AKS) Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = local.resource_names.aks_cluster
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  dns_prefix          = "aks-${local.devops_naming_suffix}"
  kubernetes_version  = var.kubernetes_version
  node_resource_group = local.resource_names.aks_node_rg
  tags                = local.common_tags

  # System Node Pool (required)
  default_node_pool {
    name               = "systempool"
    node_count         = var.aks_system_node_count
    vm_size            = var.aks_system_vm_size
    os_disk_size_gb    = 128
    os_disk_type       = "Managed"
    vnet_subnet_id     = azurerm_subnet.aks.id
    max_pods           = 110
    
    # System node pool should be in zones for HA
    zones = ["1", "2", "3"]
    
    # Node labels for system workloads
    node_labels = {
      "workload-type" = "system"
    }

    upgrade_settings {
      max_surge = "1"
    }
  }

  # Managed Identity Configuration
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  # Network Configuration
  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
    outbound_type      = "loadBalancer"
    service_cidr       = var.aks_service_cidr
    dns_service_ip     = var.aks_dns_service_ip
    load_balancer_sku  = "standard"
  }

  # API Server Configuration
  api_server_access_profile {
    authorized_ip_ranges = []
  }

  # Azure Monitor Integration
  dynamic "oms_agent" {
    for_each = var.enable_log_analytics ? [1] : []
    content {
      log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id
    }
  }

  # Azure Policy Integration
  azure_policy_enabled = var.enable_azure_policy

  # Ingress Application Gateway Integration
  ingress_application_gateway {
    gateway_id = azurerm_application_gateway.main.id
  }

  # Security Profile
  # Workload Identity is enabled for enhanced security
  workload_identity_enabled = true
  oidc_issuer_enabled      = true

  # Maintenance Window (optional)
  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [2, 3, 4]
    }
  }

  # Lifecycle management
  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count,
    ]
  }

  depends_on = [
    azurerm_user_assigned_identity.aks,
    azurerm_application_gateway.main,
  ]
}

# User Node Pool for Application Workloads
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "workerpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.aks_user_vm_size
  os_disk_size_gb       = 128
  os_disk_type          = "Managed"
  vnet_subnet_id        = azurerm_subnet.aks.id
  
  # Auto-scaling configuration
  node_count = var.enable_auto_scaling ? null : var.aks_user_node_count
  min_count  = var.enable_auto_scaling ? var.aks_user_node_min_count : null
  max_count  = var.enable_auto_scaling ? var.aks_user_node_max_count : null
  
  # High availability across zones
  zones = ["1", "2", "3"]
  
  # Node configuration
  max_pods = 110
  
  # Node labels for workload identification
  node_labels = {
    "workload-type" = "application"
  }

  upgrade_settings {
    max_surge = "1"
  }

  tags = local.common_tags
}
