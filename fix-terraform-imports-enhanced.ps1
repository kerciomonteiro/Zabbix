#!/usr/bin/env pwsh
# Enhanced Terraform Import Fix Script
# This script imports existing Azure resources into Terraform state to resolve import conflicts

param(
    [string]$SubscriptionId = "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf",
    [string]$ResourceGroup = "rg-devops-pops-eastus",
    [switch]$WhatIf,
    [switch]$Verbose
)

Write-Host "🚀 Enhanced Terraform Import Fix Script" -ForegroundColor Cyan
Write-Host "Subscription ID: $SubscriptionId" -ForegroundColor Gray
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Gray

if ($WhatIf) {
    Write-Host "🔍 WHAT-IF MODE: No actual imports will be performed" -ForegroundColor Yellow
}

# Define critical resources that commonly cause import conflicts
$criticalResources = @(
    @{
        TfResource = "azurerm_log_analytics_workspace.main[0]"
        AzureId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/law-devops-eastus"
        Name = "Log Analytics Workspace"
        Priority = 1
    },
    @{
        TfResource = "azurerm_container_registry.main"
        AzureId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ContainerRegistry/registries/acrdevopseastus"
        Name = "Container Registry" 
        Priority = 1
    },
    @{
        TfResource = "azurerm_network_security_group.aks"
        AzureId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Network/networkSecurityGroups/nsg-aks-devops-eastus"
        Name = "AKS Network Security Group"
        Priority = 2
    },
    @{
        TfResource = "azurerm_network_security_group.appgw"
        AzureId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Network/networkSecurityGroups/nsg-appgw-devops-eastus"
        Name = "App Gateway Network Security Group"
        Priority = 2
    },
    @{
        TfResource = "azurerm_virtual_network.main"
        AzureId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus"
        Name = "Virtual Network"
        Priority = 2
    },
    @{
        TfResource = "azurerm_public_ip.appgw"
        AzureId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Network/publicIPAddresses/pip-appgw-devops-eastus"
        Name = "Application Gateway Public IP"
        Priority = 3
    }
)

function Test-ResourceExists {
    param($AzureId)
    
    try {
        az resource show --ids $AzureId 2>$null | Out-Null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Test-TerraformState {
    param($TfResource)
    
    try {
        terraform state show $TfResource 2>$null | Out-Null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Import-Resource {
    param($Resource, $WhatIf)
    
    Write-Host ""
    Write-Host "📋 Processing: $($Resource.Name)" -ForegroundColor Cyan
    
    # Check if already in state
    if (Test-TerraformState -TfResource $Resource.TfResource) {
        Write-Host "  ✅ Already in Terraform state" -ForegroundColor Green
        return $true
    }
    
    # Check if resource exists in Azure
    if (-not (Test-ResourceExists -AzureId $Resource.AzureId)) {
        Write-Host "  ⚠️  Resource not found in Azure - skipping" -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "  🔍 Found in Azure, importing..." -ForegroundColor Blue
    
    if ($WhatIf) {
        Write-Host "  📋 Would run: terraform import $($Resource.TfResource) $($Resource.AzureId)" -ForegroundColor Yellow
        return $true
    }
    
    # Perform the import
    try {
        $importResult = terraform import $Resource.TfResource $Resource.AzureId 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ Successfully imported" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  ❌ Import failed: $importResult" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "  ❌ Import failed with exception: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main execution
try {
    # Check if we're in the right directory
    if (-not (Test-Path "infra/terraform" -PathType Container)) {
        Write-Host "❌ Error: Must run from Zabbix project root directory" -ForegroundColor Red
        Write-Host "   Looking for: infra/terraform/" -ForegroundColor Gray
        exit 1
    }
    
    # Navigate to terraform directory
    Push-Location "infra/terraform"
    
    # Initialize Terraform if needed
    if (-not (Test-Path ".terraform" -PathType Container)) {
        Write-Host "📦 Initializing Terraform..." -ForegroundColor Yellow
        terraform init
    }
    
    # Sort resources by priority and import them
    $sortedResources = $criticalResources | Sort-Object Priority
    $successCount = 0
    $totalCount = $sortedResources.Count
    
    Write-Host ""
    Write-Host "🎯 Importing $totalCount critical resources..." -ForegroundColor Cyan
    
    foreach ($resource in $sortedResources) {
        if (Import-Resource -Resource $resource -WhatIf:$WhatIf) {
            $successCount++
        }
    }
    
    # Summary
    Write-Host ""
    Write-Host "📊 Import Summary" -ForegroundColor Cyan
    Write-Host "  Total resources: $totalCount" -ForegroundColor Gray
    Write-Host "  Successfully imported: $successCount" -ForegroundColor Green
    Write-Host "  Failed: $($totalCount - $successCount)" -ForegroundColor $(if ($totalCount -eq $successCount) { "Green" } else { "Red" })
    
    if ($successCount -eq $totalCount) {
        Write-Host ""
        Write-Host "🎉 All critical resources imported successfully!" -ForegroundColor Green
        Write-Host "   You can now run 'terraform plan' or 'terraform apply'" -ForegroundColor Gray
    } else {
        Write-Host ""
        Write-Host "⚠️  Some imports failed - you may still encounter conflicts" -ForegroundColor Yellow
        Write-Host "   Try running the specific imports manually if needed" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "❌ Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "✅ Import process completed" -ForegroundColor Green
