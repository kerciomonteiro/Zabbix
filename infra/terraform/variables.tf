# Variables for Multi-Application AKS Infrastructure Terraform deployment

variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "Devops-Test"
}

variable "location" {
  description = "Azure region for resource deployment"
  type        = string
  default     = "eastus"

  validation {
    condition = contains([
      "eastus", "eastus2", "westus", "westus2", "westus3", "centralus",
      "northcentralus", "southcentralus", "westcentralus", "canadacentral",
      "canadaeast", "brazilsouth", "northeurope", "westeurope", "uksouth",
      "ukwest", "francecentral", "germanywestcentral", "norwayeast",
      "switzerlandnorth", "uaenorth", "southafricanorth", "australiaeast",
      "australiasoutheast", "southeastasia", "eastasia", "japaneast",
      "japanwest", "koreacentral", "koreasouth", "southindia", "centralindia",
      "westindia"
    ], var.location)
    error_message = "The location must be a valid Azure region."
  }
}

variable "environment_name" {
  description = "Name of the deployment environment"
  type        = string

  validation {
    condition     = length(var.environment_name) >= 1 && length(var.environment_name) <= 64
    error_message = "Environment name must be between 1 and 64 characters."
  }
}

variable "principal_id" {
  description = "Principal ID of the deployment user for role assignments (optional)"
  type        = string
  default     = ""
}

variable "create_role_assignments" {
  description = "Whether to create role assignments (requires elevated permissions)"
  type        = bool
  default     = false
}

variable "kubernetes_version" {
  description = "Version of Kubernetes to use for the AKS cluster"
  type        = string
  default     = "1.32"
}

variable "aks_system_node_count" {
  description = "Number of nodes in the AKS system node pool"
  type        = number
  default     = 2

  validation {
    condition     = var.aks_system_node_count >= 1 && var.aks_system_node_count <= 10
    error_message = "System node count must be between 1 and 10."
  }
}

variable "aks_user_node_count" {
  description = "Initial number of nodes in the AKS user node pool"
  type        = number
  default     = 3

  validation {
    condition     = var.aks_user_node_count >= 1 && var.aks_user_node_count <= 10
    error_message = "User node count must be between 1 and 10."
  }
}

variable "aks_user_node_min_count" {
  description = "Minimum number of nodes in the AKS user node pool for auto-scaling"
  type        = number
  default     = 2
}

variable "aks_user_node_max_count" {
  description = "Maximum number of nodes in the AKS user node pool for auto-scaling"
  type        = number
  default     = 10
}

variable "aks_system_vm_size" {
  description = "VM size for AKS system node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "aks_user_vm_size" {
  description = "VM size for AKS user node pool"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.224.0.0/12"]
}

variable "aks_subnet_address_prefix" {
  description = "Address prefix for the AKS subnet"
  type        = string
  default     = "10.224.0.0/16"
}

variable "appgw_subnet_address_prefix" {
  description = "Address prefix for the Application Gateway subnet"
  type        = string
  default     = "10.225.0.0/24"
}

variable "aks_service_cidr" {
  description = "CIDR range for Kubernetes services"
  type        = string
  default     = "172.16.0.0/16"
}

variable "aks_dns_service_ip" {
  description = "IP address for the Kubernetes DNS service"
  type        = string
  default     = "172.16.0.10"
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for AKS user node pool"
  type        = bool
  default     = true
}

variable "enable_azure_policy" {
  description = "Enable Azure Policy addon for AKS"
  type        = bool
  default     = true
}

variable "enable_log_analytics" {
  description = "Enable Log Analytics workspace integration"
  type        = bool
  default     = true
}

variable "log_analytics_retention_days" {
  description = "Number of days to retain logs in Log Analytics"
  type        = number
  default     = 30

  validation {
    condition     = var.log_analytics_retention_days >= 30 && var.log_analytics_retention_days <= 730
    error_message = "Log Analytics retention must be between 30 and 730 days."
  }
}

# Variables for Application Insights
variable "enable_application_insights" {
  description = "Enable Application Insights for APM"
  type        = bool
  default     = true
}

variable "application_insights_retention_days" {
  description = "Data retention period for Application Insights"
  type        = number
  default     = 90

  validation {
    condition     = contains([30, 60, 90, 120, 180, 270, 365, 550, 730], var.application_insights_retention_days)
    error_message = "Retention period must be one of: 30, 60, 90, 120, 180, 270, 365, 550, 730 days."
  }
}

# Variables for Multi-Application Security
variable "enable_pod_security_standards" {
  description = "Enable Pod Security Standards for all namespaces"
  type        = bool
  default     = true
}

variable "default_pod_security_standard" {
  description = "Default Pod Security Standard level"
  type        = string
  default     = "restricted"

  validation {
    condition     = contains(["privileged", "baseline", "restricted"], var.default_pod_security_standard)
    error_message = "Pod Security Standard must be one of: privileged, baseline, restricted."
  }
}

variable "enable_workload_identity" {
  description = "Enable Azure Workload Identity for secure pod authentication"
  type        = bool
  default     = true
}

variable "enable_azure_rbac" {
  description = "Enable Azure RBAC for Kubernetes authorization"
  type        = bool
  default     = true
}

# Variables for Application Gateway
variable "appgw_sku_name" {
  description = "SKU name for Application Gateway"
  type        = string
  default     = "Standard_v2"

  validation {
    condition     = contains(["Standard_v2", "WAF_v2"], var.appgw_sku_name)
    error_message = "Application Gateway SKU must be Standard_v2 or WAF_v2."
  }
}

variable "appgw_min_capacity" {
  description = "Minimum capacity for Application Gateway autoscaling"
  type        = number
  default     = 1

  validation {
    condition     = var.appgw_min_capacity >= 1 && var.appgw_min_capacity <= 10
    error_message = "Application Gateway minimum capacity must be between 1 and 10."
  }
}

variable "appgw_max_capacity" {
  description = "Maximum capacity for Application Gateway autoscaling"
  type        = number
  default     = 3

  validation {
    condition     = var.appgw_max_capacity >= 1 && var.appgw_max_capacity <= 125
    error_message = "Application Gateway maximum capacity must be between 1 and 125."
  }
}

variable "enable_waf" {
  description = "Enable Web Application Firewall for Application Gateway"
  type        = bool
  default     = false
}

# Variables for Container Registry
variable "acr_sku" {
  description = "SKU tier for Azure Container Registry"
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "ACR SKU must be Basic, Standard, or Premium."
  }
}

variable "acr_admin_enabled" {
  description = "Enable admin user for Azure Container Registry"
  type        = bool
  default     = false
}

# Variables for Multi-Tenancy
variable "enable_cluster_autoscaler" {
  description = "Enable cluster autoscaler for the AKS cluster"
  type        = bool
  default     = true
}

variable "max_pods_per_node" {
  description = "Maximum number of pods per node"
  type        = number
  default     = 110

  validation {
    condition     = var.max_pods_per_node >= 10 && var.max_pods_per_node <= 250
    error_message = "Maximum pods per node must be between 10 and 250."
  }
}

variable "enable_private_cluster" {
  description = "Enable private cluster for AKS (API server not accessible from internet)"
  type        = bool
  default     = false
}

variable "authorized_ip_ranges" {
  description = "Authorized IP ranges for accessing the AKS API server (when not using private cluster)"
  type        = list(string)
  default     = []
}
