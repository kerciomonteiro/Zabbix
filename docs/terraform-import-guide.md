# Import Existing Azure Resources into Terraform State

This script helps import existing Azure resources into Terraform state to avoid "resource already exists" errors.

## Prerequisites

1. Ensure you're in the correct Terraform directory
2. Have the correct Azure credentials configured
3. Run `terraform init` first

## Import Commands

Run these commands from the `infra/terraform` directory:

```powershell
# Change to Terraform directory
cd "infra\terraform"

# Initialize Terraform (if not already done)
terraform init

# Import existing resources
terraform import azurerm_user_assigned_identity.aks "/subscriptions/d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf/resourceGroups/Devops-Test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-devops-eastus"

terraform import azurerm_log_analytics_workspace.main[0] "/subscriptions/d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf/resourceGroups/Devops-Test/providers/Microsoft.OperationalInsights/workspaces/law-devops-eastus"

terraform import azurerm_network_security_group.aks "/subscriptions/d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf/resourceGroups/Devops-Test/providers/Microsoft.Network/networkSecurityGroups/nsg-aks-devops-eastus"

terraform import azurerm_network_security_group.appgw "/subscriptions/d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf/resourceGroups/Devops-Test/providers/Microsoft.Network/networkSecurityGroups/nsg-appgw-devops-eastus"

terraform import azurerm_virtual_network.main "/subscriptions/d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf/resourceGroups/Devops-Test/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus"

terraform import azurerm_public_ip.appgw "/subscriptions/d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf/resourceGroups/Devops-Test/providers/Microsoft.Network/publicIPAddresses/pip-appgw-devops-eastus"

# Check if there are other resources to import
# You may need to import additional resources like subnets, ACR, etc.

# Check the current state
terraform plan
```

## Additional Resources That May Need Importing

You may also need to import these resources if they exist:

```powershell
# List existing resources to find their IDs
az resource list --resource-group Devops-Test --output table

# Import subnets (get subnet names first)
az network vnet subnet list --vnet-name vnet-devops-eastus --resource-group Devops-Test --output table

# Import AKS subnet
terraform import azurerm_subnet.aks "/subscriptions/d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf/resourceGroups/Devops-Test/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus/subnets/subnet-aks-devops-eastus"

# Import Application Gateway subnet
terraform import azurerm_subnet.appgw "/subscriptions/d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf/resourceGroups/Devops-Test/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus/subnets/subnet-appgw-devops-eastus"

# Import Container Registry (adjust name as needed)
terraform import azurerm_container_registry.main "/subscriptions/d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf/resourceGroups/Devops-Test/providers/Microsoft.ContainerRegistry/registries/acrzabbixdevopseastus30devopseastus"

# Import AKS cluster (if it exists)
az aks list --resource-group Devops-Test --output table
# terraform import azurerm_kubernetes_cluster.main "/subscriptions/d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf/resourceGroups/Devops-Test/providers/Microsoft.ContainerService/managedClusters/YOUR_AKS_NAME"
```

## Alternative: Clean Slate Deployment

If you prefer to start fresh (this will delete existing resources):

```powershell
# Delete the entire resource group (DESTRUCTIVE!)
az group delete --name Devops-Test --yes --no-wait

# Wait for deletion to complete
az group show --name Devops-Test --query "properties.provisioningState" --output tsv
# Should return "NotFound" when deletion is complete

# Create resource group again
az group create --name Devops-Test --location eastus

# Run Terraform deployment
terraform apply
```

## Alternative: Use Different Environment

To avoid conflicts, you can use a different environment name:

```powershell
# Edit terraform.tfvars to use a different environment name
# environment_name = "zabbix-devops-eastus-002"  # Change the suffix

# This will create resources with different names
terraform apply
```

## Verification

After importing or deploying:

```powershell
# Check Terraform state
terraform state list

# Verify resources match configuration
terraform plan

# Should show "No changes" if everything is properly imported
```

## Troubleshooting

If import fails:
1. Verify the resource ID is correct
2. Check that the resource actually exists in Azure
3. Ensure you have proper permissions
4. Make sure Terraform configuration matches the existing resource

If you get "resource not found" errors during import:
1. List resources: `az resource list --resource-group Devops-Test`
2. Get specific resource details: `az resource show --id "RESOURCE_ID"`
3. Verify the exact resource name and type
