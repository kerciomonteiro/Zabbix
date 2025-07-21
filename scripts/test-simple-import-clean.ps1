#!/usr/bin/env pwsh

# Simple script to test the import logic locally

param(
    [string]$ResourceGroup = "rg-devops-pops-eastus",
    [string]$SubscriptionId = "7c4fc789-5508-473d-b924-de34b2ac4d6e"
)

Write-Host "Testing import logic for resource group: $ResourceGroup" -ForegroundColor Cyan

# Check if we're logged into Azure
try {
    $context = az account show --output json | ConvertFrom-Json
    Write-Host "Logged into Azure as: $($context.user.name)" -ForegroundColor Green
    Write-Host "Subscription: $($context.name) ($($context.id))" -ForegroundColor Green
} catch {
    Write-Host "Not logged into Azure CLI. Please run 'az login' first." -ForegroundColor Red
    exit 1
}

# List resources in the resource group
Write-Host "Listing resources in resource group..." -ForegroundColor Cyan
try {
    az resource list --resource-group $ResourceGroup --output table
} catch {
    Write-Host "Failed to list resources in resource group $ResourceGroup" -ForegroundColor Red
    exit 1
}

# Test specific resource checks that our import logic will use
$resources = @(
    @{ Name = "id-devops-eastus"; Type = "Managed Identity"; Command = "az identity show --resource-group '$ResourceGroup' --name 'id-devops-eastus'" },
    @{ Name = "law-devops-eastus"; Type = "Log Analytics"; Command = "az monitor log-analytics workspace show --resource-group '$ResourceGroup' --workspace-name 'law-devops-eastus'" },
    @{ Name = "acrdevopseastus"; Type = "Container Registry"; Command = "az acr show --resource-group '$ResourceGroup' --name 'acrdevopseastus'" },
    @{ Name = "vnet-devops-eastus"; Type = "Virtual Network"; Command = "az network vnet show --resource-group '$ResourceGroup' --name 'vnet-devops-eastus'" },
    @{ Name = "nsg-aks-devops-eastus"; Type = "AKS NSG"; Command = "az network nsg show --resource-group '$ResourceGroup' --name 'nsg-aks-devops-eastus'" },
    @{ Name = "nsg-appgw-devops-eastus"; Type = "App Gateway NSG"; Command = "az network nsg show --resource-group '$ResourceGroup' --name 'nsg-appgw-devops-eastus'" },
    @{ Name = "pip-appgw-devops-eastus"; Type = "Public IP"; Command = "az network public-ip show --resource-group '$ResourceGroup' --name 'pip-appgw-devops-eastus'" },
    @{ Name = "appgw-devops-eastus"; Type = "Application Gateway"; Command = "az network application-gateway show --resource-group '$ResourceGroup' --name 'appgw-devops-eastus'" },
    @{ Name = "aks-devops-eastus"; Type = "AKS Cluster"; Command = "az aks show --resource-group '$ResourceGroup' --name 'aks-devops-eastus'" }
)

Write-Host "Testing resource existence checks..." -ForegroundColor Cyan

foreach ($resource in $resources) {
    Write-Host "Checking $($resource.Type) ($($resource.Name))..." -ForegroundColor Yellow
    
    try {
        $result = Invoke-Expression "$($resource.Command) --output json 2>$null"
        if ($result) {
            Write-Host "  Found $($resource.Type)" -ForegroundColor Green
            
            # For key resources, show the resource ID that would be used for import
            $resourceObj = $result | ConvertFrom-Json
            if ($resourceObj.id) {
                Write-Host "     Resource ID: $($resourceObj.id)" -ForegroundColor Gray
            }
        } else {
            Write-Host "  $($resource.Type) not found" -ForegroundColor Red
        }
    } catch {
        Write-Host "  $($resource.Type) not found or access denied" -ForegroundColor Red
    }
}

Write-Host "Resource existence check completed!" -ForegroundColor Green
