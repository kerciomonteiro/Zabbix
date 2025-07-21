#!/bin/bash
set -e

# Terraform Import Helper Script
# This script handles the complex logic of importing Azure resources into Terraform state
# It's designed to work with GitHub Actions environment variables

echo "🚀 Starting Terraform import helper script..."

# Validate required environment variables
if [[ -z "$AZURE_SUBSCRIPTION_ID" || -z "$AZURE_RESOURCE_GROUP" ]]; then
    echo "❌ Error: Required environment variables missing"
    echo "   AZURE_SUBSCRIPTION_ID: ${AZURE_SUBSCRIPTION_ID:-'Not set'}"
    echo "   AZURE_RESOURCE_GROUP: ${AZURE_RESOURCE_GROUP:-'Not set'}"
    exit 1
fi

echo "📋 Configuration:"
echo "  Subscription ID: $AZURE_SUBSCRIPTION_ID"
echo "  Resource Group: $AZURE_RESOURCE_GROUP"

# Enhanced safe import function with better error handling
safe_import() {
    local tf_resource="$1"
    local azure_id="$2"
    local display_name="$3"
    
    echo ""
    echo "==> Processing $display_name..."
    echo "    Terraform resource: $tf_resource"
    echo "    Azure resource ID: $azure_id"
    
    # Check if resource is already in Terraform state
    if terraform state show "$tf_resource" >/dev/null 2>&1; then
        echo "    [INFO] Resource already in Terraform state - verifying..."
        local current_id=""
        current_id=$(terraform state show "$tf_resource" 2>/dev/null | grep -E '^\s*id\s*=' | head -1 | sed -E 's/.*=\s*"([^"]+)".*/\1/' || echo "")
        
        if [ -n "$current_id" ] && [ "$current_id" = "$azure_id" ]; then
            echo "    [SUCCESS] $display_name already correctly imported"
            return 0
        else
            echo "    [WARNING] State exists but may point to different resource"
            echo "              Current ID in state: $current_id"
            echo "              Expected ID: $azure_id"
            echo "              Removing and re-importing..."
            terraform state rm "$tf_resource" >/dev/null 2>&1 || echo "              Note: Failed to remove from state"
        fi
    fi
    
    # Verify the Azure resource exists
    echo "    [CHECK] Verifying resource exists in Azure..."
    if ! az resource show --ids "$azure_id" >/dev/null 2>&1; then
        echo "    [ERROR] Resource not found in Azure - skipping import"
        return 1
    fi
    echo "    [SUCCESS] Resource verified in Azure"
    
    # Attempt the import
    echo "    [IMPORT] Importing $display_name into Terraform state..."
    local import_output=""
    local import_exit_code=0
    
    import_output=$(terraform import "$tf_resource" "$azure_id" 2>&1) || import_exit_code=$?
    
    if [ $import_exit_code -eq 0 ]; then
        if echo "$import_output" | grep -q "Import successful\|successfully imported\|Import prepared"; then
            echo "    [SUCCESS] Successfully imported $display_name"
            return 0
        fi
    fi
    
    echo "    [FAILED] Import failed for $display_name (exit code: $import_exit_code)"
    echo "             Error output:"
    echo "$import_output" | sed 's/^/              /' | head -10
    return 1
}

# Import resources in dependency order
echo ""
echo "📦 Starting systematic resource import in dependency order..."

imported_count=0
total_resources=13

# Track successful imports
declare -a successful_imports=()
declare -a failed_imports=()

# Core resources first
echo ""
echo "=== PHASE 1: Core Resources ==="

if safe_import "azurerm_user_assigned_identity.aks" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-devops-eastus" \
    "Managed Identity"; then
    successful_imports+=("Managed Identity")
    ((imported_count++))
else
    failed_imports+=("Managed Identity")
fi

if safe_import "azurerm_log_analytics_workspace.main[0]" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.OperationalInsights/workspaces/law-devops-eastus" \
    "Log Analytics Workspace"; then
    successful_imports+=("Log Analytics Workspace")
    ((imported_count++))
else
    failed_imports+=("Log Analytics Workspace")
fi

if safe_import "azurerm_container_registry.main" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.ContainerRegistry/registries/acrdevopseastus" \
    "Container Registry"; then
    successful_imports+=("Container Registry")
    ((imported_count++))
else
    failed_imports+=("Container Registry")
fi

echo ""
echo "=== PHASE 2: Network Infrastructure ==="

