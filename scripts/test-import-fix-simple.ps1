#!/usr/bin/env pwsh
# Test the improved Terraform import logic

param(
    [string]$CommitMessage = "Improve Terraform resource import logic with comprehensive error handling"
)

Write-Host "Testing improved Terraform import logic..." -ForegroundColor Green

try {
    # Check if we're in a git repository
    if (!(Test-Path ".git")) {
        Write-Error "Not in a git repository. Please run this script from the repository root."
        exit 1
    }

    # Show current status
    Write-Host "Current Git Status:" -ForegroundColor Yellow
    git status --porcelain

    # Add all changes
    Write-Host "Adding all changes..." -ForegroundColor Yellow
    git add .

    # Show what's being committed
    Write-Host "Changes to be committed:" -ForegroundColor Yellow
    git diff --cached --name-only

    # Commit changes
    Write-Host "Committing changes..." -ForegroundColor Yellow
    git commit -m "$CommitMessage"

    # Push changes
    Write-Host "Pushing to remote repository..." -ForegroundColor Yellow
    git push

    Write-Host "Changes pushed successfully!" -ForegroundColor Green

    # Wait a moment for GitHub to register the push
    Start-Sleep -Seconds 3

    # Trigger the workflow with plan-and-apply mode to test the import
    Write-Host "Triggering GitHub Actions workflow to test import fixes..." -ForegroundColor Yellow
    
    # Get current branch
    $branch = git rev-parse --abbrev-ref HEAD
    Write-Host "Using branch: $branch" -ForegroundColor Cyan

    # Note: This requires GitHub CLI (gh) to be installed and authenticated
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Host "Triggering workflow via GitHub CLI..." -ForegroundColor Yellow
        gh workflow run deploy.yml --field deployment_type="infra-only" --field deployment_mode="plan-and-apply" --field resource_group_name="rg-devops-pops-eastus" --field aks_cluster_name="aks-devops-eastus"
        
        # Wait and show workflow runs
        Start-Sleep -Seconds 5
        Write-Host "Recent workflow runs:" -ForegroundColor Yellow
        gh run list --limit 5
        
        Write-Host "You can monitor the workflow at:" -ForegroundColor Green
        $repo = gh repo view --json nameWithOwner --jq '.nameWithOwner'
        Write-Host "   https://github.com/$repo/actions" -ForegroundColor Cyan
    } else {
        Write-Host "GitHub CLI (gh) not found. Please manually trigger the workflow:" -ForegroundColor Yellow
        Write-Host "   1. Go to your repository on GitHub" -ForegroundColor White
        Write-Host "   2. Click on Actions tab" -ForegroundColor White
        Write-Host "   3. Find Deploy Zabbix to AKS workflow" -ForegroundColor White
        Write-Host "   4. Click Run workflow with these settings:" -ForegroundColor White
        Write-Host "      - Deployment Type: infra-only" -ForegroundColor Cyan
        Write-Host "      - Deployment Mode: plan-and-apply" -ForegroundColor Cyan
        Write-Host "      - Resource Group: rg-devops-pops-eastus" -ForegroundColor Cyan
        Write-Host "      - AKS Cluster: aks-devops-eastus" -ForegroundColor Cyan
    }

    Write-Host "Test initiated! The workflow will now test the improved import logic." -ForegroundColor Green
    Write-Host "Key improvements made:" -ForegroundColor Yellow
    Write-Host "   • Enhanced resource existence checking before import" -ForegroundColor White
    Write-Host "   • Remove from state before re-import to avoid conflicts" -ForegroundColor White
    Write-Host "   • Better error handling and status reporting" -ForegroundColor White
    Write-Host "   • Comprehensive logging of import process" -ForegroundColor White
    Write-Host "   • Plan summary showing what resources will be created/modified" -ForegroundColor White

} catch {
    Write-Error "Error during test setup: $_"
    exit 1
}
