# Terraform Import Error Resolution

## Overview

This document explains how to resolve Terraform import errors that may occur during AKS cluster deployments, particularly when Azure resources already exist but aren't properly tracked in Terraform state.

## Common Import Error Symptoms

You may see errors like:
```
Error: A resource with the ID "/subscriptions/.../providers/Microsoft.OperationsManagement/solutions/ContainerInsights(...)" already exists - to be managed via Terraform this resource needs to be imported into the State.
```

## Root Causes

1. **Partial Previous Deployments**: Previous deployment runs created Azure resources but didn't complete successfully
2. **State Synchronization Issues**: Terraform state became out of sync with actual Azure resources  
3. **Resource Group Reuse**: Using an existing resource group that contains resources from previous deployments
4. **Cluster Recreation**: When AKS node resource group naming changes, the cluster must be recreated

## Automatic Resolution

The deployment workflow includes **automatic import resolution** that handles these scenarios:

### Enhanced Import Helper Scripts

The following scripts work together to resolve import conflicts:

- **`scripts/terraform/terraform-master.sh`** - Orchestrates the import and deployment process
- **`scripts/terraform/terraform-import-helper.sh`** - Handles comprehensive resource imports
- **`fix-missing-terraform-imports.ps1`** - Manual PowerShell recovery script (Windows)

### Resources Automatically Imported

The scripts automatically detect and import these critical resources:

1. **Log Analytics Workspace** (`law-devops-eastus`)
2. **Container Registry** (`acrdevopseastus`)  
3. **Network Security Groups** (`nsg-aks-devops-eastus`, `nsg-appgw-devops-eastus`)
4. **Virtual Network** (`vnet-devops-eastus`)
5. **Public IP** (`pip-appgw-devops-eastus`)
6. **Container Insights Solution** (`ContainerInsights(law-devops-eastus)`)
7. **Application Insights** (`ai-devops-eastus`)
8. **AKS Subnet** (`subnet-aks-devops-eastus`)
9. **App Gateway Subnet** (`subnet-appgw-devops-eastus`)

## Manual Resolution (If Automatic Fails)

### Option 1: PowerShell Script (Windows)

```powershell
# Run the manual import script
./fix-missing-terraform-imports.ps1
```

### Option 2: Manual Terraform Commands

```bash
cd infra/terraform

# Set environment variables
export AZURE_SUBSCRIPTION_ID="d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"
export AZURE_RESOURCE_GROUP="rg-devops-pops-eastus"

# Import specific resources
terraform import "azurerm_log_analytics_solution.container_insights[0]" \
  "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.OperationsManagement/solutions/ContainerInsights(law-devops-eastus)"

terraform import "azurerm_application_insights.main[0]" \
  "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Insights/components/ai-devops-eastus"

terraform import "azurerm_subnet.aks" \
  "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus/subnets/subnet-aks-devops-eastus"

terraform import "azurerm_subnet.appgw" \
  "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus/subnets/subnet-appgw-devops-eastus"
```

### Option 3: Clean State (Nuclear Option)

⚠️ **WARNING: This destroys existing infrastructure**

```bash
# Remove conflicting resources from state
terraform state rm "azurerm_log_analytics_solution.container_insights[0]"
terraform state rm "azurerm_application_insights.main[0]"  
terraform state rm "azurerm_subnet.aks"
terraform state rm "azurerm_subnet.appgw"

# Run terraform apply to recreate
terraform apply
```

## AKS Cluster Recreation Scenario

### When Does This Happen?

The AKS cluster will be **automatically recreated** when:
- The node resource group name changes (e.g., due to naming convention fixes)
- Kubernetes version updates require cluster replacement
- Network configuration changes that require replacement

### What to Expect

1. **Cluster Recreation**: The existing AKS cluster will be destroyed and recreated
2. **Downtime**: Applications will be temporarily unavailable during recreation
3. **Data Persistence**: PVCs and external data sources are preserved
4. **Identity Changes**: Cluster identities and certificates will be regenerated

### Deployment Process During Recreation

```bash
# The workflow automatically handles:
1. Disable Kubernetes provider (prevents API connection errors)
2. Import existing Azure resources 
3. Plan infrastructure changes (shows cluster recreation)
4. Apply changes (recreates cluster)
5. Re-enable Kubernetes provider 
6. Deploy applications to new cluster
```

## Validation

After resolution, verify the deployment:

```bash
# Check Terraform state
terraform state list | grep -E "(container_insights|application_insights|subnet)"

# Verify resources in Azure
az resource list -g rg-devops-pops-eastus --query "[?contains(id, 'ContainerInsights')]"
az resource list -g rg-devops-pops-eastus --query "[?contains(id, 'ai-devops-eastus')]"
```

## Prevention

To avoid import conflicts in future deployments:

1. **Use Unique Resource Groups**: Create new resource groups for each environment
2. **Monitor Deployments**: Don't cancel deployments mid-execution
3. **Clean Failure Recovery**: Use proper cleanup procedures when deployments fail
4. **State Backup**: Regularly backup Terraform state files

## GitHub Actions Workflow Integration

The workflow automatically handles import resolution:

```yaml
# The terraform-master.sh script includes:
- Import existing resources 
- Retry logic for failed imports
- Targeted recovery for critical resources
- Proper error handling and fallback
```

## Troubleshooting

### Import Still Failing?

1. **Check Azure CLI Authentication**:
   ```bash
   az account show
   az account set --subscription "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"
   ```

2. **Verify Resource Existence**:
   ```bash
   az resource show --ids "/subscriptions/.../resourceGroups/rg-devops-pops-eastus/providers/Microsoft.Insights/components/ai-devops-eastus"
   ```

3. **Check Terraform State**:
   ```bash
   terraform state list
   terraform state show "azurerm_application_insights.main[0]"
   ```

### False Positive Errors

Sometimes import errors are **false positives** where:
- Resources are already in Terraform state
- State synchronization temporarily failed
- Concurrent operations caused race conditions

The enhanced scripts detect and handle these scenarios automatically.

## Related Documentation

- [AGIC Installation Fix](AGIC_INSTALLATION_FIX.md)
- [AKS Node Resource Group Fix](AKS_NODE_RESOURCE_GROUP_FIX.md)
- [Main Troubleshooting Guide](README.md#troubleshooting)

---

**Last Updated**: July 2025  
**Status**: ✅ Resolved - Automatic import handling implemented
