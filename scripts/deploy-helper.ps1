#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Helper script for managing Zabbix AKS deployments via GitHub Actions
    
.DESCRIPTION
    This script provides an easy interface to trigger GitHub Actions workflows
    with various deployment options. It supports both infrastructure and application
    deployments with different modes.

.PARAMETER DeploymentType
    Type of deployment: full, infrastructure-only, application-only, redeploy-clean

.PARAMETER InfrastructureMethod  
    Infrastructure deployment method: terraform, arm, both

.PARAMETER TerraformMode
    Terraform execution mode: plan-only, plan-and-apply, apply-existing-plan

.PARAMETER ResetDatabase
    Whether to reset the Zabbix database (WARNING: destroys data)

.PARAMETER DebugMode
    Enable debug logging

.PARAMETER EnvironmentSuffix
    Optional environment suffix for resource naming

.PARAMETER GitHubToken
    GitHub personal access token (can also be set via GITHUB_TOKEN env var)

.PARAMETER Repository
    GitHub repository in format owner/repo (default: auto-detect from git remote)

.EXAMPLE
    # Plan only - review infrastructure changes
    .\scripts\deploy-helper.ps1 -DeploymentType infrastructure-only -TerraformMode plan-only

.EXAMPLE  
    # Apply existing plan after review
    .\scripts\deploy-helper.ps1 -DeploymentType infrastructure-only -TerraformMode apply-existing-plan

.EXAMPLE
    # Full deployment with automatic apply
    .\scripts\deploy-helper.ps1 -DeploymentType full -TerraformMode plan-and-apply

.EXAMPLE
    # Application only deployment with database reset
    .\scripts\deploy-helper.ps1 -DeploymentType application-only -ResetDatabase

.EXAMPLE
    # Clean redeploy everything
    .\scripts\deploy-helper.ps1 -DeploymentType redeploy-clean -ResetDatabase
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('full', 'infrastructure-only', 'application-only', 'redeploy-clean')]
    [string]$DeploymentType = 'application-only',
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('terraform', 'arm', 'both')]
    [string]$InfrastructureMethod = 'terraform',
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('plan-only', 'plan-and-apply', 'apply-existing-plan')]
    [string]$TerraformMode = 'plan-and-apply',
    
    [Parameter(Mandatory = $false)]
    [switch]$ResetDatabase,
    
    [Parameter(Mandatory = $false)]
    [switch]$DebugMode,
    
    [Parameter(Mandatory = $false)]
    [string]$EnvironmentSuffix = '',
    
    [Parameter(Mandatory = $false)]
    [string]$GitHubToken = $env:GITHUB_TOKEN,
    
    [Parameter(Mandatory = $false)]
    [string]$Repository = ''
)

# Function to get repository info
function Get-RepositoryInfo {
    if ($Repository) {
        return $Repository
    }
    
    try {
        $remoteUrl = git remote get-url origin 2>$null
        if ($remoteUrl -match 'github\.com[:/]([^/]+/[^/]+?)(?:\.git)?/?$') {
            return $matches[1]
        }
    }
    catch {
        Write-Warning "Could not auto-detect repository. Please specify -Repository parameter."
    }
    
    return $null
}

# Function to trigger GitHub Actions workflow
function Invoke-GitHubWorkflow {
    param(
        [string]$Token,
        [string]$Repo,
        [hashtable]$Inputs
    )
    
    $headers = @{
        'Authorization' = "token $Token"
        'Accept' = 'application/vnd.github.v3+json'
        'User-Agent' = 'PowerShell-Zabbix-Deploy-Helper'
    }
    
    $body = @{
        ref = 'main'
        inputs = $Inputs
    } | ConvertTo-Json
    
    $uri = "https://api.github.com/repos/$Repo/actions/workflows/deploy.yml/dispatches"
    
    try {
        Write-Host "🚀 Triggering GitHub Actions workflow..." -ForegroundColor Cyan
        Write-Host "Repository: $Repo" -ForegroundColor Yellow
        Write-Host "Workflow: deploy.yml" -ForegroundColor Yellow
        
        $response = Invoke-RestMethod -Uri $uri -Method POST -Body $body -Headers $headers
        Write-Host "✅ Workflow triggered successfully!" -ForegroundColor Green
        
        # Get workflow run URL
        $workflowUrl = "https://github.com/$Repo/actions/workflows/deploy.yml"
        Write-Host "🔗 View workflow: $workflowUrl" -ForegroundColor Blue
        
        return $true
    }
    catch {
        Write-Error "❌ Failed to trigger workflow: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            $errorBody = $_.Exception.Response.Content.ReadAsStringAsync().Result
            Write-Error "Response: $errorBody"
        }
        return $false
    }
}

