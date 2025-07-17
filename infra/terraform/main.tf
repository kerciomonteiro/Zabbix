# Terraform configuration for Zabbix AKS Infrastructure
# This replaces the Bicep template with Terraform for better multi-cloud support

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azuread" {
}

# Import blocks for existing NSG associations that need to be managed by Terraform
import {
  to = azurerm_subnet_network_security_group_association.aks
  id = "/subscriptions/d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf/resourceGroups/Devops-Test/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus/subnets/subnet-aks-devops-eastus"
}

import {
  to = azurerm_subnet_network_security_group_association.appgw
  id = "/subscriptions/d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf/resourceGroups/Devops-Test/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus/subnets/subnet-appgw-devops-eastus"
}

import {
  to = azurerm_kubernetes_cluster.main
  id = "/subscriptions/d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf/resourceGroups/Devops-Test/providers/Microsoft.ContainerService/managedClusters/aks-devops-eastus"
}

# Data sources for existing resources
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

data "azurerm_client_config" "current" {}

# Local variables for naming convention: resourcename-devops-regionname
locals {
  devops_naming_suffix = "devops-${var.location}"
  
  resource_names = {
    vnet                = "vnet-${local.devops_naming_suffix}"
    aks_cluster         = "aks-${local.devops_naming_suffix}"
    aks_node_rg         = "rg-${var.environment_name}-aks-nodes-${local.devops_naming_suffix}"
    aks_subnet          = "subnet-aks-${local.devops_naming_suffix}"
    appgw_subnet        = "subnet-appgw-${local.devops_naming_suffix}"
    identity            = "id-${local.devops_naming_suffix}"
    log_analytics       = "law-${local.devops_naming_suffix}"
    container_registry  = "acrzabbixdevops${lower(var.location)}"
    app_gateway         = "appgw-${local.devops_naming_suffix}"
    public_ip           = "pip-appgw-${local.devops_naming_suffix}"
    nsg_aks             = "nsg-aks-${local.devops_naming_suffix}"
    nsg_appgw           = "nsg-appgw-${local.devops_naming_suffix}"
  }
  
  common_tags = {
    "azd-env-name" = var.environment_name
    "environment"  = var.environment_name
    "project"      = "zabbix"
    "managed-by"   = "terraform"
  }
}
