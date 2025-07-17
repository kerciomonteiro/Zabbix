# GitHub Actions Deployment Fixes

This document outlines the fixes applied to resolve the GitHub Actions deployment issues.

## Issues Identified

### 1. Kubernetes Version Compatibility Error
```
Error: creating Kubernetes Cluster: "K8sVersionNotSupported",
"message": "Managed cluster aks-devops-eastus is on version 1.29.9, which is only available for Long-Term Support (LTS)"
```

**Root Cause**: The existing AKS cluster was on version 1.32, but Terraform configuration was set to 1.31.2, causing a version mismatch.

**Fix**: Updated Kubernetes version to 1.32 to match the existing cluster.

### 2. Resource Already Exists Error
```
Error: A resource with the ID "...subnet-aks-devops-eastus" already exists - 
to be managed via Terraform this resource needs to be imported into the State.
```

**Root Cause**: NSG associations for subnets already existed in Azure but were not in Terraform state.

**Fix**: Added import blocks for existing NSG associations:
- `azurerm_subnet_network_security_group_association.aks`
- `azurerm_subnet_network_security_group_association.appgw`

### 3. AKS Import ID Format Error
```
Error: parsing "/subscriptions/.../resourcegroups/...": parsing segment "staticResourceGroups": 
the segment at position 2 didn't match
```

**Root Cause**: Incorrect casing in resource ID - used `resourcegroups` instead of `resourceGroups`.

**Fix**: Corrected the AKS cluster import ID format.

## Applied Fixes

### 1. Updated main.tf
```terraform
# Fixed import blocks with correct resource ID formats
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
```

### 2. Version Configuration
- **variables.tf**: `kubernetes_version` default = "1.32"
- **terraform.tfvars**: `kubernetes_version = "1.32"`
- **deploy.yml**: `kubernetes_version = "1.32"`

### 3. AKS Configuration
- **aks.tf**: Added `sku_tier = "Free"` to match existing cluster

## Verification Commands

To verify the current state:

```powershell
# Check AKS cluster version
az aks list --resource-group "Devops-Test" --query "[].{Name:name, KubernetesVersion:kubernetesVersion, ProvisioningState:provisioningState}" --output table

# Check NSG associations
az network vnet subnet list --resource-group "Devops-Test" --vnet-name "vnet-devops-eastus" --query "[].{Name:name, NSG:networkSecurityGroup.id}" --output table

# Check available AKS versions
az aks get-versions --location eastus --query "values[?isPreview!=true].version" --output table
```

## Next Steps

1. **Monitor GitHub Actions**: The workflow should now complete successfully with the corrected configurations
2. **Import Execution**: The import blocks will automatically import existing resources into Terraform state
3. **Remove Import Blocks**: After successful import, remove the import blocks from main.tf
4. **Validate Deployment**: Ensure all resources are properly managed by Terraform

## Status

✅ **Fixed**: AKS resource ID format error  
✅ **Fixed**: Kubernetes version compatibility  
✅ **Fixed**: NSG association resource conflicts  
✅ **Committed**: All changes pushed to GitHub  
🔄 **Pending**: GitHub Actions workflow execution validation  

The deployment should now proceed successfully through the GitHub Actions pipeline.
