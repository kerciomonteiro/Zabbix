#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Alternative infrastructure deployment script using Azure PowerShell
    
.DESCRIPTION
    This script provides a backup deployment method using Azure PowerShell
    when Azure CLI experiences issues like "content already consumed" errors.
    
.PARAMETER ResourceGroupName
    The name of the Azure resource group
    
.PARAMETER Location
    The Azure region for deployment
    
.PARAMETER EnvironmentName
    The environment name for the deployment
    
.PARAMETER SubscriptionId
    The Azure subscription ID
    
.EXAMPLE
    ./deploy-infrastructure-pwsh.ps1 -ResourceGroupName "Devops-Test" -Location "eastus" -EnvironmentName "zabbix-aks-123" -SubscriptionId "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$Location,
    
    [Parameter(Mandatory = $true)]
    [string]$EnvironmentName,
    
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    $colorMap = @{
        "Red" = [System.ConsoleColor]::Red
        "Green" = [System.ConsoleColor]::Green
        "Yellow" = [System.ConsoleColor]::Yellow
        "Blue" = [System.ConsoleColor]::Blue
        "Cyan" = [System.ConsoleColor]::Cyan
        "White" = [System.ConsoleColor]::White
    }
    
    Write-Host $Message -ForegroundColor $colorMap[$Color]
}

try {
    Write-ColorOutput "🚀 Starting Azure PowerShell infrastructure deployment..." "Cyan"
    
    # Check if Az module is installed
    if (-not (Get-Module -ListAvailable -Name Az.Resources)) {
        Write-ColorOutput "📦 Installing Azure PowerShell module..." "Yellow"
        Install-Module -Name Az -Force -AllowClobber -Scope CurrentUser
    }
    
    # Import required modules
    Write-ColorOutput "📋 Importing Azure modules..." "Blue"
    Import-Module Az.Accounts -Force
    Import-Module Az.Resources -Force
    Import-Module Az.Profile -Force
    
    # Set subscription context
    Write-ColorOutput "🔐 Setting subscription context..." "Blue"
    $context = Set-AzContext -SubscriptionId $SubscriptionId
    Write-ColorOutput "✅ Connected to subscription: $($context.Subscription.Name)" "Green"
    
    # Verify resource group access
    Write-ColorOutput "🔍 Verifying resource group access..." "Blue"
    $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $resourceGroup) {
        throw "Cannot access resource group '$ResourceGroupName'"
    }
    Write-ColorOutput "✅ Resource group access confirmed" "Green"
    
    # Generate deployment name
    $deploymentName = "zabbix-pwsh-deploy-$(Get-Date -Format 'yyyyMMddHHmmss')"
    Write-ColorOutput "📝 Using deployment name: $deploymentName" "Blue"
    
    # Construct template file path
    $templatePath = Join-Path $PSScriptRoot ".." "infra" "main.bicep"
    if (-not (Test-Path $templatePath)) {
        throw "Bicep template not found at: $templatePath"
    }
    
    Write-ColorOutput "📄 Using template: $templatePath" "Blue"
    
    # Prepare deployment parameters
    $deploymentParameters = @{
        environmentName = $EnvironmentName
        location = $Location
    }
    
    Write-ColorOutput "🔧 Deployment parameters:" "Blue"
    $deploymentParameters.GetEnumerator() | ForEach-Object {
        Write-ColorOutput "  $($_.Key): $($_.Value)" "White"
    }
    
    # Test deployment first
    Write-ColorOutput "🧪 Testing deployment..." "Yellow"
    $testResult = Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $templatePath -TemplateParameterObject $deploymentParameters
    
    if ($testResult) {
        Write-ColorOutput "❌ Deployment test failed:" "Red"
        $testResult | ForEach-Object {
            Write-ColorOutput "  Error: $($_.Message)" "Red"
        }
        throw "Deployment validation failed"
    }
    
    Write-ColorOutput "✅ Deployment test passed" "Green"
    
    # Deploy infrastructure
    Write-ColorOutput "🚀 Starting infrastructure deployment..." "Cyan"
    $deployment = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name $deploymentName -TemplateFile $templatePath -TemplateParameterObject $deploymentParameters -Verbose
    
    if ($deployment.ProvisioningState -ne "Succeeded") {
        throw "Deployment failed with state: $($deployment.ProvisioningState)"
    }
    
    Write-ColorOutput "✅ Infrastructure deployment completed successfully!" "Green"
    
    # Extract outputs
    Write-ColorOutput "📋 Extracting deployment outputs..." "Blue"
    $outputs = $deployment.Outputs
    
    if (-not $outputs -or -not $outputs.ContainsKey("AKS_CLUSTER_NAME")) {
        throw "Required outputs not found in deployment"
    }
    
    $aksClusterName = $outputs["AKS_CLUSTER_NAME"].Value
    $containerRegistryEndpoint = $outputs["CONTAINER_REGISTRY_ENDPOINT"].Value
    
    if (-not $aksClusterName) {
        throw "AKS cluster name is empty in deployment outputs"
    }
    
    # Display results
    Write-ColorOutput "" "White"
    Write-ColorOutput "=== Deployment Results ===" "Cyan"
    Write-ColorOutput "✅ Deployment Method: Azure PowerShell" "Green"
    Write-ColorOutput "📋 AKS Cluster Name: $aksClusterName" "White"
    Write-ColorOutput "📋 Resource Group: $ResourceGroupName" "White"
    Write-ColorOutput "📋 Container Registry: $containerRegistryEndpoint" "White"
    Write-ColorOutput "📋 Deployment Name: $deploymentName" "White"
    
    # Output results for GitHub Actions
    if ($env:GITHUB_OUTPUT) {
        Write-ColorOutput "📝 Setting GitHub Actions outputs..." "Blue"
        Add-Content -Path $env:GITHUB_OUTPUT -Value "AKS_CLUSTER_NAME=$aksClusterName"
        Add-Content -Path $env:GITHUB_OUTPUT -Value "AZURE_RESOURCE_GROUP=$ResourceGroupName"
        Add-Content -Path $env:GITHUB_OUTPUT -Value "CONTAINER_REGISTRY_ENDPOINT=$containerRegistryEndpoint"
        Add-Content -Path $env:GITHUB_OUTPUT -Value "DEPLOYMENT_METHOD=powershell"
        Add-Content -Path $env:GITHUB_OUTPUT -Value "DEPLOYMENT_SUCCESS=true"
    }
    
    # Return success
    exit 0
    
} catch {
    Write-ColorOutput "❌ Deployment failed: $($_.Exception.Message)" "Red"
    Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" "Red"
    
    if ($env:GITHUB_OUTPUT) {
        Add-Content -Path $env:GITHUB_OUTPUT -Value "DEPLOYMENT_SUCCESS=false"
    }
    
    exit 1
}
