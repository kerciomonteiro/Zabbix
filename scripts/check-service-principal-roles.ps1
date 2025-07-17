# Quick Service Principal Role Check
# This script helps you check if the service principal has proper role assignments

Write-Host "🔍 Service Principal Role Assignment Checker" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

$servicePrincipalName = "github-actions-zabbix-deployment"
$subscriptionId = "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"
$resourceGroup = "Devops-Test"

Write-Host "Checking role assignments for: $servicePrincipalName" -ForegroundColor Yellow
Write-Host ""

# Check if logged in
try {
    $currentAccount = az account show --output json | ConvertFrom-Json
    Write-Host "✅ Logged in as: $($currentAccount.user.name)" -ForegroundColor Green
    Write-Host "✅ Current subscription: $($currentAccount.name)" -ForegroundColor Green
} catch {
    Write-Host "❌ Not logged into Azure CLI. Please run 'az login' first." -ForegroundColor Red
    exit 1
}

Write-Host ""

# Get service principal object ID
Write-Host "🔍 Finding service principal..." -ForegroundColor Yellow
$spInfo = az ad sp list --display-name $servicePrincipalName --output json | ConvertFrom-Json

if ($spInfo.Count -gt 0) {
    $spObjectId = $spInfo[0].id
    $spAppId = $spInfo[0].appId
    Write-Host "✅ Found service principal:" -ForegroundColor Green
    Write-Host "   Display Name: $($spInfo[0].displayName)" -ForegroundColor White
    Write-Host "   Object ID: $spObjectId" -ForegroundColor White
    Write-Host "   App ID: $spAppId" -ForegroundColor White
    Write-Host ""
    
    # Check subscription level role assignments
    Write-Host "🔍 Checking subscription-level role assignments..." -ForegroundColor Yellow
    $subRoles = az role assignment list --assignee $spObjectId --scope "/subscriptions/$subscriptionId" --output json | ConvertFrom-Json
    
    if ($subRoles.Count -gt 0) {
        Write-Host "✅ Subscription-level roles found:" -ForegroundColor Green
        foreach ($role in $subRoles) {
            Write-Host "   - $($role.roleDefinitionName) on $($role.scope)" -ForegroundColor White
        }
    } else {
        Write-Host "❌ No subscription-level roles found." -ForegroundColor Red
    }
    
    Write-Host ""
    
    # Check resource group level role assignments
    Write-Host "🔍 Checking resource group-level role assignments..." -ForegroundColor Yellow
    $rgRoles = az role assignment list --assignee $spObjectId --resource-group $resourceGroup --output json | ConvertFrom-Json
    
    if ($rgRoles.Count -gt 0) {
        Write-Host "✅ Resource group-level roles found:" -ForegroundColor Green
        foreach ($role in $rgRoles) {
            Write-Host "   - $($role.roleDefinitionName) on $($role.scope)" -ForegroundColor White
        }
    } else {
        Write-Host "❌ No resource group-level roles found." -ForegroundColor Red
    }
    
    Write-Host ""
    
    # Recommendations
    Write-Host "📋 Recommendations:" -ForegroundColor Cyan
    if ($subRoles.Count -eq 0 -and $rgRoles.Count -eq 0) {
        Write-Host "❌ No role assignments found. You need to assign roles!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Option 1 - Assign at subscription level:" -ForegroundColor Yellow
        Write-Host "az role assignment create --assignee $spObjectId --role Contributor --scope /subscriptions/$subscriptionId" -ForegroundColor White
        Write-Host ""
        Write-Host "Option 2 - Assign at resource group level:" -ForegroundColor Yellow
        Write-Host "az role assignment create --assignee $spObjectId --role Contributor --resource-group $resourceGroup" -ForegroundColor White
        Write-Host ""
        Write-Host "Or use the Azure Portal as described in the documentation." -ForegroundColor Yellow
    } else {
        Write-Host "✅ Role assignments found. GitHub Actions should work now!" -ForegroundColor Green
    }
    
} else {
    Write-Host "❌ Service principal '$servicePrincipalName' not found." -ForegroundColor Red
    Write-Host "   Please create the service principal first." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🔗 For manual assignment, go to:" -ForegroundColor Cyan
Write-Host "   Azure Portal → Subscriptions → Access control (IAM) → Add role assignment" -ForegroundColor White
