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

# Dynamic resource discovery using Azure CLI
discover_azure_resource() {
    local resource_type="$1"
    local expected_pattern="$2"
    local display_name="$3"
    
    echo "    [DISCOVER] Finding $display_name in resource group $AZURE_RESOURCE_GROUP..."
    
    # Query Azure for resources of this type in the resource group
    local resources=""
    case "$resource_type" in
        "Microsoft.ManagedIdentity/userAssignedIdentities")
            resources=$(az identity list --resource-group "$AZURE_RESOURCE_GROUP" --query "[?contains(name, 'id-') || contains(name, 'devops')].id" -o tsv 2>/dev/null || echo "")
            ;;
        "Microsoft.OperationalInsights/workspaces") 
            resources=$(az monitor log-analytics workspace list --resource-group "$AZURE_RESOURCE_GROUP" --query "[?contains(name, 'law-') || contains(name, 'devops')].id" -o tsv 2>/dev/null || echo "")
            ;;
        "Microsoft.ContainerRegistry/registries")
            resources=$(az acr list --resource-group "$AZURE_RESOURCE_GROUP" --query "[?contains(name, 'acr') || contains(name, 'devops')].id" -o tsv 2>/dev/null || echo "")
            ;;
        "Microsoft.Network/virtualNetworks")
            resources=$(az network vnet list --resource-group "$AZURE_RESOURCE_GROUP" --query "[?contains(name, 'vnet-') || contains(name, 'devops')].id" -o tsv 2>/dev/null || echo "")
            ;;
        "Microsoft.Network/networkSecurityGroups")
            if [[ "$expected_pattern" == *"aks"* ]]; then
                resources=$(az network nsg list --resource-group "$AZURE_RESOURCE_GROUP" --query "[?contains(name, 'nsg-aks') || (contains(name, 'nsg') && contains(name, 'aks'))].id" -o tsv 2>/dev/null || echo "")
            else
                resources=$(az network nsg list --resource-group "$AZURE_RESOURCE_GROUP" --query "[?contains(name, 'nsg-appgw') || (contains(name, 'nsg') && contains(name, 'appgw'))].id" -o tsv 2>/dev/null || echo "")
            fi
            ;;
        "Microsoft.Network/publicIPAddresses")
            resources=$(az network public-ip list --resource-group "$AZURE_RESOURCE_GROUP" --query "[?contains(name, 'pip-') || contains(name, 'appgw')].id" -o tsv 2>/dev/null || echo "")
            ;;
        "Microsoft.Network/applicationGateways")
            resources=$(az network application-gateway list --resource-group "$AZURE_RESOURCE_GROUP" --query "[?contains(name, 'appgw-') || contains(name, 'devops')].id" -o tsv 2>/dev/null || echo "")
            ;;
        "Microsoft.ContainerService/managedClusters")
            resources=$(az aks list --resource-group "$AZURE_RESOURCE_GROUP" --query "[?contains(name, 'aks-') || contains(name, 'devops')].id" -o tsv 2>/dev/null || echo "")
            ;;
        "Microsoft.Insights/components")
            resources=$(az monitor app-insights component show --resource-group "$AZURE_RESOURCE_GROUP" --app ai-devops-eastus --query "id" -o tsv 2>/dev/null || echo "")
            ;;
        "subnet")
            # Special case for subnets
            local vnet_name=""
            if [[ "$expected_pattern" == *"aks"* ]]; then
                vnet_name=$(az network vnet list --resource-group "$AZURE_RESOURCE_GROUP" --query "[0].name" -o tsv 2>/dev/null || echo "")
                if [ -n "$vnet_name" ]; then
                    resources=$(az network vnet subnet list --resource-group "$AZURE_RESOURCE_GROUP" --vnet-name "$vnet_name" --query "[?contains(name, 'aks')].id" -o tsv 2>/dev/null || echo "")
                fi
            else
                vnet_name=$(az network vnet list --resource-group "$AZURE_RESOURCE_GROUP" --query "[0].name" -o tsv 2>/dev/null || echo "")
                if [ -n "$vnet_name" ]; then
                    resources=$(az network vnet subnet list --resource-group "$AZURE_RESOURCE_GROUP" --vnet-name "$vnet_name" --query "[?contains(name, 'appgw')].id" -o tsv 2>/dev/null || echo "")
                fi
            fi
            ;;
        *)
            echo "      [WARN] Unknown resource type for discovery: $resource_type"
            return 1
            ;;
    esac
    
    if [ -n "$resources" ]; then
        # Return the first matching resource (assume single resource per type in RG)
        echo "$resources" | head -n 1
        return 0
    else
        echo "      [WARN] No matching resources found for $display_name"
        return 1
    fi
}

