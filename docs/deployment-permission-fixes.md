# Fixing Azure Deployment Permission Issues

This document explains how to resolve common Azure deployment permission issues encountered during Terraform deployment.

## Issues Fixed

### 1. Application Gateway Identity Error

**Error:**
```
Resource type 'Microsoft.Network/applicationGateways' does not support creation of 'SystemAssigned' resource identity. The supported types are 'UserAssigned'.
```

**Solution:**
- Changed Application Gateway identity from `SystemAssigned` to `UserAssigned`
- Using the existing user-assigned managed identity created for AKS
- This provides better security and resource management

### 2. Role Assignment Permission Errors

**Error:**
```
AuthorizationFailed: The client does not have authorization to perform action 'Microsoft.Authorization/roleAssignments/write'
```

**Solution:**
- Added a new variable `create_role_assignments` (default: `false`)
- Made all role assignments conditional based on this variable
- When `create_role_assignments = false`, the deployment will skip role assignments
- Role assignments can be created manually after deployment if needed

## Deployment Options

### Option 1: Deploy without Role Assignments (Recommended)

1. Set `create_role_assignments = false` in your `terraform.tfvars` file (or leave default)
2. Run Terraform deployment normally
3. After successful deployment, manually create the required role assignments:

```powershell
# Get the managed identity principal ID
$identityId = az identity show --name "id-zabbix-devops-eastus" --resource-group "Devops-Test" --query principalId -o tsv

# Assign Contributor role to resource group
az role assignment create --assignee $identityId --role "Contributor" --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/Devops-Test"

# Assign Network Contributor role to VNet
$vnetId = az network vnet show --name "vnet-devops-eastus" --resource-group "Devops-Test" --query id -o tsv
az role assignment create --assignee $identityId --role "Network Contributor" --scope $vnetId

# Assign AcrPull role to Container Registry
$acrId = az acr show --name "acrzabbixdevopseastus29devopseastus" --resource-group "Devops-Test" --query id -o tsv
az role assignment create --assignee $identityId --role "AcrPull" --scope $acrId
```

### Option 2: Deploy with Elevated Permissions

If your service principal has `User Access Administrator` or `Owner` permissions:

1. Set `create_role_assignments = true` in your `terraform.tfvars` file
2. Run Terraform deployment normally
3. Role assignments will be created automatically

## Required Azure Permissions

### For Basic Deployment (Option 1)
- `Contributor` role on the resource group
- OR specific permissions for each resource type being created

### For Role Assignment Creation (Option 2)
- `User Access Administrator` role on the target scopes (resource group, VNet, ACR)
- OR `Owner` role on the target scopes

## Verification

After deployment, verify that the AKS cluster can:
1. Pull images from the Azure Container Registry
2. Create/modify network resources in the VNet
3. Access other resources as needed

You can check role assignments using:
```powershell
# Check all role assignments for the managed identity
az role assignment list --assignee $identityId --output table
```

## Troubleshooting

If you encounter permission issues during deployment:

1. **Check your current permissions:**
   ```powershell
   az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv) --scope "/subscriptions/$(az account show --query id -o tsv)" --output table
   ```

2. **Use Option 1 (skip role assignments)** and create them manually after deployment

3. **Contact your Azure administrator** to grant the necessary permissions for automatic role assignment creation

## Security Notes

- The user-assigned managed identity follows the principle of least privilege
- Role assignments are scoped to specific resources (not subscription-wide)
- Manual role assignment creation allows for better security review and approval processes
