# GitHub Actions Workflow Trigger Helper
# This script helps you trigger different deployment scenarios

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("full", "infrastructure-only", "application-only", "redeploy-clean")]
    [string]$DeploymentType,
    
    [ValidateSet("terraform", "arm", "both")]
    [string]$InfrastructureMethod = "terraform",
    
    [switch]$ResetDatabase = $false,
    [switch]$DebugMode = $false,
    [string]$EnvironmentSuffix = ""
)

Write-Host "🚀 GitHub Actions Workflow Trigger Helper" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Configuration Summary
Write-Host "`n📋 Deployment Configuration:" -ForegroundColor Yellow
Write-Host "   Deployment Type: $DeploymentType" -ForegroundColor White
Write-Host "   Infrastructure Method: $InfrastructureMethod" -ForegroundColor White
Write-Host "   Reset Database: $ResetDatabase" -ForegroundColor White
Write-Host "   Debug Mode: $DebugMode" -ForegroundColor White
Write-Host "   Environment Suffix: $(if($EnvironmentSuffix) { $EnvironmentSuffix } else { 'none' })" -ForegroundColor White

# Generate the GitHub CLI command
$ghCommand = "gh workflow run deploy-optimized.yml"
$ghCommand += " --field deployment_type=$DeploymentType"
$ghCommand += " --field infrastructure_method=$InfrastructureMethod"
$ghCommand += " --field reset_database=$($ResetDatabase.ToString().ToLower())"
$ghCommand += " --field debug_mode=$($DebugMode.ToString().ToLower())"

if ($EnvironmentSuffix) {
    $ghCommand += " --field environment_suffix=$EnvironmentSuffix"
}

Write-Host "`n🔧 GitHub CLI Command:" -ForegroundColor Green
Write-Host $ghCommand -ForegroundColor White

Write-Host "`n📝 Manual GitHub UI Steps:" -ForegroundColor Cyan
Write-Host "1. Go to: https://github.com/YOUR_USERNAME/YOUR_REPO/actions" -ForegroundColor White
Write-Host "2. Click 'Deploy AKS Zabbix Infrastructure (Terraform & ARM)'" -ForegroundColor White
Write-Host "3. Click 'Run workflow'" -ForegroundColor White
Write-Host "4. Select these options:" -ForegroundColor White
Write-Host "   - Deployment Type: $DeploymentType" -ForegroundColor Gray
Write-Host "   - Infrastructure Method: $InfrastructureMethod" -ForegroundColor Gray
Write-Host "   - Reset Database: $ResetDatabase" -ForegroundColor Gray
Write-Host "   - Debug Mode: $DebugMode" -ForegroundColor Gray
if ($EnvironmentSuffix) {
    Write-Host "   - Environment Suffix: $EnvironmentSuffix" -ForegroundColor Gray
}

# Deployment Type Explanations
Write-Host "`n💡 Deployment Type Explanations:" -ForegroundColor Yellow

switch ($DeploymentType) {
    "full" {
        Write-Host "   🏗️ FULL: Deploys both infrastructure and application" -ForegroundColor White
        Write-Host "   - Creates/updates AKS, networking, and all Azure resources" -ForegroundColor Gray  
        Write-Host "   - Deploys complete Zabbix application" -ForegroundColor Gray
        Write-Host "   - Use this for: New environments, major updates" -ForegroundColor Gray
    }
    "infrastructure-only" {
        Write-Host "   🏢 INFRASTRUCTURE-ONLY: Deploys only Azure infrastructure" -ForegroundColor White
        Write-Host "   - Creates/updates AKS, Application Gateway, networking" -ForegroundColor Gray
        Write-Host "   - Does NOT deploy Zabbix application" -ForegroundColor Gray  
        Write-Host "   - Use this for: Infrastructure changes, testing new cluster" -ForegroundColor Gray
    }
    "application-only" {
        Write-Host "   📱 APPLICATION-ONLY: Deploys only Zabbix application" -ForegroundColor White
        Write-Host "   - Uses existing AKS cluster" -ForegroundColor Gray
        Write-Host "   - Deploys/updates Zabbix components" -ForegroundColor Gray
        Write-Host "   - Use this for: Application updates, configuration changes" -ForegroundColor Gray
    }
    "redeploy-clean" {
        Write-Host "   🧹 REDEPLOY-CLEAN: Complete fresh deployment" -ForegroundColor White
        Write-Host "   - Removes all existing Zabbix resources" -ForegroundColor Gray
        Write-Host "   - Fresh database initialization" -ForegroundColor Gray
        Write-Host "   - ⚠️ WARNING: All data will be lost!" -ForegroundColor Red
    }
}

Write-Host "`n🎯 Recommended Usage Scenarios:" -ForegroundColor Cyan
Write-Host "   📈 First time setup: full" -ForegroundColor White
Write-Host "   🔄 App updates only: application-only" -ForegroundColor White
Write-Host "   🏗️ Infrastructure changes: infrastructure-only" -ForegroundColor White
Write-Host "   🆘 Fresh start/troubleshooting: redeploy-clean" -ForegroundColor White

# Execution options
Write-Host "`n⚡ Execution Options:" -ForegroundColor Yellow
Write-Host "1. Copy and run the GitHub CLI command above" -ForegroundColor White
Write-Host "2. Use the GitHub web interface with the manual steps" -ForegroundColor White
Write-Host "3. Test locally first with: .\test-zabbix-deployment.ps1" -ForegroundColor White

if (Get-Command gh -ErrorAction SilentlyContinue) {
    Write-Host "`n❓ Execute now? (y/N): " -ForegroundColor Green -NoNewline
    $response = Read-Host
    if ($response -eq 'y' -or $response -eq 'Y') {
        Write-Host "🚀 Executing GitHub workflow..." -ForegroundColor Green
        Invoke-Expression $ghCommand
        Write-Host "✅ Workflow triggered! Check GitHub Actions for progress." -ForegroundColor Green
    }
} else {
    Write-Host "`n💡 Install GitHub CLI for one-click execution:" -ForegroundColor Yellow
    Write-Host "   winget install --id GitHub.cli" -ForegroundColor White
}

Write-Host "`n🔗 Useful Links:" -ForegroundColor Cyan
Write-Host "   📊 GitHub Actions: https://github.com/YOUR_USERNAME/YOUR_REPO/actions" -ForegroundColor White
Write-Host "   🌐 Zabbix UI: http://dal2-devmon-mgt-devops.eastus.cloudapp.azure.com" -ForegroundColor White
Write-Host "   📋 Azure Portal: https://portal.azure.com/#@/resource/subscriptions/d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf/resourceGroups/rg-devops-pops-eastus/overview" -ForegroundColor White
