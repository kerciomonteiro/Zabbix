# Variables for Zabbix AKS Infrastructure Terraform deployment

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
  default     = "1.29.9"
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