# Network resources
if safe_import "azurerm_virtual_network.main" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus" \
    "Virtual Network"; then
    successful_imports+=("Virtual Network")
    ((imported_count++))
else
    failed_imports+=("Virtual Network")
fi

if safe_import "azurerm_network_security_group.aks" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/networkSecurityGroups/nsg-aks-devops-eastus" \
    "AKS Network Security Group"; then
    successful_imports+=("AKS NSG")
    ((imported_count++))
else
    failed_imports+=("AKS NSG")
fi

if safe_import "azurerm_network_security_group.appgw" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/networkSecurityGroups/nsg-appgw-devops-eastus" \
    "App Gateway Network Security Group"; then
    successful_imports+=("App Gateway NSG")
    ((imported_count++))
else
    failed_imports+=("App Gateway NSG")
fi

if safe_import "azurerm_public_ip.appgw" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/publicIPAddresses/pip-appgw-devops-eastus" \
    "Application Gateway Public IP"; then
    successful_imports+=("App Gateway Public IP")
    ((imported_count++))
else
    failed_imports+=("App Gateway Public IP")
fi

echo ""
echo "=== PHASE 3: Subnets and Associations ==="

# Subnets (depend on VNet)
if safe_import "azurerm_subnet.aks" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus/subnets/subnet-aks-devops-eastus" \
    "AKS Subnet"; then
    successful_imports+=("AKS Subnet")
    ((imported_count++))
else
    failed_imports+=("AKS Subnet")
fi

if safe_import "azurerm_subnet.appgw" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus/subnets/subnet-appgw-devops-eastus" \
    "App Gateway Subnet"; then
    successful_imports+=("App Gateway Subnet")
    ((imported_count++))
else
    failed_imports+=("App Gateway Subnet")
fi

# NSG associations
if safe_import "azurerm_subnet_network_security_group_association.aks" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus/subnets/subnet-aks-devops-eastus" \
    "AKS NSG Association"; then
    successful_imports+=("AKS NSG Association")
    ((imported_count++))
else
    failed_imports+=("AKS NSG Association")
fi

if safe_import "azurerm_subnet_network_security_group_association.appgw" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus/subnets/subnet-appgw-devops-eastus" \
    "App Gateway NSG Association"; then
    successful_imports+=("App Gateway NSG Association")
    ((imported_count++))
else
    failed_imports+=("App Gateway NSG Association")
fi

echo ""
echo "=== PHASE 4: Complex Resources ==="

# Complex resources
if safe_import "azurerm_application_gateway.main" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/applicationGateways/appgw-devops-eastus" \
    "Application Gateway"; then
    successful_imports+=("Application Gateway")
    ((imported_count++))
else
    failed_imports+=("Application Gateway")
fi

if safe_import "azurerm_kubernetes_cluster.main" \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.ContainerService/managedClusters/aks-devops-eastus" \
    "AKS Cluster"; then
    successful_imports+=("AKS Cluster")
    ((imported_count++))
else
    failed_imports+=("AKS Cluster")
fi

echo ""
echo "=== IMPORT SUMMARY ==="
echo "📊 Import Results: $imported_count/$total_resources resources successfully imported"
echo ""

if [ ${#successful_imports[@]} -gt 0 ]; then
    echo "✅ Successful imports (${#successful_imports[@]}):"
    for import in "${successful_imports[@]}"; do
        echo "  - $import"
    done
fi

if [ ${#failed_imports[@]} -gt 0 ]; then
    echo ""
    echo "❌ Failed imports (${#failed_imports[@]}):"
    for import in "${failed_imports[@]}"; do
        echo "  - $import"
    done
fi

# Set output for GitHub Actions
echo "IMPORT_COUNT=$imported_count" >> "$GITHUB_OUTPUT"
echo "TOTAL_RESOURCES=$total_resources" >> "$GITHUB_OUTPUT"
echo "IMPORT_SUCCESS_RATE=$((imported_count * 100 / total_resources))" >> "$GITHUB_OUTPUT"

# Return success if at least AKS was imported (minimum for deployment to proceed)
if terraform state show "azurerm_kubernetes_cluster.main" >/dev/null 2>&1; then
    echo ""
    echo "✅ Critical resource (AKS Cluster) successfully imported - deployment can proceed"
    exit 0
else
    echo ""
    echo "❌ Critical resource (AKS Cluster) not imported - manual intervention required"
    exit 1
fi
