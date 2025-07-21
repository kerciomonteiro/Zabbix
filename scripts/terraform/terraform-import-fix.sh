#!/bin/bash
set -e

# Terraform Import Fix Script
# This script specifically addresses the import errors shown in GitHub Actions
# It focuses on the resources that commonly fail during deployment

echo "🔧 Terraform Import Fix Script"
echo "This script addresses specific import errors that occur during GitHub Actions deployment"

# Validate environment variables
if [[ -z "$AZURE_SUBSCRIPTION_ID" || -z "$AZURE_RESOURCE_GROUP" ]]; then
    echo "❌ Error: Required environment variables missing"
    echo "   AZURE_SUBSCRIPTION_ID: ${AZURE_SUBSCRIPTION_ID:-'Not set'}"
    echo "   AZURE_RESOURCE_GROUP: ${AZURE_RESOURCE_GROUP:-'Not set'}"
    echo ""
    echo "ℹ️  Expected values:"
    echo "   AZURE_SUBSCRIPTION_ID: d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"
    echo "   AZURE_RESOURCE_GROUP: rg-devops-pops-eastus"
    exit 1
fi

echo "📋 Configuration:"
echo "  Subscription ID: $AZURE_SUBSCRIPTION_ID"
echo "  Resource Group: $AZURE_RESOURCE_GROUP"

# Function to safely attempt import without failing the script
try_import() {
    local tf_resource="$1"
    local azure_id="$2"
    local display_name="$3"
    
    echo ""
    echo "==> Attempting to import $display_name..."
    echo "    Terraform resource: $tf_resource"
    echo "    Azure resource ID: $azure_id"
    
    # Check if already in state
    if terraform state show "$tf_resource" >/dev/null 2>&1; then
        echo "    [SKIP] Resource already in Terraform state"
        return 0
    fi
    
    # Verify resource exists in Azure
    if ! az resource show --ids "$azure_id" >/dev/null 2>&1; then
        echo "    [SKIP] Resource not found in Azure"
        return 0
    fi
    
    # Attempt import
    echo "    [IMPORT] Importing into Terraform state..."
    local import_output=""
    import_output=$(terraform import "$tf_resource" "$azure_id" 2>&1) || {
        local import_exit_code=$?
        # Check if the error is due to resource already being managed
        if echo "$import_output" | grep -q "already managed by Terraform\|Resource already managed"; then
            echo "    [SUCCESS] Resource already properly managed by Terraform"
            return 0
        else
            echo "    [FAILED] Import failed - continuing anyway"
            echo "             Error: $(echo "$import_output" | head -n 3 | tr '\n' ' ')"
            return 1
        fi
    }
    echo "    [SUCCESS] Import successful"
    return 0
}

# Target the specific resources that commonly fail
echo ""
echo "🎯 Importing commonly failing resources in dependency order..."

# Phase 1: Identity and Core Resources (must be imported first)
echo ""
echo "=== Phase 1: Identity and Core Resources ==="

try_import "azurerm_user_assigned_identity.aks" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-devops-eastus" \
    "User Assigned Identity"

try_import "azurerm_log_analytics_workspace.main[0]" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.OperationalInsights/workspaces/law-devops-eastus" \
    "Log Analytics Workspace"

try_import "azurerm_log_analytics_solution.container_insights[0]" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.OperationsManagement/solutions/ContainerInsights(law-devops-eastus)" \
    "Container Insights Solution"

try_import "azurerm_application_insights.main[0]" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Insights/components/ai-devops-eastus" \
    "Application Insights"

try_import "azurerm_container_registry.main" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.ContainerRegistry/registries/acrdevopseastus" \
    "Container Registry"

# Phase 2: Network Infrastructure
echo ""
echo "=== Phase 2: Network Infrastructure ==="

try_import "azurerm_virtual_network.main" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus" \
    "Virtual Network"

try_import "azurerm_public_ip.appgw" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/publicIPAddresses/pip-appgw-devops-eastus" \
    "Application Gateway Public IP"

try_import "azurerm_network_security_group.aks" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/networkSecurityGroups/nsg-aks-devops-eastus" \
    "AKS Network Security Group"

try_import "azurerm_network_security_group.appgw" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/networkSecurityGroups/nsg-appgw-devops-eastus" \
    "App Gateway Network Security Group"

try_import "azurerm_subnet.aks" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus/subnets/subnet-aks-devops-eastus" \
    "AKS Subnet"

try_import "azurerm_subnet.appgw" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus/subnets/subnet-appgw-devops-eastus" \
    "App Gateway Subnet"

# Phase 3: Subnet Associations (depend on subnets and NSGs)
echo ""
echo "=== Phase 3: Subnet Network Security Group Associations ==="

try_import "azurerm_subnet_network_security_group_association.aks" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus/subnets/subnet-aks-devops-eastus" \
    "AKS Subnet NSG Association"

try_import "azurerm_subnet_network_security_group_association.appgw" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus/subnets/subnet-appgw-devops-eastus" \
    "App Gateway Subnet NSG Association"

# Phase 4: Complex Resources (depend on all above)
echo ""
echo "=== Phase 4: Complex Resources ==="

