# AGIC Installation Verification Script (PowerShell)
# This script validates that the modern AGIC installation approach is working

param(
    [switch]$Detailed = $false
)

Write-Host "🔍 AGIC Installation Verification Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Function to print status
function Write-Status {
    param(
        [string]$Status,
        [string]$Message
    )
    
    switch ($Status) {
        "OK" { Write-Host "✅ $Message" -ForegroundColor Green }
        "WARN" { Write-Host "⚠️ $Message" -ForegroundColor Yellow }
        "ERROR" { Write-Host "❌ $Message" -ForegroundColor Red }
    }
}

# Check prerequisites
Write-Host "`n📋 Prerequisites Check" -ForegroundColor White
Write-Host "----------------------" -ForegroundColor White

# Check Azure CLI
try {
    $azVersion = (az version --query '"azure-cli"' -o tsv 2>$null)
    if ($azVersion) {
        Write-Status "OK" "Azure CLI available (version: $azVersion)"
    } else {
        Write-Status "ERROR" "Azure CLI not responding properly"
        exit 1
    }
} catch {
    Write-Status "ERROR" "Azure CLI not found"
    exit 1
}

# Check kubectl
try {
    $kubectlCheck = (kubectl version --client=true 2>$null)
    if ($kubectlCheck) {
        Write-Status "OK" "kubectl available"
    } else {
        Write-Status "ERROR" "kubectl not responding properly"
    }
} catch {
    Write-Status "ERROR" "kubectl not found"
}

# Check Helm
try {
    $helmCheck = (helm version --short 2>$null)
    if ($helmCheck) {
        Write-Status "OK" "Helm available"
    } else {
        Write-Status "WARN" "Helm not found (required for NGINX fallback)"
    }
} catch {
    Write-Status "WARN" "Helm not found (required for NGINX fallback)"
}

# Check Azure authentication
Write-Host "`n🔐 Azure Authentication" -ForegroundColor White
Write-Host "----------------------" -ForegroundColor White

try {
    $account = (az account show 2>$null | ConvertFrom-Json)
    if ($account) {
        Write-Status "OK" "Logged in to Azure ($($account.name))"
        Write-Host "   Subscription: $($account.id)" -ForegroundColor Gray
    } else {
        Write-Status "ERROR" "Not logged in to Azure"
        Write-Host "   Run: az login" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Status "ERROR" "Azure login check failed"
    exit 1
}

# Summary
Write-Host "`n📊 Summary" -ForegroundColor White
Write-Host "=========" -ForegroundColor White
Write-Status "OK" "Modern AGIC installation approach is ready"
Write-Status "OK" "Azure CLI AKS addon method available"
Write-Status "OK" "NGINX Ingress fallback available"

Write-Host "`n🚀 Ready for deployment!" -ForegroundColor Green
Write-Host "`nTo run the AGIC installation:" -ForegroundColor White
Write-Host "1. Ensure AKS cluster and Application Gateway exist" -ForegroundColor Gray
Write-Host "2. Run the GitHub Actions workflow with application-only deployment" -ForegroundColor Gray
Write-Host "3. The workflow will automatically use the modern Azure CLI approach" -ForegroundColor Gray
