# PowerShell script to fix terraform imports for new resource group
$subscriptionId = "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"
$newResourceGroup = "rg-devops-pops-eastus"

# Resources to re-import
$resources = @(
    @{
        TerraformResource = "azurerm_log_analytics_workspace.main[0]"
        AzureResourceId = "/subscriptions/$subscriptionId/resourceGroups/$newResourceGroup/providers/Microsoft.OperationalInsights/workspaces/law-devops-eastus"
    },
    @{
        TerraformResource = "azurerm_container_registry.main"
        AzureResourceId = "/subscriptions/$subscriptionId/resourceGroups/$newResourceGroup/providers/Microsoft.ContainerRegistry/registries/acrdevopseastus"
    },
    @{
        TerraformResource = "azurerm_network_security_group.aks"
        AzureResourceId = "/subscriptions/$subscriptionId/resourceGroups/$newResourceGroup/providers/Microsoft.Network/networkSecurityGroups/nsg-aks-devops-eastus"
    },
    @{
        TerraformResource = "azurerm_network_security_group.appgw" 
        AzureResourceId = "/subscriptions/$subscriptionId/resourceGroups/$newResourceGroup/providers/Microsoft.Network/networkSecurityGroups/nsg-appgw-devops-eastus"
    },
    @{
        TerraformResource = "azurerm_virtual_network.main"
        AzureResourceId = "/subscriptions/$subscriptionId/resourceGroups/$newResourceGroup/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus"
    },
    @{
        TerraformResource = "azurerm_public_ip.appgw"
        AzureResourceId = "/subscriptions/$subscriptionId/resourceGroups/$newResourceGroup/providers/Microsoft.Network/publicIPAddresses/pip-appgw-devops-eastus"
    }
)

Write-Host "Fixing Terraform imports for resource group: $newResourceGroup" -ForegroundColor Cyan

Set-Location "infra\terraform"

foreach ($resource in $resources) {
    Write-Host "Processing: $($resource.TerraformResource)" -ForegroundColor Yellow
    
    # Remove from state
    terraform state rm $resource.TerraformResource
    
    # Re-import
    terraform import $resource.TerraformResource $resource.AzureResourceId
    
    Write-Host "Completed: $($resource.TerraformResource)" -ForegroundColor Green
}

Write-Host "All imports completed!" -ForegroundColor Green