try_import "azurerm_application_gateway.main" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/applicationGateways/appgw-devops-eastus" \
    "Application Gateway"

# AKS cluster import with enhanced error handling
echo "==> Attempting to import AKS Cluster with enhanced diagnostics..."
echo "    Terraform resource: azurerm_kubernetes_cluster.main"
echo "    Expected Azure resource ID: /subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.ContainerService/managedClusters/aks-devops-eastus"

# Check if already in state first
if terraform state show "azurerm_kubernetes_cluster.main" >/dev/null 2>&1; then
    echo "    [SKIP] AKS cluster already in Terraform state"
else
    # Check if resource exists in Azure with detailed info
    echo "    [CHECK] Verifying AKS cluster exists in Azure..."
    AKS_INFO=$(az aks show --name "aks-devops-eastus" --resource-group "$AZURE_RESOURCE_GROUP" --output json 2>/dev/null || echo "null")
    
    if [ "$AKS_INFO" = "null" ]; then
        echo "    [INFO] AKS cluster not found in Azure - will be created by Terraform"
    else
        echo "    [FOUND] AKS cluster exists in Azure"
        
        # Get cluster details for troubleshooting
        AKS_STATE=$(echo "$AKS_INFO" | jq -r '.provisioningState // "unknown"')
        AKS_VERSION=$(echo "$AKS_INFO" | jq -r '.kubernetesVersion // "unknown"')
        AKS_IDENTITY_TYPE=$(echo "$AKS_INFO" | jq -r '.identity.type // "unknown"')
        
        echo "    [INFO] Cluster State: $AKS_STATE"
        echo "    [INFO] K8s Version: $AKS_VERSION"
        echo "    [INFO] Identity Type: $AKS_IDENTITY_TYPE"
        
        # Attempt import with detailed error capture
        echo "    [IMPORT] Attempting to import AKS cluster..."
        import_output=$(terraform import "azurerm_kubernetes_cluster.main" "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.ContainerService/managedClusters/aks-devops-eastus" 2>&1) || {
            import_exit_code=$?
            echo "    [FAILED] AKS cluster import failed (exit code: $import_exit_code)"
            
            # Analyze the error
            if echo "$import_output" | grep -i "already managed by Terraform\|Resource already managed"; then
                echo "    [SUCCESS] Resource already properly managed by Terraform"
            elif echo "$import_output" | grep -i "does not exist\|not found"; then
                echo "    [ERROR] Resource not found during import (unexpected)"
            elif echo "$import_output" | grep -i "configuration.*not.*compatible\|incompatible"; then
                echo "    [WARNING] Configuration incompatible - cluster may need recreation"
                echo "    [ADVICE] Consider destroying existing cluster and letting Terraform recreate it"
                echo "    [COMMAND] To manually fix: az aks delete --name aks-devops-eastus --resource-group $AZURE_RESOURCE_GROUP"
            else
                echo "    [ERROR] Unknown import error:"
                echo "$import_output" | head -n 5 | sed 's/^/             /'
            fi
            
            echo "    [CONTINUE] Continuing with deployment - Terraform apply will handle this"
            return 1
        }
        
        echo "    [SUCCESS] AKS cluster imported successfully"
    fi
fi

# Import AKS node pool if cluster exists
echo ""
echo "==> Attempting to import AKS Node Pool..."
if terraform state show "azurerm_kubernetes_cluster.main" >/dev/null 2>&1; then
    try_import "azurerm_kubernetes_cluster_node_pool.user" \
        "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.ContainerService/managedClusters/aks-devops-eastus/agentPools/workerpool" \
        "AKS Node Pool (workerpool)"
else
    echo "    [SKIP] AKS cluster not in state - node pool import will be handled later"
fi

echo ""
echo "✅ Import fix script completed"
echo "Note: Resources already in state or not found in Azure were skipped"

# Final check - verify critical resources are in state
echo ""
echo "🔍 Final verification of critical resources..."

critical_resources=(
    "azurerm_user_assigned_identity.aks"
    "azurerm_log_analytics_solution.container_insights[0]" 
    "azurerm_application_insights.main[0]"
    "azurerm_application_gateway.main" 
    "azurerm_kubernetes_cluster.main"
    "azurerm_kubernetes_cluster_node_pool.user"
    "azurerm_subnet_network_security_group_association.aks" 
    "azurerm_subnet_network_security_group_association.appgw"
)
missing_critical=()

for resource in "${critical_resources[@]}"; do
    if terraform state show "$resource" >/dev/null 2>&1; then
        echo "  ✅ $resource - in state"
    else
        echo "  ❌ $resource - not in state"
        missing_critical+=("$resource")
    fi
done

if [ ${#missing_critical[@]} -eq 0 ]; then
    echo ""
    echo "🎉 All critical resources are properly imported!"
    exit 0
else
    echo ""
    echo "⚠️  Some critical resources still missing from state:"
    for resource in "${missing_critical[@]}"; do
        echo "     - $resource"
    done
    echo ""
    echo "This may indicate:"
    echo "1. Resources don't exist in Azure yet"
    echo "2. Resource naming doesn't match expected pattern"
    echo "3. Permissions issue accessing the resources"
    exit 0  # Don't fail - let terraform plan handle it
fi