# Enhanced safe import function with Azure discovery
safe_import() {
    local tf_resource="$1"
    local azure_id_override="$2"
    local display_name="$3"
    
    local azure_id="$azure_id_override"
    
    # If no override provided, try discovery based on Terraform resource type
    if [ -z "$azure_id" ]; then
        case "$tf_resource" in
            "azurerm_user_assigned_identity.aks")
                azure_id=$(discover_azure_resource "Microsoft.ManagedIdentity/userAssignedIdentities" "id-devops" "$display_name")
                ;;
            "azurerm_log_analytics_workspace.main[0]")
                azure_id=$(discover_azure_resource "Microsoft.OperationalInsights/workspaces" "law-devops" "$display_name")
                ;;
            "azurerm_container_registry.main")
                azure_id=$(discover_azure_resource "Microsoft.ContainerRegistry/registries" "acrdevops" "$display_name")
                ;;
            "azurerm_virtual_network.main")
                azure_id=$(discover_azure_resource "Microsoft.Network/virtualNetworks" "vnet-devops" "$display_name")
                ;;
            "azurerm_network_security_group.aks")
                azure_id=$(discover_azure_resource "Microsoft.Network/networkSecurityGroups" "nsg-aks-devops" "$display_name")
                ;;
            "azurerm_network_security_group.appgw")
                azure_id=$(discover_azure_resource "Microsoft.Network/networkSecurityGroups" "nsg-appgw-devops" "$display_name")
                ;;
            "azurerm_public_ip.appgw")
                azure_id=$(discover_azure_resource "Microsoft.Network/publicIPAddresses" "pip-appgw-devops" "$display_name")
                ;;
            "azurerm_application_gateway.main")
                azure_id=$(discover_azure_resource "Microsoft.Network/applicationGateways" "appgw-devops" "$display_name")
                ;;
            "azurerm_kubernetes_cluster.main")
                azure_id=$(discover_azure_resource "Microsoft.ContainerService/managedClusters" "aks-devops" "$display_name")
                ;;
            "azurerm_subnet.aks")
                azure_id=$(discover_azure_resource "subnet" "aks" "$display_name")
                ;;
            "azurerm_subnet.appgw")
                azure_id=$(discover_azure_resource "subnet" "appgw" "$display_name")
                ;;
            "azurerm_subnet_network_security_group_association.aks"|"azurerm_subnet_network_security_group_association.appgw")
                # For NSG associations, we need the subnet ID
                local subnet_type="aks"
                if [[ "$tf_resource" == *"appgw"* ]]; then
                    subnet_type="appgw"
                fi
                azure_id=$(discover_azure_resource "subnet" "$subnet_type" "$display_name (subnet)")
                ;;
            "azurerm_application_insights.main[0]")
                azure_id=$(discover_azure_resource "Microsoft.Insights/components" "ai-devops" "$display_name")
                ;;
            "azurerm_log_analytics_solution.container_insights[0]")
                # Container Insights solution has a specific naming pattern
                azure_id="/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.OperationsManagement/solutions/ContainerInsights(law-devops-eastus)"
                ;;
            *)
                echo "    [WARN] No discovery logic for resource type: $tf_resource"
                ;;
        esac
    fi
    
    if [ -z "$azure_id" ]; then
        echo "    [ERROR] Could not determine resource ID for $display_name - skipping import"
        return 1
    fi
    
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

