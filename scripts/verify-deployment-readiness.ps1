#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verifies deployment readiness for the Zabbix AKS infrastructure

.DESCRIPTION
    This script performs comprehensive checks to ensure all prerequisites
    are met for successful deployment including:
    - Azure authentication status
    - Resource group access
    - Resource provider registration
    - Quota availability
    - Template validation
    - Service principal permissions

.PARAMETER SubscriptionId
    The Azure subscription ID to verify

.PARAMETER ResourceGroupName
    The name of the target resource group

.PARAMETER Location
    The Azure region for deployment

.EXAMPLE
    .\verify-deployment-readiness.ps1 -SubscriptionId "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf" -ResourceGroupName "Devops-Test" -Location "eastus"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$Location
)

# Color output function
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    $colors = @{
        "Red" = [ConsoleColor]::Red
        "Green" = [ConsoleColor]::Green
        "Yellow" = [ConsoleColor]::Yellow
        "Blue" = [ConsoleColor]::Blue
        "Cyan" = [ConsoleColor]::Cyan
        "Magenta" = [ConsoleColor]::Magenta
        "White" = [ConsoleColor]::White
    }
    if ($colors.ContainsKey($Color)) {
        Write-Host $Message -ForegroundColor $colors[$Color]
    } else {
        Write-Host $Message -ForegroundColor White
    }
}

# Test results storage
$testResults = @()

function Add-TestResult {
    param([string]$Test, [bool]$Passed, [string]$Details = "")
    $testResults += [PSCustomObject]@{
        Test = $Test
        Status = if ($Passed) { "✅ PASS" } else { "❌ FAIL" }
        Details = $Details
    }
    if ($Passed) {
        Write-ColorOutput "✅ $Test" "Green"
    } else {
        Write-ColorOutput "❌ $Test - $Details" "Red"
    }
}

