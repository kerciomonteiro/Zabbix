# AKS Node Resource Group Naming Fix

## Problem
The AKS cluster node resource group was being created with a malformed name due to hardcoded naming in the Terraform configuration:

**Before (Incorrect)**: `rg-zabbix-devops-eastus-aks-nodes-devops-eastus`
- Duplicated "devops-eastus"
- Hardcoded "zabbix" prefix
- Inconsistent with other resource naming

**After (Correct)**: `rg-aks-nodes-devops-eastus`
- Follows consistent naming pattern: `resourcename-devops-regionname`
- Removes duplication
- Uses dynamic naming based on variables

## Root Cause
In `infra/terraform/main.tf`, the `aks_node_rg` was hardcoded instead of following the dynamic naming pattern:

```terraform
# Before (incorrect)
aks_node_rg = "rg-zabbix-devops-eastus-aks-nodes-devops-eastus"

# After (correct)
aks_node_rg = "rg-aks-nodes-${local.devops_naming_suffix}"
```

## Solution Applied
Updated the Terraform configuration to use the proper naming convention that matches all other resources.

## Impact on Existing Deployments

### New Deployments
- Will automatically use the correct node resource group name
- No manual intervention required

### Existing Deployments
If you have an existing AKS cluster with the malformed node resource group name, you have two options:

#### Option 1: Keep Current Deployment (Recommended)
If your current deployment is working, you can continue using it. The malformed name doesn't affect functionality, only consistency.

#### Option 2: Redeploy with Correct Naming
If you want consistent naming, redeploy the infrastructure:

1. **Clean Redeploy via GitHub Actions**:
   - Go to GitHub Actions → Deploy AKS Zabbix Infrastructure
   - Select "redeploy-clean" deployment type
   - This will create new infrastructure with correct naming

2. **Manual Cleanup** (if needed):
   ```bash
   # Delete the old node resource group (only if you're doing a clean redeploy)
   az group delete --name "rg-zabbix-devops-eastus-aks-nodes-devops-eastus" --yes
   ```

## Verification

After deployment, verify the correct resource group naming:

```bash
# Check AKS cluster details
az aks show --name "aks-devops-eastus" --resource-group "rg-devops-pops-eastus" --query "nodeResourceGroup"

# Expected output: "rg-aks-nodes-devops-eastus"
```

## Benefits of This Fix

1. **Consistency**: All resources now follow the same naming pattern
2. **Maintainability**: Dynamic naming makes it easier to deploy to different regions
3. **Clarity**: Removes confusing duplicate suffixes
4. **Scalability**: Pattern works for multi-region deployments

## Files Modified
- `infra/terraform/main.tf` - Fixed `aks_node_rg` naming pattern

## No Breaking Changes
This change only affects new deployments. Existing deployments continue to work with the old naming.
