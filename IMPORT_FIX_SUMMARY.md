# Terraform Import Error Fixes - December 2024

## Issue Summary

The Zabbix deployment workflow was experiencing "resource already exists" errors during Terraform apply operations. These errors occurred because Azure resources existed in the target resource group (`rg-devops-pops-eastus`) but were not properly imported into the Terraform state file.

## Root Cause

1. **State/Resource Drift**: After migrating to a new resource group, some Azure resources existed but weren't tracked in Terraform state
2. **Incomplete Import Logic**: The original import logic didn't comprehensively check for and import all required resources
3. **Import Conflicts**: Some resources were partially in state but pointing to wrong resource groups or had outdated configurations

## Key Error Messages Fixed

```
Error: A resource with the ID "/subscriptions/.../id-devops-eastus" already exists
Error: A resource with the ID "/subscriptions/.../acrdevopseastus" already exists  
Error: A resource with the ID "/subscriptions/.../nsg-aks-devops-eastus" already exists
Error: A resource with the ID "/subscriptions/.../law-devops-eastus" already exists
```

## Solutions Implemented

### 1. Enhanced Resource Existence Checking

**Before**: Basic resource import without verification
```bash
terraform import resource_name resource_id || echo "import failed"
```

**After**: Comprehensive existence checking before import
```bash
# Check if resource exists in Azure
az identity show --resource-group "$RG" --name "id-devops-eastus" &>/dev/null && echo "exists" || echo "missing"

# Check if already in Terraform state  
if grep -q "^resource_name$" current_state.txt; then
  echo "already in state, skipping import"
else
  # Import only if exists in Azure and not in state
  terraform import resource_name resource_id
fi
```

### 2. State Cleanup Before Import

**Problem**: Resources in state pointing to old/wrong resource groups
**Solution**: Remove from state before re-importing
```bash
# Remove existing state entry to avoid conflicts
terraform state rm azurerm_user_assigned_identity.aks 2>/dev/null || echo "No existing state"
# Then import fresh
terraform import azurerm_user_assigned_identity.aks "/subscriptions/.../id-devops-eastus"
```

### 3. Comprehensive Resource Coverage

Added imports for all resources that could cause conflicts:

- ✅ Managed Identity (`id-devops-eastus`)
- ✅ Log Analytics Workspace (`law-devops-eastus`) 
- ✅ Container Registry (`acrdevopseastus`)
- ✅ Network Security Groups (`nsg-aks-devops-eastus`, `nsg-appgw-devops-eastus`)
- ✅ Virtual Network (`vnet-devops-eastus`)
- ✅ Subnets (`subnet-aks-devops-eastus`, `subnet-appgw-devops-eastus`)
- ✅ Public IP (`pip-appgw-devops-eastus`)
- ✅ Application Gateway (`appgw-devops-eastus`)
- ✅ NSG Associations 
- ✅ AKS Cluster (`aks-devops-eastus`)

### 4. Better Error Handling and Diagnostics

**Added**:
- Resource existence verification before import attempts
- Detailed logging of each import operation with success/failure status
- State comparison (resources in Terraform vs resources in Azure)
- Plan summary showing what changes would be applied after import
- Improved error messages and debugging information

**Example Output**:
```bash
🔍 Checking for specific resources that are causing conflicts...
✅ id-devops-eastus exists
✅ acrdevopseastus exists  
✅ nsg-aks-devops-eastus exists
📥 Importing managed identity...
✅ Managed identity imported
📊 Import Summary:
Resources in Terraform state: 15
Resources in Azure RG: 18
```

### 5. Plan Validation After Import

Added comprehensive plan validation to ensure imports were successful:

```bash
# Create plan after imports to see remaining changes
terraform plan -out=$PLAN_FILE -detailed-exitcode
if [ $PLAN_EXIT_CODE -eq 2 ]; then
  echo "Plan has changes to apply"
  # Show plan summary for review
  terraform show -no-color $PLAN_FILE | head -30
fi
```

## Files Modified

1. **`.github/workflows/deploy.yml`**:
   - Enhanced import logic in the "Deploy Infrastructure" step
   - Added comprehensive resource existence checking
   - Improved error handling and logging
   - Added plan validation after imports

2. **`scripts/test-import-fix.ps1`** (New):
   - PowerShell helper script to commit changes and trigger workflow
   - Automated testing of the import fixes

## Testing Strategy

1. **Commit and push all changes** ✅
2. **Trigger workflow with `infra-only` + `plan-and-apply` mode** 
3. **Monitor workflow execution** to verify:
   - Resources are properly detected in Azure
   - Imports succeed without conflicts
   - Terraform plan shows minimal/expected changes
   - Apply succeeds without "resource already exists" errors

## Expected Outcome

After these fixes, the workflow should:

1. ✅ Successfully detect existing Azure resources
2. ✅ Import them into Terraform state without conflicts  
3. ✅ Show a clean Terraform plan with expected changes only
4. ✅ Apply infrastructure changes without "already exists" errors
5. ✅ Proceed to application deployment phase

## Next Steps

1. **Manual Trigger Required**: Go to GitHub Actions and run the workflow with:
   - Deployment Type: `infra-only`
   - Deployment Mode: `plan-and-apply`  
   - Resource Group: `rg-devops-pops-eastus`
   - AKS Cluster: `aks-devops-eastus`

2. **Monitor Results**: Check workflow logs for:
   - Import success messages
   - Clean Terraform plan
   - Successful infrastructure apply

3. **Full Deployment Test**: Once infrastructure-only succeeds, test full deployment (`full` + `plan-and-apply`)

## Backup Plan

If issues persist:
- Use `destroy-and-recreate` mode to start fresh
- Check Azure portal for any resources not covered by import logic
- Add additional resource imports as needed

---
**Status**: ✅ Implemented and committed (commit: 56b5ed8)  
**Next Action**: Manual workflow trigger required to test fixes
