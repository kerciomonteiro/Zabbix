# Emergency AKS Cluster Deletion Script - PowerShell Version
# This script deletes the failed AKS cluster to allow Terraform to create a new one

Write-Host "🚨 Emergency AKS Cluster Deletion" -ForegroundColor Red
Write-Host "==================================" -ForegroundColor Red
Write-Host ""
Write-Host "⚠️  WARNING: This script will DELETE the existing AKS cluster!" -ForegroundColor Yellow
Write-Host "⚠️  This action is IRREVERSIBLE and will cause downtime." -ForegroundColor Yellow
Write-Host "⚠️  Only run this if the cluster is in a failed state and cannot be recovered." -ForegroundColor Yellow
Write-Host ""

# Set the resource details
$SUBSCRIPTION_ID = "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"
$RESOURCE_GROUP = "rg-devops-pops-eastus"
$AKS_CLUSTER_NAME = "aks-devops-eastus"

Write-Host "📋 Target Cluster:" -ForegroundColor Blue
Write-Host "  Subscription: $SUBSCRIPTION_ID"
Write-Host "  Resource Group: $RESOURCE_GROUP"
Write-Host "  AKS Cluster: $AKS_CLUSTER_NAME"
Write-Host ""

# Check if cluster exists and get its state
Write-Host "🔍 Step 1: Checking cluster status..." -ForegroundColor Blue

try {
    $CLUSTER_STATE = az aks show --name $AKS_CLUSTER_NAME --resource-group $RESOURCE_GROUP --query "provisioningState" --output tsv
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✅ Cluster does not exist - no deletion needed" -ForegroundColor Green
        Write-Host "   Terraform can proceed with creating a new cluster"
        exit 0
    }
    
    Write-Host "📊 Cluster Details:" -ForegroundColor Blue
    Write-Host "  Provisioning State: $CLUSTER_STATE"
    Write-Host ""
    
    # Check if cluster is in a failed state
    if ($CLUSTER_STATE -eq "Failed") {
        Write-Host "🚨 CONFIRMED: Cluster is in FAILED state" -ForegroundColor Red
        Write-Host "   This cluster cannot be recovered and must be deleted"
        Write-Host ""
    }
    elseif ($CLUSTER_STATE -eq "Succeeded") {
        Write-Host "⚠️  WARNING: Cluster appears to be in SUCCEEDED state" -ForegroundColor Yellow
        Write-Host "   Are you sure you want to delete a working cluster?" -ForegroundColor Yellow
        Write-Host ""
        $confirm = Read-Host "   Type 'DELETE_WORKING_CLUSTER' to confirm deletion of working cluster"
        if ($confirm -ne "DELETE_WORKING_CLUSTER") {
            Write-Host "❌ Deletion cancelled by user" -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "⚠️  Cluster state is: $CLUSTER_STATE" -ForegroundColor Yellow
        Write-Host "   This may indicate the cluster is in transition or another state"
        Write-Host ""
    }
}
catch {
    Write-Host "❌ Error checking cluster status: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Confirm deletion
Write-Host "🚨 FINAL CONFIRMATION REQUIRED" -ForegroundColor Red
Write-Host ""
Write-Host "This will:" -ForegroundColor Yellow
Write-Host "  ✓ Delete the AKS cluster: $AKS_CLUSTER_NAME"
Write-Host "  ✓ Delete the node resource group"
Write-Host "  ✓ Delete all cluster nodes, load balancers, and associated resources"
Write-Host "  ✓ Allow Terraform to create a fresh, working cluster"
Write-Host ""
Write-Host "This will NOT affect:" -ForegroundColor Green
Write-Host "  ✓ Main resource group: $RESOURCE_GROUP"
Write-Host "  ✓ Virtual network, subnets, NSGs"
Write-Host "  ✓ Application Gateway"
Write-Host "  ✓ User-assigned managed identity"
Write-Host "  ✓ Log Analytics, Application Insights"
Write-Host "  ✓ Container Registry"
Write-Host ""

$final_confirm = Read-Host "Type 'DELETE_CLUSTER_NOW' to proceed with deletion"
if ($final_confirm -ne "DELETE_CLUSTER_NOW") {
    Write-Host "❌ Deletion cancelled by user" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🗑️  Step 2: Deleting AKS cluster..." -ForegroundColor Red
Write-Host "   This may take 5-10 minutes..." -ForegroundColor Yellow

# Delete the cluster
Write-Host "   Running deletion command..."
az aks delete --name $AKS_CLUSTER_NAME --resource-group $RESOURCE_GROUP --yes

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ SUCCESS: AKS cluster deleted successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎯 Next steps:" -ForegroundColor Blue
    Write-Host "1. The failed cluster has been removed"
    Write-Host "2. Re-run the GitHub Actions deployment"
    Write-Host "3. Terraform will create a new, working AKS cluster"
    Write-Host "4. All imported resources are preserved"
    Write-Host "5. Monitor the deployment for successful cluster creation"
}
else {
    Write-Host ""
    Write-Host "❌ Failed to delete AKS cluster" -ForegroundColor Red
    Write-Host ""
    Write-Host "Manual alternatives:" -ForegroundColor Yellow
    Write-Host "1. Try deletion via Azure Portal"
    Write-Host "2. Contact Azure support if cluster is stuck"
    exit 1
}
