# AKS Cluster Import Issue Resolution

## 🎯 Current Issue: AKS Cluster Import Conflict

**Error Message:**
```
Error: A resource with the ID "/subscriptions/d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf/resourceGroups/rg-devops-pops-eastus/providers/Microsoft.ContainerService/managedClusters/aks-devops-eastus" already exists - to be managed via Terraform this resource needs to be imported into the State.
```

**Root Cause:** The AKS cluster `aks-devops-eastus` exists in Azure but is not in the Terraform state, causing Terraform to fail when trying to create it.

## 🔧 Solution Applied

### Enhanced Import Script
The `terraform-import-fix.sh` script has been enhanced with better AKS cluster import handling:

1. **Enhanced Diagnostics**: Detailed cluster analysis before import
2. **Configuration Compatibility Check**: Detects if existing cluster matches Terraform config
3. **Multiple Resolution Paths**: Import, recreation, or configuration adjustment options
4. **Better Error Handling**: Clear messaging for different failure scenarios

### New Troubleshooting Tool
Created `scripts/terraform/aks-import-troubleshoot.sh` for dedicated AKS cluster import diagnostics:

- Step-by-step analysis of Terraform state vs Azure reality
- Cluster property comparison with Terraform configuration
- Specific resolution recommendations based on error type
- Manual recovery options when automated import fails

## 📋 Resource Group Clarification

**Main Resource Group:** `rg-devops-pops-eastus` ✅  
- This is the main resource group containing all the infrastructure
- Created manually/externally and referenced by Terraform via `data.azurerm_resource_group.main`
- **Not created by Terraform** - uses existing resource group

**AKS Node Resource Group:** `rg-aks-nodes-devops-eastus` ✅  
- This is automatically created by Azure when deploying AKS cluster
- Contains the underlying cluster infrastructure (VMs, NICs, disks, etc.)
- **Expected behavior** - not a duplicate or error
- Name controlled by `node_resource_group` parameter in AKS Terraform config

## 🔍 Current Status

### What's Working
- ✅ Managed identity credential issue resolved (60-second propagation delay added)
- ✅ All role assignments and dependencies properly configured
- ✅ Import script handles most resource import conflicts
- ✅ Resource group naming is correct and consistent

### Current Challenge
- ❌ AKS cluster exists but not in Terraform state
- ❌ Import may fail due to configuration drift between existing cluster and Terraform config

## 🚀 Resolution Options

### Option 1: Automated Import (Recommended)
The enhanced import script will attempt to import the cluster automatically:
```bash
cd infra/terraform
../../scripts/terraform/terraform-import-fix.sh
```

### Option 2: Manual Import Troubleshooting
If automated import fails, use the detailed troubleshooting script:
```bash
cd infra/terraform
../../scripts/terraform/aks-import-troubleshoot.sh
```

### Option 3: Cluster Recreation (If Configuration Drift)
If the existing cluster configuration is incompatible with Terraform:
```bash
# WARNING: This will cause downtime!
az aks delete --name aks-devops-eastus --resource-group rg-devops-pops-eastus
terraform apply  # Will recreate cluster with correct configuration
```

## 📊 Expected Outcome

After successful resolution:
1. ✅ AKS cluster imported into Terraform state
2. ✅ `terraform plan` shows no changes (or only minor updates)
3. ✅ `terraform apply` completes successfully
4. ✅ Zabbix application deployment proceeds
5. ✅ Full end-to-end deployment success

## 🔄 Next Steps

1. **Monitor GitHub Actions**: Check if automated import resolves the issue
2. **Manual Intervention**: Use troubleshooting script if automated import fails
3. **Configuration Review**: Verify Terraform config matches existing cluster if import issues persist
4. **Deployment Completion**: Proceed with application deployment after infrastructure is stable

---

**Created**: July 21, 2025  
**Status**: Active issue - solution applied, monitoring results  
**Related**: MANAGED_IDENTITY_FIX.md, TERRAFORM_IMPORT_FIX_UPDATED.md
