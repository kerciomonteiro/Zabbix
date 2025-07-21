#!/bin/bash
set -e

# Quick Node Pool Import Fix
# This script specifically imports the missing AKS node pool

echo "🔧 Quick Node Pool Import Fix"
echo "==============================="
echo ""

AZURE_SUBSCRIPTION_ID="d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"
AZURE_RESOURCE_GROUP="rg-devops-pops-eastus"

echo "📋 Configuration:"
echo "  Subscription ID: $AZURE_SUBSCRIPTION_ID"
echo "  Resource Group: $AZURE_RESOURCE_GROUP"
echo ""

# Navigate to terraform directory
cd "$(dirname "$0")/../../infra/terraform" || exit 1

# Check if node pool already in state
if terraform state show "azurerm_kubernetes_cluster_node_pool.user" >/dev/null 2>&1; then
    echo "✅ Node pool already in Terraform state"
    exit 0
fi

# Verify node pool exists in Azure
NODE_POOL_ID="/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.ContainerService/managedClusters/aks-devops-eastus/agentPools/workerpool"

echo "🔍 Verifying node pool exists in Azure..."
if ! az resource show --ids "$NODE_POOL_ID" >/dev/null 2>&1; then
    echo "❌ Node pool not found in Azure: $NODE_POOL_ID"
    exit 1
fi

echo "✅ Node pool exists in Azure"
echo ""

# Import the node pool
echo "📥 Importing AKS node pool..."
echo "  Terraform resource: azurerm_kubernetes_cluster_node_pool.user"
echo "  Azure resource ID: $NODE_POOL_ID"
echo ""

if terraform import "azurerm_kubernetes_cluster_node_pool.user" "$NODE_POOL_ID"; then
    echo ""
    echo "✅ SUCCESS: AKS node pool imported successfully!"
    echo ""
    echo "🎯 Next steps:"
    echo "1. The node pool is now in Terraform state"
    echo "2. Re-run terraform apply to continue deployment"
    echo "3. This should resolve the node pool conflict"
else
    echo ""
    echo "❌ Failed to import AKS node pool"
    echo ""
    echo "Possible causes:"
    echo "1. Node pool is in a transitioning state"
    echo "2. Permissions issue"
    echo "3. Resource ID mismatch"
    echo ""
    echo "Manual verification:"
    echo "  az aks nodepool show --cluster-name aks-devops-eastus --resource-group $AZURE_RESOURCE_GROUP --name workerpool"
    exit 1
fi
