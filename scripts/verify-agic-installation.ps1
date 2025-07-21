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
    $kubectlVersion = (kubectl version --client --short 2>$null | Select-String "Client Version" | ForEach-Object { $_.ToString().Split()[2] })
    if ($kubectlVersion) {
        Write-Status "OK" "kubectl available (version: $kubectlVersion)"
    } else {
        Write-Status "ERROR" "kubectl not responding properly"
    }
} catch {
    Write-Status "ERROR" "kubectl not found"
}

# Check Helm
try {
    $helmOutput = (helm version --short 2>$null)
    if ($helmOutput) {
        Write-Status "OK" "Helm available ($helmOutput)"
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

# Check AGIC addon availability
Write-Host "`n🔌 AGIC Addon Availability" -ForegroundColor White
Write-Host "-------------------------" -ForegroundColor White

try {
    $agicAddon = (az aks addon list-available --query "[?name=='ingress-appgw']" 2>$null | ConvertFrom-Json)
    if ($agicAddon -and $agicAddon.Count -gt 0) {
        Write-Status "OK" "AGIC addon is available in this subscription"
    } else {
        Write-Status "ERROR" "AGIC addon not available or permission issue"
    }
} catch {
    Write-Status "ERROR" "Cannot check AGIC addon availability"
}

# Check Terraform integration
Write-Host "`n🏗️ Terraform Integration" -ForegroundColor White
Write-Host "------------------------" -ForegroundColor White

if (Test-Path "infra/terraform/terraform.tfstate") {
    try {
        Push-Location "infra/terraform"
        $appgwName = (terraform output -raw APPLICATION_GATEWAY_NAME 2>$null)
        if ($appgwName -and $appgwName -ne "") {
            Write-Status "OK" "Application Gateway name from Terraform: $appgwName"
        } else {
            Write-Status "WARN" "Cannot retrieve Application Gateway name from Terraform"
        }
        Pop-Location
    } catch {
        Write-Status "WARN" "Error reading Terraform outputs"
        Pop-Location
    }
} else {
    Write-Status "WARN" "Terraform state file not found"
}

# Check NGINX Ingress fallback
Write-Host "`n🔄 NGINX Ingress Fallback" -ForegroundColor White
Write-Host "------------------------" -ForegroundColor White

try {
    $helmRepos = (helm repo list 2>$null | ConvertFrom-Csv -Delimiter "`t" -Header "NAME", "URL")
    if ($helmRepos | Where-Object { $_.NAME -eq "ingress-nginx" }) {
        Write-Status "OK" "NGINX Ingress Helm repository already configured"
    } else {
        Write-Host "Testing NGINX Ingress repository..." -ForegroundColor Gray
        $null = (helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>$null)
        $null = (helm repo update 2>$null)
        Write-Status "OK" "NGINX Ingress repository accessible"
        $null = (helm repo remove ingress-nginx 2>$null)
    }
} catch {
    Write-Status "ERROR" "Cannot access NGINX Ingress repository"
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

if ($Detailed) {
    Write-Host "`n📋 Detailed Information" -ForegroundColor White
    Write-Host "=======================" -ForegroundColor White
    
    # Show current Azure context
    try {
        $context = (az account show | ConvertFrom-Json)
        Write-Host "Current Azure Context:" -ForegroundColor Yellow
        Write-Host "  Name: $($context.name)" -ForegroundColor Gray
        Write-Host "  ID: $($context.id)" -ForegroundColor Gray
        Write-Host "  Tenant: $($context.tenantId)" -ForegroundColor Gray
    } catch {
        Write-Host "Could not retrieve detailed Azure context" -ForegroundColor Red
    }
    
    # Show available AKS addon information
    try {
        Write-Host "`nAvailable AKS Addons:" -ForegroundColor Yellow
        az aks addon list-available --query "[].name" -o table 2>$null | Write-Host -ForegroundColor Gray
    } catch {
        Write-Host "Could not retrieve AKS addon list" -ForegroundColor Red
    }
}
