# GitHub Actions Deployment Verification Script (PowerShell)
# This script verifies that your repository is ready for GitHub Actions deployment

Write-Host "Verifying GitHub Actions Deployment Setup..." -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# Check if we're in a Git repository
try {
    $null = git rev-parse --git-dir 2>$null
    Write-Host "✅ Git repository detected" -ForegroundColor Green
} catch {
    Write-Host "❌ Not in a Git repository" -ForegroundColor Red
    exit 1
}

# Check if workflow file exists
$WorkflowFile = ".github/workflows/deploy.yml"
if (-not (Test-Path $WorkflowFile)) {
    Write-Host "❌ GitHub Actions workflow file not found: $WorkflowFile" -ForegroundColor Red
    exit 1
}

Write-Host "✅ GitHub Actions workflow file found" -ForegroundColor Green

# Check workflow configuration
Write-Host ""
Write-Host "Workflow Configuration:" -ForegroundColor Yellow
Write-Host "------------------------" -ForegroundColor Yellow

# Extract key configuration values
$WorkflowContent = Get-Content $WorkflowFile
$ResourceGroup = ($WorkflowContent | Select-String "AZURE_RESOURCE_GROUP:").ToString().Split("'")[1]
$Location = ($WorkflowContent | Select-String "AZURE_LOCATION:").ToString().Split("'")[1]
$SubscriptionId = ($WorkflowContent | Select-String "AZURE_SUBSCRIPTION_ID:").ToString().Split("'")[1]

Write-Host "Resource Group: $ResourceGroup"
Write-Host "Location: $Location"
Write-Host "Subscription ID: $SubscriptionId"

# Check if infrastructure files exist
Write-Host ""
Write-Host "Infrastructure Files:" -ForegroundColor Yellow
Write-Host "------------------------" -ForegroundColor Yellow

if (Test-Path "infra/terraform") {
    Write-Host "✅ Terraform infrastructure found" -ForegroundColor Green
    $TerraformFiles = (Get-ChildItem -Recurse -Path "infra/terraform" -Filter "*.tf").Count
    Write-Host "   Terraform files: $TerraformFiles"
} else {
    Write-Host "⚠️ Terraform infrastructure not found" -ForegroundColor Yellow
}

if (Test-Path "infra/main-arm.json") {
    Write-Host "✅ ARM template found" -ForegroundColor Green
} else {
    Write-Host "⚠️ ARM template not found" -ForegroundColor Yellow
}

# Check Kubernetes manifests
Write-Host ""
Write-Host "Kubernetes Manifests:" -ForegroundColor Yellow
Write-Host "------------------------" -ForegroundColor Yellow

$K8sFound = $false

if (Test-Path "k8s") {
    Write-Host "✅ Kubernetes manifests found in k8s/" -ForegroundColor Green
    $K8sFiles = (Get-ChildItem -Recurse -Path "k8s" -Include "*.yaml", "*.yml").Count
    Write-Host "   k8s/ files: $K8sFiles"
    $K8sFound = $true
}

if (Test-Path "applications/zabbix/k8s") {
    Write-Host "✅ Kubernetes manifests found in applications/zabbix/k8s/" -ForegroundColor Green
    $ZabbixK8sFiles = (Get-ChildItem -Recurse -Path "applications/zabbix/k8s" -Include "*.yaml", "*.yml").Count
    Write-Host "   applications/zabbix/k8s/ files: $ZabbixK8sFiles"
    $K8sFound = $true
}

if (-not $K8sFound) {
    Write-Host "❌ Kubernetes manifests not found" -ForegroundColor Red
    Write-Host "   Expected: k8s/ or applications/zabbix/k8s/ directory"
}

# Check Git status
Write-Host ""
Write-Host "Git Status:" -ForegroundColor Yellow
Write-Host "-------------" -ForegroundColor Yellow

$GitStatus = git status --porcelain
if ($GitStatus) {
    Write-Host "⚠️ You have uncommitted changes:" -ForegroundColor Yellow
    $GitStatus | Select-Object -First 10 | ForEach-Object { Write-Host "   $_" }
    Write-Host ""
    Write-Host "Commit and push changes before running GitHub Actions workflow" -ForegroundColor Cyan
} else {
    Write-Host "✅ Working tree is clean" -ForegroundColor Green
}

# Check if we're on main branch
$CurrentBranch = git rev-parse --abbrev-ref HEAD
Write-Host "Current branch: $CurrentBranch"

if ($CurrentBranch -eq "main" -or $CurrentBranch -eq "develop") {
    Write-Host "✅ On deployment branch" -ForegroundColor Green
} else {
    Write-Host "⚠️ Not on main/develop branch (workflow may not trigger automatically)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Required GitHub Secrets:" -ForegroundColor Yellow
Write-Host "-------------------------" -ForegroundColor Yellow
Write-Host "⚠️ Please ensure you have configured AZURE_CREDENTIALS secret in GitHub" -ForegroundColor Yellow
Write-Host ""

Write-Host ""
Write-Host "Deployment Instructions:" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host "1. Ensure AZURE_CREDENTIALS secret is configured in GitHub"
Write-Host "2. Go to GitHub repository - Actions tab"
Write-Host "3. Select 'Deploy AKS Zabbix Infrastructure' workflow"
Write-Host "4. Click 'Run workflow'"
Write-Host "5. Choose deployment options:"
Write-Host "   - Type: 'full' for complete deployment"
Write-Host "   - Method: 'terraform' (recommended)"
Write-Host "   - Leave other options as default for first deployment"
Write-Host "6. Click 'Run workflow' button"
Write-Host ""
Write-Host "For detailed instructions, see: GITHUB-DEPLOYMENT-GUIDE.md" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Repository appears ready for GitHub Actions deployment!" -ForegroundColor Green