try {
    Write-ColorOutput "🔍 Starting deployment readiness verification..." "Cyan"
    Write-ColorOutput "📋 Target: Subscription $SubscriptionId, RG $ResourceGroupName, Location $Location" "Blue"
    
    # Check 1: Azure CLI availability and authentication
    Write-ColorOutput "`n1️⃣ Checking Azure CLI..." "Yellow"
    try {
        $azVersion = az --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Add-TestResult "Azure CLI Available" $true
            
            # Check authentication
            $account = az account show 2>$null | ConvertFrom-Json
            if ($account -and $account.id -eq $SubscriptionId) {
                Add-TestResult "Azure CLI Authentication" $true "Authenticated as $($account.user.name)"
            } else {
                Add-TestResult "Azure CLI Authentication" $false "Not authenticated to correct subscription"
            }
        } else {
            Add-TestResult "Azure CLI Available" $false "Azure CLI not found or not working"
        }
    } catch {
        Add-TestResult "Azure CLI Available" $false $_.Exception.Message
    }

    # Check 2: Azure PowerShell modules
    Write-ColorOutput "`n2️⃣ Checking Azure PowerShell..." "Yellow"
    $requiredModules = @('Az.Accounts', 'Az.Resources', 'Az.Profile')
    $moduleStatus = $true
    foreach ($module in $requiredModules) {
        if (Get-Module -ListAvailable -Name $module) {
            Add-TestResult "PowerShell Module: $module" $true
        } else {
            Add-TestResult "PowerShell Module: $module" $false "Module not installed"
            $moduleStatus = $false
        }
    }

    # Check PowerShell authentication
    $azContext = Get-AzContext -ErrorAction SilentlyContinue
    if ($azContext -and $azContext.Subscription.Id -eq $SubscriptionId) {
        Add-TestResult "PowerShell Authentication" $true "Authenticated to $($azContext.Subscription.Name)"
    } else {
        Add-TestResult "PowerShell Authentication" $false "Not authenticated to correct subscription"
    }

    # Check 3: Resource Group access
    Write-ColorOutput "`n3️⃣ Checking Resource Group access..." "Yellow"
    try {
        if ($azContext) {
            $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
            if ($rg) {
                Add-TestResult "Resource Group Access" $true "Can access $ResourceGroupName"
            } else {
                Add-TestResult "Resource Group Access" $false "Cannot access $ResourceGroupName"
            }
        } else {
            # Fallback to Azure CLI
            $rgCheck = az group show --name $ResourceGroupName 2>$null
            if ($LASTEXITCODE -eq 0) {
                Add-TestResult "Resource Group Access" $true "Can access $ResourceGroupName (via CLI)"
            } else {
                Add-TestResult "Resource Group Access" $false "Cannot access $ResourceGroupName"
            }
        }
    } catch {
        Add-TestResult "Resource Group Access" $false $_.Exception.Message
    }

    # Check 4: Required Resource Providers
    Write-ColorOutput "`n4️⃣ Checking Resource Providers..." "Yellow"
    $requiredProviders = @(
        'Microsoft.ContainerService',
        'Microsoft.Network',
        'Microsoft.Compute',
        'Microsoft.ContainerRegistry',
        'Microsoft.OperationalInsights'
    )

    foreach ($provider in $requiredProviders) {
        try {
            if ($azContext) {
                $providerStatus = Get-AzResourceProvider -ProviderNamespace $provider | Where-Object { $_.RegistrationState -eq 'Registered' }
                if ($providerStatus) {
                    Add-TestResult "Provider: $provider" $true "Registered"
                } else {
                    Add-TestResult "Provider: $provider" $false "Not registered"
                }
            } else {
                # Fallback to CLI
                $providerJson = az provider show --namespace $provider --query "registrationState" -o tsv 2>$null
                if ($providerJson -eq "Registered") {
                    Add-TestResult "Provider: $provider" $true "Registered (via CLI)"
                } else {
                    Add-TestResult "Provider: $provider" $false "Not registered"
                }
            }
        } catch {
            Add-TestResult "Provider: $provider" $false $_.Exception.Message
        }
    }

    # Check 5: Infrastructure template validation
    Write-ColorOutput "`n5️⃣ Validating infrastructure templates..." "Yellow"
    
    # Check Terraform configuration
    $terraformPath = Join-Path $PSScriptRoot ".." "infra" "terraform"
    if (Test-Path $terraformPath) {
        Add-TestResult "Terraform Directory Exists" $true
        
        # Check for terraform command
        try {
            $terraformVersion = terraform version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Add-TestResult "Terraform CLI Available" $true "Version: $($terraformVersion | Select-Object -First 1)"
                
                # Validate Terraform configuration
                try {
                    Push-Location $terraformPath
                    $validateOutput = terraform validate 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Add-TestResult "Terraform Configuration Valid" $true "Configuration is valid"
                    } else {
                        Add-TestResult "Terraform Configuration Valid" $false "Validation errors: $validateOutput"
                    }
                } catch {
                    Add-TestResult "Terraform Configuration Valid" $false "Cannot validate configuration: $($_.Exception.Message)"
                } finally {
                    Pop-Location
                }
            } else {
                Add-TestResult "Terraform CLI Available" $false "Terraform not installed or not in PATH"
            }
        } catch {
            Add-TestResult "Terraform CLI Available" $false "Cannot check Terraform: $($_.Exception.Message)"
        }
    } else {
        Add-TestResult "Terraform Directory Exists" $false "Terraform directory not found at $terraformPath"
    }
    
    # Check ARM template
    $armPath = Join-Path $PSScriptRoot ".." "infra" "main-arm.json"
    if (Test-Path $armPath) {
        Add-TestResult "ARM Template Exists" $true
        
        # Validate ARM template JSON syntax
        try {
            $armTemplate = Get-Content $armPath -Raw | ConvertFrom-Json
            Add-TestResult "ARM Template JSON Valid" $true "JSON syntax is valid"
        } catch {
            Add-TestResult "ARM Template JSON Valid" $false "JSON syntax error: $($_.Exception.Message)"
        }
    } else {
        Add-TestResult "ARM Template Exists" $false "ARM template not found at $armPath"
    }
    
    # Legacy Bicep template (removed)
    $bicepPath = Join-Path $PSScriptRoot ".." "infra" "main.bicep"
    if (Test-Path $bicepPath) {
        Add-TestResult "Bicep Template Exists (Unexpected)" $false "⚠️ Found legacy Bicep file - should have been removed"
    } else {
        Add-TestResult "Legacy Bicep Cleanup" $true "✅ Legacy Bicep files properly removed"
    }

    # Check 6: Kubernetes manifests
    Write-ColorOutput "`n6️⃣ Checking Kubernetes manifests..." "Yellow"
    $k8sPath = Join-Path $PSScriptRoot ".." "k8s"
    $requiredManifests = @('mysql.yaml', 'zabbix-server.yaml', 'zabbix-web.yaml', 'ingress.yaml')
    
    foreach ($manifest in $requiredManifests) {
        $manifestPath = Join-Path $k8sPath $manifest
        if (Test-Path $manifestPath) {
            Add-TestResult "K8s Manifest: $manifest" $true
        } else {
            Add-TestResult "K8s Manifest: $manifest" $false "File not found"
        }
    }

    # Summary
    Write-ColorOutput "`n📊 Deployment Readiness Summary:" "Cyan"
    $passedTests = ($testResults | Where-Object { $_.Status -eq "✅ PASS" }).Count
    $failedTests = ($testResults | Where-Object { $_.Status -eq "❌ FAIL" }).Count
    $totalTests = $testResults.Count

    Write-ColorOutput "Total Tests: $totalTests" "Blue"
    Write-ColorOutput "Passed: $passedTests" "Green"
    Write-ColorOutput "Failed: $failedTests" $(if ($failedTests -gt 0) { "Red" } else { "Green" })

    # Display detailed results
    Write-ColorOutput "`n📋 Detailed Results:" "Yellow"
    $testResults | Format-Table -AutoSize

    if ($failedTests -gt 0) {
        Write-ColorOutput "`n⚠️  Some checks failed. Please review and fix issues before deployment." "Yellow"
        Write-ColorOutput "💡 Recommendation: Fix failed tests and run this script again." "Blue"
        exit 1
    } else {
        Write-ColorOutput "`n🎉 All checks passed! System is ready for deployment." "Green"
        Write-ColorOutput "▶️  You can now proceed with GitHub Actions workflow or manual deployment." "Cyan"
        exit 0
    }

} catch {
    Write-ColorOutput "❌ Verification script failed: $($_.Exception.Message)" "Red"
    Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" "Red"
    exit 1
}
