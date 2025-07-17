# Azure Credentials JSON Generator for GitHub Actions
# This script helps you generate the correct AZURE_CREDENTIALS JSON format

Write-Host "Azure Credentials JSON Generator for GitHub Actions" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Please provide the following information from your Azure service principal:" -ForegroundColor Yellow
Write-Host ""

# Get client ID
$ClientId = Read-Host "Enter Application (client) ID"

# Get client secret
$ClientSecret = Read-Host "Enter Client Secret" -AsSecureString
$ClientSecretText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ClientSecret))

# Get tenant ID
$TenantId = Read-Host "Enter Directory (tenant) ID"

# Subscription ID is fixed
$SubscriptionId = "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"

Write-Host ""
Write-Host "Generated AZURE_CREDENTIALS JSON:" -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Green

# Generate the JSON
$jsonCredentials = @{
    clientId = $ClientId
    clientSecret = $ClientSecretText
    subscriptionId = $SubscriptionId
    tenantId = $TenantId
} | ConvertTo-Json -Compress

Write-Host $jsonCredentials -ForegroundColor White

Write-Host ""
Write-Host "Instructions:" -ForegroundColor Yellow
Write-Host "1. Copy the JSON above (including the curly braces)" -ForegroundColor White
Write-Host "2. Go to your GitHub repository" -ForegroundColor White
Write-Host "3. Navigate to Settings > Secrets and variables > Actions" -ForegroundColor White
Write-Host "4. Click 'New repository secret'" -ForegroundColor White
Write-Host "5. Name: AZURE_CREDENTIALS" -ForegroundColor White
Write-Host "6. Value: Paste the JSON above" -ForegroundColor White
Write-Host "7. Click 'Add secret'" -ForegroundColor White
Write-Host ""
Write-Host "Important: Make sure there are no extra spaces or line breaks in the JSON!" -ForegroundColor Red

# Also save to clipboard if possible
try {
    $jsonCredentials | Set-Clipboard
    Write-Host "JSON has been copied to your clipboard!" -ForegroundColor Green
} catch {
    Write-Host "Could not copy to clipboard automatically. Please copy manually." -ForegroundColor Yellow
}