# Detect actual resource names from environment or fallback to defaults
detect_resource_names() {
    local env_name="${ENVIRONMENT_NAME:-zabbix-devops-eastus}"
    local location="${LOCATION:-eastus}"
    
    # Extract base environment pattern (e.g., "devops-eastus" from "zabbix-devops-eastus")
    local base_pattern="devops-${location}"
    
    echo "🔍 Detecting resource names..."
    echo "  Environment: $env_name"
    echo "  Location: $location"
    echo "  Base pattern: $base_pattern"
}

# Import resources in dependency order
echo ""
echo "📦 Starting systematic resource import in dependency order..."

detect_resource_names

imported_count=0
total_resources=15

# Track successful imports
declare -a successful_imports=()
declare -a failed_imports=()

# Core resources first
echo ""
echo "=== PHASE 1: Core Resources ==="

if safe_import "azurerm_user_assigned_identity.aks" \
    "" \
    "Managed Identity"; then
    successful_imports+=("Managed Identity")
    ((imported_count++))
else
    failed_imports+=("Managed Identity")
fi

if safe_import "azurerm_log_analytics_workspace.main[0]" \
    "" \
    "Log Analytics Workspace"; then
    successful_imports+=("Log Analytics Workspace")
    ((imported_count++))
else
    failed_imports+=("Log Analytics Workspace")
fi

# Log Analytics Solution (Container Insights)
if safe_import "azurerm_log_analytics_solution.container_insights[0]" \
    "" \
    "Container Insights Solution"; then
    successful_imports+=("Container Insights Solution")
    ((imported_count++))
else
    failed_imports+=("Container Insights Solution")
fi

# Application Insights
if safe_import "azurerm_application_insights.main[0]" \
    "" \
    "Application Insights"; then
    successful_imports+=("Application Insights")
    ((imported_count++))
else
    failed_imports+=("Application Insights")
fi

if safe_import "azurerm_container_registry.main" \
    "" \
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
    "" \
    "Virtual Network"; then
    successful_imports+=("Virtual Network")
    ((imported_count++))
else
    failed_imports+=("Virtual Network")
fi

if safe_import "azurerm_network_security_group.aks" \
    "" \
    "AKS Network Security Group"; then
    successful_imports+=("AKS NSG")
    ((imported_count++))
else
    failed_imports+=("AKS NSG")
fi

if safe_import "azurerm_network_security_group.appgw" \
    "" \
    "App Gateway Network Security Group"; then
    successful_imports+=("App Gateway NSG")
    ((imported_count++))
else
    failed_imports+=("App Gateway NSG")
fi

if safe_import "azurerm_public_ip.appgw" \
    "" \
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
    "" \
    "AKS Subnet"; then
    successful_imports+=("AKS Subnet")
    ((imported_count++))
else
    failed_imports+=("AKS Subnet")
fi

if safe_import "azurerm_subnet.appgw" \
    "" \
    "App Gateway Subnet"; then
    successful_imports+=("App Gateway Subnet")
    ((imported_count++))
else
    failed_imports+=("App Gateway Subnet")
fi

# NSG associations
if safe_import "azurerm_subnet_network_security_group_association.aks" \
    "" \
    "AKS NSG Association"; then
    successful_imports+=("AKS NSG Association")
    ((imported_count++))
else
    failed_imports+=("AKS NSG Association")
fi

if safe_import "azurerm_subnet_network_security_group_association.appgw" \
    "" \
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
    "" \
    "Application Gateway"; then
    successful_imports+=("Application Gateway")
    ((imported_count++))
else
    failed_imports+=("Application Gateway")
fi

if safe_import "azurerm_kubernetes_cluster.main" \
    "" \
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
