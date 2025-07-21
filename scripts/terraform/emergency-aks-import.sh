#!/bin/bash
set -e

# Emergency AKS Cluster Import Fix
# Run this manually if the automated import script fails to import the AKS cluster

echo "🚨 Emergency AKS Cluster Import Fix"
echo "==================================="

# Check if we're in the right directory
if [ ! -f "main.tf" ]; then
    echo "❌ Error: Not in terraform directory. Please run from infra/terraform/"
    echo "   cd infra/terraform"
    echo "   ../../scripts/terraform/emergency-aks-import.sh"
    exit 1
fi

# Set the resource details
SUBSCRIPTION_ID="d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"
RESOURCE_GROUP="rg-devops-pops-eastus"
AKS_CLUSTER_NAME="aks-devops-eastus"

echo "📋 Import Details:"
echo "  Subscription: $SUBSCRIPTION_ID"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  AKS Cluster: $AKS_CLUSTER_NAME"
echo ""

# Construct the full resource ID
AKS_RESOURCE_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.ContainerService/managedClusters/${AKS_CLUSTER_NAME}"

echo "🔍 Step 1: Checking if AKS cluster is already in Terraform state..."
if terraform state show "azurerm_kubernetes_cluster.main" >/dev/null 2>&1; then
    echo "✅ AKS cluster is already in Terraform state!"
    echo ""
    echo "If you're still getting the 'already exists' error, try:"
    echo "1. terraform plan (to see what changes are needed)"
    echo "2. terraform refresh (to sync state with Azure)"
    exit 0
fi

echo "❌ AKS cluster not in Terraform state"

echo ""
echo "🔍 Step 2: Verifying AKS cluster exists in Azure..."
if ! az aks show --name "$AKS_CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "❌ AKS cluster not found in Azure!"
    echo "   This shouldn't happen based on the error message."
    echo "   Please verify the cluster name and resource group."
    exit 1
fi

echo "✅ AKS cluster exists in Azure"

echo ""
echo "🔧 Step 3: Importing AKS cluster into Terraform state..."
echo "Import command: terraform import azurerm_kubernetes_cluster.main \"$AKS_RESOURCE_ID\""
echo ""

# Attempt the import
if terraform import "azurerm_kubernetes_cluster.main" "$AKS_RESOURCE_ID"; then
    echo ""
    echo "🎉 SUCCESS: AKS cluster imported successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Run: terraform plan"
    echo "2. If plan looks good, run: terraform apply"
    echo "3. Continue with application deployment"
else
    import_exit_code=$?
    echo ""
    echo "❌ Import failed (exit code: $import_exit_code)"
    echo ""
    echo "Possible solutions:"
    echo ""
    echo "Option 1 - Configuration mismatch (most likely):"
    echo "  The existing cluster configuration doesn't match Terraform"
    echo "  Check: identity type, network settings, node pools, etc."
    echo "  Solution: Update Terraform config to match existing cluster"
    echo ""
    echo "Option 2 - Force recreation (causes downtime):"
    echo "  az aks delete --name $AKS_CLUSTER_NAME --resource-group $RESOURCE_GROUP"
    echo "  terraform apply  # Will create new cluster"
    echo ""
    echo "Option 3 - Detailed analysis:"
    echo "  ../../scripts/terraform/aks-import-troubleshoot.sh"
    echo ""
    exit $import_exit_code
fi
