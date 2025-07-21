#!/bin/bash
set -e

# AKS Cluster Import Troubleshooting Script
# This script helps diagnose and resolve AKS cluster import issues

echo "🔧 AKS Cluster Import Troubleshooting"
echo "======================================"

# Validate environment
if [[ -z "$AZURE_SUBSCRIPTION_ID" || -z "$AZURE_RESOURCE_GROUP" ]]; then
    echo "❌ Error: Required environment variables missing"
    echo "   AZURE_SUBSCRIPTION_ID: ${AZURE_SUBSCRIPTION_ID:-'Not set'}"
    echo "   AZURE_RESOURCE_GROUP: ${AZURE_RESOURCE_GROUP:-'Not set'}"
    exit 1
fi

echo "📋 Configuration:"
echo "  Subscription: $AZURE_SUBSCRIPTION_ID"
echo "  Resource Group: $AZURE_RESOURCE_GROUP"
echo "  Expected AKS Name: aks-devops-eastus"
echo ""

# Step 1: Check Terraform state
echo "🔍 Step 1: Checking Terraform state..."
if terraform state show "azurerm_kubernetes_cluster.main" >/dev/null 2>&1; then
    echo "✅ AKS cluster found in Terraform state"
    echo ""
    terraform state show "azurerm_kubernetes_cluster.main" | head -n 10
    echo "..."
    echo ""
    echo "If the cluster is in state but deployment fails, there may be a configuration drift."
    echo "Consider running: terraform plan to see what needs to be updated"
    exit 0
else
    echo "❌ AKS cluster NOT found in Terraform state"
fi

# Step 2: Check if AKS cluster exists in Azure
echo ""
echo "🔍 Step 2: Checking Azure for existing cluster..."
AKS_INFO=$(az aks show --name "aks-devops-eastus" --resource-group "$AZURE_RESOURCE_GROUP" --output json 2>/dev/null || echo "null")

if [ "$AKS_INFO" = "null" ]; then
    echo "❌ AKS cluster does not exist in Azure"
    echo ""
    echo "✅ Resolution: No action needed - Terraform will create the cluster"
    echo "   Run: terraform apply"
    exit 0
fi

echo "✅ AKS cluster exists in Azure"

# Step 3: Analyze cluster properties
echo ""
echo "🔍 Step 3: Analyzing cluster properties..."
AKS_ID=$(echo "$AKS_INFO" | jq -r '.id')
AKS_STATE=$(echo "$AKS_INFO" | jq -r '.provisioningState // "unknown"')
AKS_VERSION=$(echo "$AKS_INFO" | jq -r '.kubernetesVersion // "unknown"')
AKS_IDENTITY_TYPE=$(echo "$AKS_INFO" | jq -r '.identity.type // "unknown"')
AKS_IDENTITY_ID=$(echo "$AKS_INFO" | jq -r '.identity.userAssignedIdentities | keys[0] // "none"')
AKS_SUBNET_ID=$(echo "$AKS_INFO" | jq -r '.agentPoolProfiles[0].vnetSubnetId // "unknown"')
AKS_NODE_RG=$(echo "$AKS_INFO" | jq -r '.nodeResourceGroup // "unknown"')

echo "  Resource ID: $AKS_ID"
echo "  Provisioning State: $AKS_STATE"
echo "  Kubernetes Version: $AKS_VERSION"
echo "  Identity Type: $AKS_IDENTITY_TYPE"
echo "  Identity ID: $AKS_IDENTITY_ID"
echo "  Subnet ID: $AKS_SUBNET_ID"
echo "  Node Resource Group: $AKS_NODE_RG"

# Step 4: Attempt import with detailed diagnostics
echo ""
echo "🔍 Step 4: Attempting import with diagnostics..."
echo "Import command: terraform import azurerm_kubernetes_cluster.main \"$AKS_ID\""
echo ""

set +e
import_output=$(terraform import "azurerm_kubernetes_cluster.main" "$AKS_ID" 2>&1)
import_exit_code=$?
set -e

if [ $import_exit_code -eq 0 ]; then
    echo "✅ Import successful!"
    echo ""
    echo "Next steps:"
    echo "1. Run: terraform plan"
    echo "2. If plan shows changes, run: terraform apply"
    exit 0
fi

echo "❌ Import failed (exit code: $import_exit_code)"
echo ""
echo "Error details:"
echo "$import_output"
echo ""

# Step 5: Analyze import failure and provide solutions
echo "🔍 Step 5: Analyzing import failure..."

if echo "$import_output" | grep -i "already managed by Terraform\|Resource already managed"; then
    echo "✅ Actually successful - resource already managed by Terraform"
    echo ""
    echo "Resolution: No action needed"
    
elif echo "$import_output" | grep -i "does not exist\|not found"; then
    echo "❌ Resource not found error (unexpected)"
    echo ""
    echo "This shouldn't happen since we verified the cluster exists."
    echo "Possible causes:"
    echo "1. Permissions issue accessing the resource"
    echo "2. Resource ID format incorrect"
    echo "3. Race condition - resource was deleted between checks"
    
elif echo "$import_output" | grep -i "configuration.*not.*compatible\|incompatible\|conflicts"; then
    echo "❌ Configuration incompatibility detected"
    echo ""
    echo "This means the existing cluster configuration doesn't match"
    echo "the Terraform configuration. Common causes:"
    echo ""
    echo "1. Identity configuration mismatch"
    echo "2. Network configuration changes" 
    echo "3. Node pool configuration drift"
    echo "4. Version or SKU differences"
    echo ""
    echo "Resolution options:"
    echo ""
    echo "Option 1 - Update Terraform to match existing cluster:"
    echo "  - Review the cluster properties above"
    echo "  - Update terraform configuration to match"
    echo "  - Retry the import"
    echo ""
    echo "Option 2 - Delete and recreate cluster:"
    echo "  - WARNING: This will cause downtime!"
    echo "  - az aks delete --name aks-devops-eastus --resource-group $AZURE_RESOURCE_GROUP"
    echo "  - terraform apply"
    echo ""
    echo "Option 3 - Force import (risky):"
    echo "  - terraform import -replace azurerm_kubernetes_cluster.main \"$AKS_ID\""
    echo "  - This will recreate the cluster during next apply"
    
else
    echo "❌ Unknown import error"
    echo ""
    echo "Manual investigation required. Common troubleshooting:"
    echo ""
    echo "1. Verify Terraform version compatibility"
    echo "2. Check Azure CLI authentication: az account show"
    echo "3. Verify permissions: az role assignment list --scope \"$AKS_ID\""
    echo "4. Try importing with debug: TF_LOG=DEBUG terraform import ..."
fi

echo ""
echo "🎯 Recommended next actions:"
echo "1. Review the analysis above"
echo "2. Choose appropriate resolution option"
echo "3. Test with: terraform plan"
echo "4. Apply changes: terraform apply"
