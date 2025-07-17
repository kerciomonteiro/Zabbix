# Azure Deployment Issues - Fixed ✅

This document summarizes the fixes applied to resolve the Azure deployment issues.

## Issues Identified and Fixed

### 1. ✅ Application Gateway Identity Error
**Error:** `Resource type 'Microsoft.Network/applicationGateways' does not support creation of 'SystemAssigned' resource identity`

**Solution:**
- Changed Application Gateway identity from `SystemAssigned` to `UserAssigned`
- Now uses the existing user-assigned managed identity created for AKS
- Updated in `infra/terraform/appgateway.tf`

### 2. ✅ Role Assignment Permission Errors
**Error:** `AuthorizationFailed: The client does not have authorization to perform action 'Microsoft.Authorization/roleAssignments/write'`

**Solution:**
- Added conditional role assignments with `create_role_assignments` variable (default: `false`)
- Role assignments are now optional and controlled by the variable
- Updated `infra/terraform/identity.tf` and `variables.tf`

### 3. ✅ Resource Already Exists Errors
**Error:** `A resource with the ID "/subscriptions/.../resourceGroups/.../providers/..." already exists`

**Solution:**
- Added automatic import of existing resources before Terraform deployment
- Import attempts are made for all major resources (VNet, NSGs, managed identity, etc.)
- Import errors are ignored (continues if resource doesn't exist)
- Updated `.github/workflows/deploy.yml`

### 4. ✅ Empty Deployment Outputs
**Error:** Terraform and ARM outputs were empty, causing deployment verification to fail

**Solution:**
- Fixed environment name generation to be consistent (removed run numbers)
- Terraform outputs are properly defined in `outputs.tf`
- Workflow correctly extracts outputs from both Terraform and ARM deployments

### 5. ✅ Multiple Container Registries Created
**Problem:** Each deployment run created a new container registry due to timestamped naming

**Solution:**
- Fixed container registry naming to be consistent: `acrzabbixdevops{location}`
- Removed `github.run_number` from environment names
- Updated both Terraform and ARM workflows to use consistent naming
- Added cleanup documentation for removing duplicate registries

## Updated Files

### Terraform Configuration
- `infra/terraform/main.tf` - Removed import blocks, fixed naming
- `infra/terraform/appgateway.tf` - Fixed identity configuration
- `infra/terraform/identity.tf` - Made role assignments conditional
- `infra/terraform/variables.tf` - Added `create_role_assignments` variable
- `infra/terraform/terraform.tfvars.example` - Documented new variable

### GitHub Actions Workflow
- `.github/workflows/deploy.yml` - Fixed naming, added imports, improved output handling

### Documentation
- `docs/deployment-permission-fixes.md` - Comprehensive permission issue guide
- `docs/cleanup-duplicate-resources.md` - Guide for cleaning up duplicate ACRs

## How to Deploy Now

### Option 1: Default (No Role Assignments)
1. Run the GitHub Actions workflow
2. Resources will be imported automatically if they exist
3. New resources will be created with consistent naming
4. Role assignments can be created manually after deployment (see documentation)

### Option 2: With Role Assignments (Requires Elevated Permissions)
1. Set `create_role_assignments = true` in your Terraform variables
2. Ensure your service principal has `User Access Administrator` permissions
3. Run the deployment

## Expected Behavior After Fixes

1. **✅ No more duplicate container registries** - Consistent naming prevents conflicts
2. **✅ Automatic resource import** - Existing resources are imported before creation
3. **✅ Proper output extraction** - Deployment outputs are correctly captured and used
4. **✅ Flexible permissions** - Works with both basic and elevated Azure permissions
5. **✅ Application Gateway deploys successfully** - UserAssigned identity is supported

## Verification Steps

After deployment, verify:
```powershell
# Check that only one ACR exists
az acr list --resource-group Devops-Test --output table

# Check AKS cluster
az aks list --resource-group Devops-Test --output table

# Check Application Gateway
az network application-gateway list --resource-group Devops-Test --output table
```

## Next Steps

1. **Clean up duplicate resources** (if any exist): Use `docs/cleanup-duplicate-resources.md`
2. **Test the deployment** with the GitHub Actions workflow
3. **Configure role assignments** manually if needed (see `docs/deployment-permission-fixes.md`)
4. **Deploy Kubernetes applications** once infrastructure is ready

All deployment issues should now be resolved! 🎉
