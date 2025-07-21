#!/bin/bash
set -e

# Emergency AKS Cluster Deletion Script
# This script deletes the failed AKS cluster to allow Terraform to create a new one

echo "🚨 Emergency AKS Cluster Deletion"
echo "=================================="
echo ""
echo "⚠️  WARNING: This script will DELETE the existing AKS cluster!"
echo "⚠️  This action is IRREVERSIBLE and will cause downtime."
echo "⚠️  Only run this if the cluster is in a failed state and cannot be recovered."
echo ""

# Set the resource details
SUBSCRIPTION_ID="d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"
RESOURCE_GROUP="rg-devops-pops-eastus"
AKS_CLUSTER_NAME="aks-devops-eastus"

echo "📋 Target Cluster:"
echo "  Subscription: $SUBSCRIPTION_ID"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  AKS Cluster: $AKS_CLUSTER_NAME"
echo ""

# Check if cluster exists and get its state
echo "🔍 Step 1: Checking cluster status..."
if ! az aks show --name "$AKS_CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "✅ Cluster does not exist - no deletion needed"
    echo "   Terraform can proceed with creating a new cluster"
    exit 0
fi

# Get cluster details
CLUSTER_INFO=$(az aks show --name "$AKS_CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --output json 2>/dev/null)
CLUSTER_STATE=$(echo "$CLUSTER_INFO" | jq -r '.provisioningState // "unknown"')
CLUSTER_POWER_STATE=$(echo "$CLUSTER_INFO" | jq -r '.powerState.code // "unknown"')

echo "📊 Cluster Details:"
echo "  Provisioning State: $CLUSTER_STATE"
echo "  Power State: $CLUSTER_POWER_STATE"
echo ""

# Check if cluster is in a failed state
if [ "$CLUSTER_STATE" = "Failed" ]; then
    echo "🚨 CONFIRMED: Cluster is in FAILED state"
    echo "   This cluster cannot be recovered and must be deleted"
    echo ""
elif [ "$CLUSTER_STATE" = "Succeeded" ]; then
    echo "⚠️  WARNING: Cluster appears to be in SUCCEEDED state"
    echo "   Are you sure you want to delete a working cluster?"
    echo ""
    echo "   If you're seeing import errors, consider:"
    echo "   1. Configuration mismatch between Terraform and existing cluster"
    echo "   2. Updating Terraform configuration to match existing cluster"
    echo "   3. Using force import instead of deletion"
    echo ""
    read -p "   Type 'DELETE_WORKING_CLUSTER' to confirm deletion of working cluster: " confirm
    if [ "$confirm" != "DELETE_WORKING_CLUSTER" ]; then
        echo "❌ Deletion cancelled by user"
        exit 1
    fi
else
    echo "⚠️  Cluster state is: $CLUSTER_STATE"
    echo "   This may indicate the cluster is in transition or another state"
    echo ""
fi

# Confirm deletion
echo "🚨 FINAL CONFIRMATION REQUIRED"
echo ""
echo "This will:"
echo "  ✓ Delete the AKS cluster: $AKS_CLUSTER_NAME"
echo "  ✓ Delete the node resource group: rg-aks-nodes-devops-eastus"
echo "  ✓ Delete all cluster nodes, load balancers, and associated resources"
echo "  ✓ Allow Terraform to create a fresh, working cluster"
echo ""
echo "This will NOT affect:"
echo "  ✓ Main resource group: $RESOURCE_GROUP"  
echo "  ✓ Virtual network, subnets, NSGs"
echo "  ✓ Application Gateway"
echo "  ✓ User-assigned managed identity"
echo "  ✓ Log Analytics, Application Insights"
echo "  ✓ Container Registry"
echo ""

read -p "Type 'DELETE_CLUSTER_NOW' to proceed with deletion: " final_confirm
if [ "$final_confirm" != "DELETE_CLUSTER_NOW" ]; then
    echo "❌ Deletion cancelled by user"
    exit 1
fi

echo ""
echo "🗑️  Step 2: Deleting AKS cluster..."
echo "   This may take 5-10 minutes..."

# Delete the cluster
echo "   Running: az aks delete --name $AKS_CLUSTER_NAME --resource-group $RESOURCE_GROUP --yes"
if az aks delete --name "$AKS_CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --yes; then
    echo ""
    echo "✅ SUCCESS: AKS cluster deleted successfully!"
    echo ""
    echo "🎯 Next steps:"
    echo "1. The failed cluster has been removed"
    echo "2. Re-run the GitHub Actions deployment"
    echo "3. Terraform will create a new, working AKS cluster"
    echo "4. All imported resources are preserved"
    echo "5. Monitor the deployment for successful cluster creation"
    echo ""
    echo "Expected outcome:"
    echo "✓ New AKS cluster will be created with correct configuration"
    echo "✓ Managed identity and role assignments already working"
    echo "✓ All network and gateway resources already in place"
    echo "✓ Complete deployment should succeed"
else
    deletion_exit_code=$?
    echo ""
    echo "❌ Failed to delete AKS cluster (exit code: $deletion_exit_code)"
    echo ""
    echo "Possible causes:"
    echo "1. Permissions issue - ensure you have Contributor access"
    echo "2. Cluster is locked or has delete protection"
    echo "3. Azure service issue - try again in a few minutes"
    echo ""
    echo "Manual alternatives:"
    echo "1. Try deletion via Azure Portal"
    echo "2. Use Azure PowerShell: Remove-AzAksCluster"
    echo "3. Contact Azure support if cluster is stuck"
    echo ""
    exit $deletion_exit_code
fi
