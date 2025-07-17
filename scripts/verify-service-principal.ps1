# Service Principal Permission Verification Script
# This script helps verify if your service principal has the correct permissions

param(
    [Parameter(Mandatory=$true)]
    [string]$ClientId,
    
    [Parameter(Mandatory=$true)]
    [SecureString]$ClientSecret,
    
    [Parameter(Mandatory=$true)]
    [string]$TenantId,
    
    [string]$SubscriptionId = "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"
)

Write-Host "🔍 Azure Service Principal Permission Verification" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Convert secure string to plain text
$ClientSecretText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ClientSecret))

try {
    Write-Host "🔐 Logging in with service principal..." -ForegroundColor Yellow
    
    # Login with service principal
    az login --service-principal `
        --username $ClientId `
        --password $ClientSecretText `
        --tenant $TenantId
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Service principal login successful!" -ForegroundColor Green
        
        # Set subscription
        Write-Host "🎯 Setting subscription..." -ForegroundColor Yellow
        az account set --subscription $SubscriptionId
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Subscription access confirmed!" -ForegroundColor Green
            
            # Check current account
            Write-Host "📋 Current account details:" -ForegroundColor Yellow
            az account show --output table
            
            # Check resource group access
            Write-Host "🏗️ Checking resource group access..." -ForegroundColor Yellow
            $resourceGroups = az group list --query "[].name" --output tsv
            
            if ($resourceGroups -match "Devops-Test") {
                Write-Host "✅ Access to 'Devops-Test' resource group confirmed!" -ForegroundColor Green
            } else {
                Write-Host "❌ No access to 'Devops-Test' resource group found." -ForegroundColor Red
                Write-Host "   Available resource groups:" -ForegroundColor Yellow
                $resourceGroups | ForEach-Object { Write-Host "   - $_" -ForegroundColor White }
            }
            
            # Check permissions on Devops-Test specifically
            Write-Host "🔑 Checking permissions on Devops-Test resource group..." -ForegroundColor Yellow
            $roleAssignments = az role assignment list --assignee $ClientId --resource-group "Devops-Test" --output table 2>$null
            
            if ($roleAssignments) {
                Write-Host "✅ Role assignments found:" -ForegroundColor Green
                Write-Host $roleAssignments -ForegroundColor White
            } else {
                Write-Host "❌ No role assignments found for Devops-Test resource group." -ForegroundColor Red
                Write-Host "   Please assign Contributor role to the service principal." -ForegroundColor Yellow
            }
            
        } else {
            Write-Host "❌ Failed to set subscription. Check subscription ID." -ForegroundColor Red
        }
        
    } else {
        Write-Host "❌ Service principal login failed!" -ForegroundColor Red
        Write-Host "   Check your Client ID, Client Secret, and Tenant ID." -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Error occurred: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    # Logout to clean up
    Write-Host "🚪 Logging out..." -ForegroundColor Yellow
    az logout
}

Write-Host ""
Write-Host "📋 Summary:" -ForegroundColor Cyan
Write-Host "- If all checks passed, your GitHub Actions should work" -ForegroundColor White
Write-Host "- If role assignment failed, contact your Azure administrator" -ForegroundColor White
Write-Host "- Make sure to use the exact same credentials in GitHub secrets" -ForegroundColor White
