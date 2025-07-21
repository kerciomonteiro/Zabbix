# Zabbix AKS Deployment Verification Script
# Run this script after deployment to verify everything is working

param(
    [Parameter(Mandatory=$false)]
    [string]$EnvironmentName = "zabbix-prod",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "Devops-Test"
)

Write-Host "🔍 Verifying Zabbix AKS deployment..." -ForegroundColor Green

# Check azd environment
Write-Host "📋 Checking azd environment..." -ForegroundColor Yellow
$azdEnvs = azd env list --output json | ConvertFrom-Json
$currentEnv = $azdEnvs | Where-Object { $_.Name -eq $EnvironmentName }

if (-not $currentEnv) {
    Write-Error "Environment '$EnvironmentName' not found. Available environments:"
    $azdEnvs | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor White }
    exit 1
}

Write-Host "✅ Environment '$EnvironmentName' found" -ForegroundColor Green

# Check AKS cluster
Write-Host "🏗️  Checking AKS cluster..." -ForegroundColor Yellow
$aksCluster = az aks list --resource-group $ResourceGroupName --query "[0]" --output json | ConvertFrom-Json

if (-not $aksCluster) {
    Write-Error "No AKS cluster found in resource group '$ResourceGroupName'"
    exit 1
}

Write-Host "✅ AKS cluster found: $($aksCluster.name)" -ForegroundColor Green

# Get AKS credentials
Write-Host "🔑 Getting AKS credentials..." -ForegroundColor Yellow
az aks get-credentials --resource-group $ResourceGroupName --name $aksCluster.name --overwrite-existing

# Check Kubernetes context
Write-Host "☸️  Checking Kubernetes context..." -ForegroundColor Yellow
$currentContext = kubectl config current-context 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to get Kubernetes context. Is kubectl installed?"
    exit 1
}

Write-Host "✅ Connected to Kubernetes context: $currentContext" -ForegroundColor Green

# Check Zabbix namespace
Write-Host "📦 Checking Zabbix namespace..." -ForegroundColor Yellow
$namespace = kubectl get namespace zabbix --output json 2>$null | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Zabbix namespace not found. You may need to deploy the Kubernetes manifests."
} else {
    Write-Host "✅ Zabbix namespace exists" -ForegroundColor Green
}

# Check Zabbix pods (if namespace exists)
if ($namespace) {
    Write-Host "🔍 Checking Zabbix pods..." -ForegroundColor Yellow
    kubectl get pods -n zabbix
    
    Write-Host "🌐 Checking Zabbix services..." -ForegroundColor Yellow
    kubectl get services -n zabbix
    
    Write-Host "🔗 Checking Zabbix ingress..." -ForegroundColor Yellow
    kubectl get ingress -n zabbix
}

# Check Application Gateway
Write-Host "🚪 Checking Application Gateway..." -ForegroundColor Yellow
$appGw = az network application-gateway list --resource-group $ResourceGroupName --query "[0]" --output json | ConvertFrom-Json

if ($appGw) {
    Write-Host "✅ Application Gateway found: $($appGw.name)" -ForegroundColor Green
    
    # Get public IP
    $publicIpId = $appGw.frontendIPConfigurations[0].publicIPAddress.id
    $publicIp = az network public-ip show --ids $publicIpId --query "ipAddress" --output tsv
    
    Write-Host "🌍 Application Gateway Public IP: $publicIp" -ForegroundColor Cyan
    Write-Host "📝 DNS Configuration needed:" -ForegroundColor Yellow
    Write-Host "   Point dal2-devmon-mgt.forescout.com to $publicIp" -ForegroundColor White
} else {
    Write-Warning "Application Gateway not found"
}

# Check Container Registry
Write-Host "📦 Checking Container Registry..." -ForegroundColor Yellow
$acr = az acr list --resource-group $ResourceGroupName --query "[0]" --output json | ConvertFrom-Json

if ($acr) {
    Write-Host "✅ Container Registry found: $($acr.name)" -ForegroundColor Green
} else {
    Write-Warning "Container Registry not found"
}

Write-Host ""
Write-Host "🎉 Deployment verification completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. If Zabbix pods are not running, deploy the Kubernetes manifests:" -ForegroundColor White
Write-Host "   kubectl apply -f k8s/" -ForegroundColor Gray
Write-Host "2. Configure SSL certificate in Azure Key Vault" -ForegroundColor White
Write-Host "3. Update DNS to point dal2-devmon-mgt.forescout.com to the Application Gateway IP" -ForegroundColor White
Write-Host "4. Test access to https://dal2-devmon-mgt.forescout.com" -ForegroundColor White