# Main execution
Write-Host "=== Zabbix AKS Deployment Helper ===" -ForegroundColor Magenta
Write-Host ""

# Validate GitHub token
if (-not $GitHubToken) {
    Write-Error "❌ GitHub token not provided. Set GITHUB_TOKEN environment variable or use -GitHubToken parameter."
    Write-Host "Create a token at: https://github.com/settings/tokens" -ForegroundColor Yellow
    exit 1
}

# Get repository info
$repoInfo = Get-RepositoryInfo
if (-not $repoInfo) {
    Write-Error "❌ Could not determine repository. Please specify -Repository parameter in format 'owner/repo'."
    exit 1
}

# Display configuration
Write-Host "=== Deployment Configuration ===" -ForegroundColor Cyan
Write-Host "Repository: $repoInfo" -ForegroundColor White
Write-Host "Deployment Type: $DeploymentType" -ForegroundColor White
Write-Host "Infrastructure Method: $InfrastructureMethod" -ForegroundColor White
Write-Host "Terraform Mode: $TerraformMode" -ForegroundColor White
Write-Host "Reset Database: $($ResetDatabase.IsPresent)" -ForegroundColor White
Write-Host "Debug Mode: $($DebugMode.IsPresent)" -ForegroundColor White
Write-Host "Environment Suffix: $($EnvironmentSuffix -or 'none')" -ForegroundColor White
Write-Host ""

# Prepare workflow inputs
$workflowInputs = @{
    deployment_type = $DeploymentType
    infrastructure_method = $InfrastructureMethod
    terraform_mode = $TerraformMode
    reset_database = $ResetDatabase.IsPresent.ToString().ToLower()
    debug_mode = $DebugMode.IsPresent.ToString().ToLower()
    force_powershell = 'false'
}

if ($EnvironmentSuffix) {
    $workflowInputs.environment_suffix = $EnvironmentSuffix
}

# Special warnings for destructive operations
if ($ResetDatabase) {
    Write-Warning "⚠️  DATABASE RESET ENABLED - This will destroy all Zabbix data!"
    Write-Host "Press Ctrl+C to cancel, or any key to continue..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host ""
}

if ($TerraformMode -eq 'plan-only') {
    Write-Host "📋 PLAN-ONLY MODE: Infrastructure changes will be planned but not applied." -ForegroundColor Yellow
    Write-Host "Review the plan in GitHub Actions, then run with -TerraformMode apply-existing-plan to apply." -ForegroundColor Yellow
    Write-Host ""
}

# Trigger the workflow
$success = Invoke-GitHubWorkflow -Token $GitHubToken -Repo $repoInfo -Inputs $workflowInputs

if ($success) {
    Write-Host ""
    Write-Host "=== Next Steps ===" -ForegroundColor Green
    
    switch ($TerraformMode) {
        'plan-only' {
            Write-Host "1. Review the Terraform plan in GitHub Actions" -ForegroundColor White
            Write-Host "2. Download the plan artifacts if needed" -ForegroundColor White
            Write-Host "3. Run again with -TerraformMode apply-existing-plan to apply" -ForegroundColor White
        }
        'apply-existing-plan' {
            Write-Host "1. Monitor the deployment in GitHub Actions" -ForegroundColor White
            Write-Host "2. Verify AKS cluster and resources are created" -ForegroundColor White
        }
        'plan-and-apply' {
            Write-Host "1. Monitor the deployment in GitHub Actions" -ForegroundColor White
            Write-Host "2. Review the plan output in the logs" -ForegroundColor White
            Write-Host "3. Verify resources are deployed correctly" -ForegroundColor White
        }
    }
    
    if ($DeploymentType -in @('full', 'application-only')) {
        Write-Host ""
        Write-Host "=== Post-Deployment Tasks ===" -ForegroundColor Cyan
        Write-Host "1. Configure DNS for dal2-devmon-mgt.forescout.com" -ForegroundColor White
        Write-Host "2. Change default Zabbix password (Admin/zabbix)" -ForegroundColor White
        Write-Host "3. Configure SSL certificate" -ForegroundColor White
        Write-Host "4. Set up monitoring templates" -ForegroundColor White
    }
} else {
    exit 1
}
