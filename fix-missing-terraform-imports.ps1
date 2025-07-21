# Terraform Missing Resources Import Script
# This script imports the specific resources that are currently failing in deployment

param(
    [string]$SubscriptionId = "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf",
    [string]$ResourceGroup = "rg-devops-pops-eastus",
    [string]$TerraformPath = "infra/terraform"
)

Write-Host "Starting Terraform resource import..." -ForegroundColor Green
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "   Subscription: $SubscriptionId"
Write-Host "   Resource Group: $ResourceGroup"
Write-Host "   Terraform Path: $TerraformPath"
Write-Host ""

# Change to Terraform directory
$originalPath = Get-Location
try {
    Set-Location $TerraformPath
    
    # Verify terraform is available
    if (-not (Get-Command "terraform" -ErrorAction SilentlyContinue)) {
        Write-Error "Terraform is not available in PATH"
        exit 1
    }
    
    # Initialize Terraform if needed
    Write-Host "Initializing Terraform..." -ForegroundColor Blue
    terraform init -input=false
    
    $successCount = 0
    $totalCount = 7
    
    # Function to safely import resources
    function Import-TerraformResource {
        param(
            [string]$TerraformResource,
            [string]$AzureResourceId,
            [string]$DisplayName
        )
        
        Write-Host "Processing $DisplayName..." -ForegroundColor Cyan
        Write-Host "   Terraform resource: $TerraformResource"
        Write-Host "   Azure resource ID: $AzureResourceId"
        
        try {
            # Check if already in state
            $null = terraform state show $TerraformResource 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   Resource already in Terraform state" -ForegroundColor Green
                return $true
            }
            
            # Import the resource
            Write-Host "   Importing resource..." -ForegroundColor Yellow
            terraform import $TerraformResource $AzureResourceId 2>&1 | Out-Host
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   Successfully imported $DisplayName" -ForegroundColor Green
                return $true
            } else {
                Write-Host "   Failed to import $DisplayName" -ForegroundColor Red
                return $false
            }
        }
        catch {
            Write-Host "   Exception importing $DisplayName`: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    
    Write-Host "=== IMPORTING MISSING RESOURCES ===" -ForegroundColor Magenta
    Write-Host ""
    
    # 1. Container Insights Solution
    if (Import-TerraformResource -TerraformResource "azurerm_log_analytics_solution.container_insights[0]" `
        -AzureResourceId "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationsManagement/solutions/ContainerInsights(law-devops-eastus)" `
        -DisplayName "Container Insights Solution") {
        $successCount++
    }
    
    # 2. Application Insights
    if (Import-TerraformResource -TerraformResource "azurerm_application_insights.main[0]" `
        -AzureResourceId "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/components/ai-devops-eastus" `
        -DisplayName "Application Insights") {
        $successCount++
    }
    
    # 3. AKS Subnet
    if (Import-TerraformResource -TerraformResource "azurerm_subnet.aks" `
        -AzureResourceId "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus/subnets/subnet-aks-devops-eastus" `
        -DisplayName "AKS Subnet") {
        $successCount++
    }
    
    # 4. App Gateway Subnet
    if (Import-TerraformResource -TerraformResource "azurerm_subnet.appgw" `
        -AzureResourceId "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus/subnets/subnet-appgw-devops-eastus" `
        -DisplayName "Application Gateway Subnet") {
        $successCount++
    }
    
    # 5. Application Gateway
    if (Import-TerraformResource -TerraformResource "azurerm_application_gateway.main" `
        -AzureResourceId "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Network/applicationGateways/appgw-devops-eastus" `
        -DisplayName "Application Gateway") {
        $successCount++
    }
    
    # 6. AKS Subnet NSG Association
    if (Import-TerraformResource -TerraformResource "azurerm_subnet_network_security_group_association.aks" `
        -AzureResourceId "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus/subnets/subnet-aks-devops-eastus" `
        -DisplayName "AKS Subnet NSG Association") {
        $successCount++
    }
    
    # 7. App Gateway Subnet NSG Association
    if (Import-TerraformResource -TerraformResource "azurerm_subnet_network_security_group_association.appgw" `
        -AzureResourceId "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus/subnets/subnet-appgw-devops-eastus" `
        -DisplayName "App Gateway Subnet NSG Association") {
        $successCount++
    }
    
    Write-Host ""
    Write-Host "=== IMPORT SUMMARY ===" -ForegroundColor Magenta
    Write-Host "Import Results: $successCount/$totalCount resources successfully imported" -ForegroundColor $(if ($successCount -eq $totalCount) { "Green" } else { "Yellow" })
    
    if ($successCount -eq $totalCount) {
        Write-Host "All resources successfully imported!" -ForegroundColor Green
        Write-Host ""
        Write-Host "You can now run 'terraform plan' or 'terraform apply' to continue deployment" -ForegroundColor Green
    } elseif ($successCount -gt 0) {
        Write-Host "Some resources imported successfully, but some failed" -ForegroundColor Yellow
        Write-Host "   You may need to manually check the failed resources" -ForegroundColor Yellow
    } else {
        Write-Host "No resources were successfully imported" -ForegroundColor Red
        Write-Host "   Check Azure CLI authentication and resource existence" -ForegroundColor Red
    }
    
    # Show current Terraform state for verification
    Write-Host ""
    Write-Host "Current Terraform state (key resources):" -ForegroundColor Blue
    $stateResources = @(
        "azurerm_log_analytics_solution.container_insights[0]",
        "azurerm_application_insights.main[0]",
        "azurerm_subnet.aks",
        "azurerm_subnet.appgw",
        "azurerm_application_gateway.main",
        "azurerm_subnet_network_security_group_association.aks",
        "azurerm_subnet_network_security_group_association.appgw"
    )
    
    foreach ($resource in $stateResources) {
        $null = terraform state show $resource 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   [OK] $resource" -ForegroundColor Green
        } else {
            Write-Host "   [MISSING] $resource (not in state)" -ForegroundColor Red
        }
    }
    
} catch {
    Write-Host "Script execution failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Set-Location $originalPath
}

Write-Host ""
Write-Host "Import script completed" -ForegroundColor Green
