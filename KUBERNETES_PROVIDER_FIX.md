# Kubernetes Provider Import Fix - Implementation Summary

## Problem Description

The GitHub Actions workflow was failing during the Terraform import phase with "Invalid provider configuration" errors:

```
Error: Invalid provider configuration

  on /home/runner/work/Zabbix/Zabbix/infra/terraform/kubernetes.tf line 5:
   5: provider "kubernetes" {

The configuration for provider["registry.terraform.io/hashicorp/kubernetes"] depends on values that cannot be determined until apply.
```

**Root Cause**: The Kubernetes provider configuration in `kubernetes.tf` references `azurerm_kubernetes_cluster.main.kube_config` outputs, but during the import phase, the AKS cluster doesn't exist in Terraform state yet, causing the provider configuration to fail.

## Solution Implemented

### 1. Provider Configuration Separation
- **Created**: `infra/terraform/kubernetes-providers.tf` - Contains only the Kubernetes and Helm provider configurations
- **Modified**: `infra/terraform/kubernetes.tf` - Removed provider configurations, kept only resource definitions

### 2. Workflow Enhancement
Enhanced the GitHub Actions workflow (`deploy-infrastructure` job) with the following changes:

#### A. Pre-Import Provider Disable
```bash
# Temporarily disable Kubernetes provider during import to prevent configuration errors
echo "🔧 Temporarily disabling Kubernetes provider during import phase..."
if [ -f "kubernetes-providers.tf" ]; then
  mv kubernetes-providers.tf kubernetes-providers.tf.disabled
  echo "   ✅ Kubernetes provider temporarily disabled"
fi
```

#### B. Post-AKS-Import Provider Re-enable
```bash
# Re-enable Kubernetes provider after AKS import (if it was successfully imported)
if terraform state show "azurerm_kubernetes_cluster.main" >/dev/null 2>&1; then
  if [ -f "kubernetes-providers.tf.disabled" ]; then
    mv kubernetes-providers.tf.disabled kubernetes-providers.tf
    terraform init  # Re-initialize with Kubernetes provider
    echo "   ✅ Kubernetes provider re-enabled"
  fi
fi
```

#### C. Safety Checks and Cleanup
- **Pre-Plan Check**: Ensures Kubernetes provider is enabled if AKS exists before creating Terraform plan
- **Post-Success Cleanup**: Restores provider state after successful deployment
- **Always-Run Cleanup**: Ensures provider file is restored even if workflow fails

### 3. Test Script
Created `scripts/test-kubernetes-provider-fix.ps1` to validate the fix locally.

## Files Modified

### New Files
- `infra/terraform/kubernetes-providers.tf` - Kubernetes provider configuration
- `scripts/test-kubernetes-provider-fix.ps1` - Test script

### Modified Files
- `.github/workflows/deploy.yml` - Enhanced with provider disable/enable logic
- `infra/terraform/kubernetes.tf` - Removed provider configurations

## How the Fix Works

### Import Phase (Provider Disabled)
1. **Workflow starts**: `kubernetes-providers.tf` contains Kubernetes provider
2. **Import begins**: Provider file renamed to `.disabled`
3. **Terraform init**: Runs without Kubernetes provider (no config errors)
4. **Resource imports**: Azure resources imported successfully
5. **AKS import**: AKS cluster imported into Terraform state

### Post-Import Phase (Provider Re-enabled)
1. **Check AKS state**: Verify AKS cluster exists in Terraform state
2. **Re-enable provider**: Restore `kubernetes-providers.tf`
3. **Re-initialize**: Run `terraform init` with Kubernetes provider
4. **Plan/Apply**: Continue with full configuration

### Error Prevention
- **Multiple safety checks** ensure provider is in correct state
- **Always-run cleanup** prevents provider from being left disabled
- **State verification** ensures AKS exists before enabling Kubernetes resources

## Expected Results

### Before Fix
```
❌ Import failed for Managed Identity (exit code: 1)
Error: Invalid provider configuration
```

### After Fix
```
✅ Successfully imported Managed Identity
✅ Successfully imported AKS Cluster
✅ Kubernetes provider re-enabled
✅ Terraform plan created successfully
✅ Terraform deployment successful
```

## Testing the Fix

### Local Testing
```powershell
.\scripts\test-kubernetes-provider-fix.ps1
```

### GitHub Actions Testing
1. Trigger workflow with `infrastructure-only` deployment
2. Observe import process succeeds without provider errors
3. Verify AKS cluster is imported and provider is re-enabled
4. Confirm Terraform plan/apply works correctly

## Benefits

1. **Eliminates Import Errors**: Resolves "Invalid provider configuration" during import
2. **Maintains Functionality**: Kubernetes resources still work after AKS deployment
3. **Robust Error Handling**: Multiple safeguards prevent broken state
4. **Zero Manual Intervention**: Fully automated disable/enable process
5. **Backward Compatible**: Doesn't break existing functionality

## Technical Implementation Details

### File Structure
```
infra/terraform/
├── kubernetes-providers.tf     # Provider configurations (can be disabled)
├── kubernetes.tf              # Kubernetes resources (always present)
├── main.tf                    # Main Azure resources
└── variables.tf               # Variables

.github/workflows/
└── deploy.yml                 # Enhanced with provider management
```

### Key Workflow Logic
```bash
# Phase 1: Disable provider for import
mv kubernetes-providers.tf kubernetes-providers.tf.disabled

# Phase 2: Import Azure resources (no provider config errors)
terraform init && terraform import ...

# Phase 3: Re-enable provider after AKS exists
mv kubernetes-providers.tf.disabled kubernetes-providers.tf
terraform init

# Phase 4: Plan and apply with full configuration
terraform plan && terraform apply
```

This fix ensures reliable, repeatable Terraform deployments with proper import support and eliminates the "Invalid provider configuration" errors that were blocking the import process.
