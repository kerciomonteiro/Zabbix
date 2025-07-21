# Import Existing Azure Resources into Terraform State
# This script imports existing Azure resources to avoid "resource already exists" errors

param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "Devops-Test"
)

Write-Host "🔄 Starting Terraform import process..." -ForegroundColor Green

# Ensure we're in the correct directory
$terraformDir = "infra\terraform"
if (-not (Test-Path $terraformDir)) {
    Write-Host "❌ Terraform directory not found. Please run this script from the root of the repository." -ForegroundColor Red
    exit 1
}

Set-Location $terraformDir

# Check if terraform is initialized
if (-not (Test-Path ".terraform")) {
    Write-Host "🔄 Initializing Terraform..." -ForegroundColor Yellow
    terraform init
}

# Function to import resource with error handling
function Import-TerraformResource {
    param(
        [string]$ResourceAddress,
        [string]$ResourceId
    )
    
    Write-Host "Importing: $ResourceAddress" -ForegroundColor Cyan
    
    try {
        $result = terraform import $ResourceAddress $ResourceId 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Successfully imported: $ResourceAddress" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Import failed for: $ResourceAddress" -ForegroundColor Yellow
            Write-Host "Error: $result" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Exception importing: $ResourceAddress" -ForegroundColor Red
        Write-Host "Error: $_.Exception.Message" -ForegroundColor Red
    }
}

# Import resources that already exist
Write-Host "`n🔄 Importing existing resources..." -ForegroundColor Green

# User Assigned Identity
Import-TerraformResource `
    "azurerm_user_assigned_identity.aks" `
    "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-devops-eastus"

# Log Analytics Workspace
Import-TerraformResource `
    "azurerm_log_analytics_workspace.main[0]" `
    "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.OperationalInsights/workspaces/law-devops-eastus"

# Network Security Groups
Import-TerraformResource `
    "azurerm_network_security_group.aks" `
    "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/networkSecurityGroups/nsg-aks-devops-eastus"

Import-TerraformResource `
    "azurerm_network_security_group.appgw" `
    "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/networkSecurityGroups/nsg-appgw-devops-eastus"

# Virtual Network
Import-TerraformResource `
    "azurerm_virtual_network.main" `
    "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus"

# Public IP
Import-TerraformResource `
    "azurerm_public_ip.appgw" `
    "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/publicIPAddresses/pip-appgw-devops-eastus"

# Check if subnets exist and import them
Write-Host "`n🔄 Checking for subnets to import..." -ForegroundColor Green

$subnets = az network vnet subnet list --vnet-name vnet-devops-eastus --resource-group $ResourceGroupName --query "[].name" --output tsv 2>$null

if ($subnets) {
    foreach ($subnet in $subnets) {
        if ($subnet -like "*aks*") {
            Import-TerraformResource `
                "azurerm_subnet.aks" `
                "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus/subnets/$subnet"
        }
        if ($subnet -like "*appgw*") {
            Import-TerraformResource `
                "azurerm_subnet.appgw" `
                "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus/subnets/$subnet"
        }
    }
}

# Check if Container Registry exists and import it
Write-Host "`n🔄 Checking for Container Registry to import..." -ForegroundColor Green

$acrs = az acr list --resource-group $ResourceGroupName --query "[].name" --output tsv 2>$null

if ($acrs) {
    foreach ($acr in $acrs) {
        Import-TerraformResource `
            "azurerm_container_registry.main" `
            "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.ContainerRegistry/registries/$acr"
    }
}

# Check if AKS cluster exists and import it
Write-Host "`n🔄 Checking for AKS cluster to import..." -ForegroundColor Green

$aksClusters = az aks list --resource-group $ResourceGroupName --query "[].name" --output tsv 2>$null

if ($aksClusters) {
    foreach ($aksCluster in $aksClusters) {
        Write-Host "⚠️  Found AKS cluster: $aksCluster" -ForegroundColor Yellow
        Write-Host "Note: AKS cluster import is complex and may require manual intervention." -ForegroundColor Yellow
        # Uncomment the next line if you want to import the AKS cluster
        # Import-TerraformResource `
        #     "azurerm_kubernetes_cluster.main" `
        #     "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.ContainerService/managedClusters/$aksCluster"
    }
}

# Run terraform plan to see what still needs to be created
Write-Host "`n🔄 Running terraform plan to check current state..." -ForegroundColor Green

terraform plan

Write-Host "`n✅ Import process completed!" -ForegroundColor Green
Write-Host "Review the terraform plan output above to see what resources still need to be created." -ForegroundColor Yellow
Write-Host "If you see 'No changes' then all resources have been successfully imported." -ForegroundColor Green

# Return to original directory
Set-Location ..\..
