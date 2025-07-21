#!/bin/bash
# Quick Import Fix - Manual execution script for immediate import resolution
# Use this when you need to quickly fix import errors in local development

set -e

echo "🔧 Quick Terraform Import Fix - Manual Execution"
echo "This script imports the specific resources that are currently failing"

# Check if we're in the right directory
if [ ! -f "main.tf" ]; then
    echo "❌ Error: Please run this script from the infra/terraform directory"
    echo "   Current directory: $(pwd)"
    exit 1
fi

# Check environment variables (optional for manual use)
AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf}"
AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-devops-pops-eastus}"

echo "📋 Using configuration:"
echo "  Subscription ID: $AZURE_SUBSCRIPTION_ID"
echo "  Resource Group: $AZURE_RESOURCE_GROUP"

# Simple import function
quick_import() {
    local tf_resource="$1"
    local azure_id="$2"
    local display_name="$3"
    
    echo ""
    echo "==> Importing $display_name..."
    
    # Check if already in state
    if terraform state show "$tf_resource" >/dev/null 2>&1; then
        echo "    ✅ Already in state - skipping"
        return 0
    fi
    
    # Try import
    echo "    🔄 Importing..."
    if terraform import "$tf_resource" "$azure_id" 2>/dev/null; then
        echo "    ✅ Success!"
        return 0
    else
        echo "    ❌ Failed (resource may not exist or already managed)"
        return 1
    fi
}

echo ""
echo "🎯 Importing the specific resources that are currently failing..."

# Import the exact resources from the current error message
quick_import "azurerm_user_assigned_identity.aks" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-devops-eastus" \
    "User Assigned Identity"

quick_import "azurerm_log_analytics_solution.container_insights[0]" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.OperationsManagement/solutions/ContainerInsights(law-devops-eastus)" \
    "Container Insights Solution"

quick_import "azurerm_application_insights.main[0]" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Insights/components/ai-devops-eastus" \
    "Application Insights"

quick_import "azurerm_kubernetes_cluster.main" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.ContainerService/managedClusters/aks-devops-eastus" \
    "AKS Cluster"

echo ""
echo "✅ Quick import fix completed!"
echo ""
echo "🔍 Next steps:"
echo "1. Run 'terraform plan' to verify the imports worked"
echo "2. Run 'terraform apply' to proceed with deployment"
echo "3. If still having issues, run the full import fix script"
