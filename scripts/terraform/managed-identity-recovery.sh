#!/bin/bash
# Managed Identity Recovery Script
# Use this when AKS creation fails due to managed identity credential issues

set -e

echo "🔧 Managed Identity Recovery Script"
echo "This script helps resolve managed identity credential reconciliation issues"

# Validate environment variables
AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf}"
AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-devops-pops-eastus}"

echo "📋 Using configuration:"
echo "  Subscription ID: $AZURE_SUBSCRIPTION_ID"
echo "  Resource Group: $AZURE_RESOURCE_GROUP"

# Function to check managed identity status
check_identity_status() {
    echo ""
    echo "🔍 Checking managed identity status..."
    
    local identity_name="id-devops-eastus"
    local identity_id="/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${identity_name}"
    
    if az resource show --ids "$identity_id" >/dev/null 2>&1; then
        echo "  ✅ Managed identity exists in Azure"
        
        # Get principal ID
        local principal_id=$(az identity show --name "$identity_name" --resource-group "$AZURE_RESOURCE_GROUP" --query principalId -o tsv 2>/dev/null || echo "")
        
        if [ -n "$principal_id" ]; then
            echo "  ✅ Principal ID found: $principal_id"
            
            # Check role assignments
            echo "  🔍 Checking role assignments..."
            local role_count=$(az role assignment list --assignee "$principal_id" --query "length(@)" -o tsv 2>/dev/null || echo "0")
            echo "  📋 Role assignments: $role_count"
            
            if [ "$role_count" -gt 0 ]; then
                echo "  ✅ Identity has role assignments"
                az role assignment list --assignee "$principal_id" --query "[].{Role:roleDefinitionName, Scope:scope}" -o table
            else
                echo "  ❌ Identity has no role assignments - this may cause issues"
            fi
        else
            echo "  ❌ Principal ID not found - identity may not be fully provisioned"
        fi
    else
        echo "  ❌ Managed identity not found in Azure"
        return 1
    fi
}

# Function to wait for identity propagation
wait_for_propagation() {
    echo ""
    echo "⏳ Waiting for managed identity propagation..."
    echo "   This can take up to 2 minutes for global propagation"
    
    for i in {1..12}; do
        echo "   Waiting... ${i}/12 (${i}0 seconds)"
        sleep 10
        
        # Try to get the identity again
        if az identity show --name "id-devops-eastus" --resource-group "$AZURE_RESOURCE_GROUP" --query principalId -o tsv >/dev/null 2>&1; then
            echo "   ✅ Identity accessible - propagation likely complete"
            break
        fi
    done
}

# Function to recreate role assignments if needed
recreate_role_assignments() {
    echo ""
    echo "🔧 Recreating role assignments (if needed)..."
    
    local identity_name="id-devops-eastus"
    local principal_id=$(az identity show --name "$identity_name" --resource-group "$AZURE_RESOURCE_GROUP" --query principalId -o tsv 2>/dev/null || echo "")
    
    if [ -z "$principal_id" ]; then
        echo "  ❌ Cannot get principal ID - identity not ready"
        return 1
    fi
    
    echo "  👤 Principal ID: $principal_id"
    
    # Role assignments to create/verify
    declare -A role_assignments=(
        ["Contributor"]="/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}"
        ["Network Contributor"]="/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus"
        ["AcrPull"]="/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.ContainerRegistry/registries/acrdevopseastus"
    )
    
    for role in "${!role_assignments[@]}"; do
        local scope="${role_assignments[$role]}"
        echo "  🔍 Checking $role assignment on scope..."
        
        # Check if assignment already exists
        if az role assignment list --assignee "$principal_id" --role "$role" --scope "$scope" --query "[0].id" -o tsv >/dev/null 2>&1; then
            echo "    ✅ $role assignment already exists"
        else
            echo "    🔧 Creating $role assignment..."
            if az role assignment create --assignee "$principal_id" --role "$role" --scope "$scope" >/dev/null 2>&1; then
                echo "    ✅ $role assignment created successfully"
            else
                echo "    ❌ Failed to create $role assignment"
            fi
        fi
    done
}

# Main execution
echo ""
echo "🚀 Starting managed identity recovery process..."

check_identity_status

if [ $? -eq 0 ]; then
    recreate_role_assignments
    wait_for_propagation
    check_identity_status
    
    echo ""
    echo "✅ Managed identity recovery completed"
    echo ""
    echo "🔍 Next steps:"
    echo "1. Wait 2-3 minutes for Azure AD propagation"
    echo "2. Retry Terraform deployment: terraform apply"
    echo "3. If still failing, consider switching to system-assigned identity"
else
    echo ""
    echo "❌ Managed identity not found - may need to be created first"
    echo ""
    echo "🔍 Troubleshooting:"
    echo "1. Ensure Terraform has created the managed identity"
    echo "2. Check Azure portal for identity status"
    echo "3. Verify subscription and resource group are correct"
fi

echo ""
echo "📚 For more details, see MANAGED_IDENTITY_FIX.md"
