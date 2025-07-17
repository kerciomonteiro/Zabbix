# Zabbix AKS Deployment Setup Script
# Run this script after authenticating with the correct Azure tenant

param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId = "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf",
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName = "Devops-Test",
    
    [Parameter(Mandatory=$true)]
    [string]$EnvironmentName = "zabbix-prod",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus"
)

Write-Host "Starting Zabbix AKS deployment setup..." -ForegroundColor Green

# Set the subscription
Write-Host "Setting Azure subscription..." -ForegroundColor Yellow
az account set --subscription $SubscriptionId

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set subscription. Please ensure you're authenticated and have access to subscription $SubscriptionId"
    exit 1
}

# Verify resource group exists
Write-Host "Verifying resource group exists..." -ForegroundColor Yellow
$rgExists = az group exists --name $ResourceGroupName --subscription $SubscriptionId --output tsv
if ($rgExists -eq "false") {
    Write-Error "Resource group '$ResourceGroupName' does not exist in subscription '$SubscriptionId'"
    exit 1
}

# Get current user principal ID for role assignments
Write-Host "Getting current user principal ID..." -ForegroundColor Yellow
$currentUser = az ad signed-in-user show --query id --output tsv
if (-not $currentUser) {
    Write-Error "Failed to get current user principal ID"
    exit 1
}

# Initialize azd environment
Write-Host "Initializing azd environment..." -ForegroundColor Yellow
azd env new $EnvironmentName --subscription $SubscriptionId --location $Location

# Set azd environment variables
Write-Host "Setting environment variables..." -ForegroundColor Yellow
azd env set AZURE_SUBSCRIPTION_ID $SubscriptionId
azd env set AZURE_RESOURCE_GROUP $ResourceGroupName
azd env set AZURE_LOCATION $Location
azd env set AZURE_PRINCIPAL_ID $currentUser

Write-Host "Setup completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Run 'azd up' to deploy the infrastructure and application" -ForegroundColor White
Write-Host "2. Configure your SSL certificate in Azure Key Vault" -ForegroundColor White
Write-Host "3. Update DNS to point dal2-devmon-mgt.forescout.com to the Application Gateway public IP" -ForegroundColor White
Write-Host ""
Write-Host "Environment Details:" -ForegroundColor Cyan
Write-Host "- Subscription: $SubscriptionId" -ForegroundColor White
Write-Host "- Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "- Environment: $EnvironmentName" -ForegroundColor White
Write-Host "- Location: $Location" -ForegroundColor White
Write-Host "- Principal ID: $currentUser" -ForegroundColor White
