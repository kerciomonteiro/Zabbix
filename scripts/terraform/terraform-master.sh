#!/bin/bash
set -e

# Terraform Deployment Master Script
# This script orchestrates the complete Terraform deployment process

TERRAFORM_MODE="${1:-plan-and-apply}"
DEBUG_MODE="${2:-false}"

echo "🚀 Starting Terraform deployment orchestration..."
echo "Mode: $TERRAFORM_MODE"
echo "Debug: $DEBUG_MODE"

# Validate required environment variables for import process
if [[ -z "$AZURE_SUBSCRIPTION_ID" || -z "$AZURE_RESOURCE_GROUP" ]]; then
    echo "❌ Error: Required environment variables for import missing"
    echo "   AZURE_SUBSCRIPTION_ID: ${AZURE_SUBSCRIPTION_ID:-'Not set'}"
    echo "   AZURE_RESOURCE_GROUP: ${AZURE_RESOURCE_GROUP:-'Not set'}"
    echo ""
    echo "ℹ️  These variables are needed for resource import functionality"
    echo "   Continuing without import capability..."
    SKIP_IMPORT="true"
else
    echo "✅ Environment variables validated for import process"
    SKIP_IMPORT="false"
fi

# Step 1: Initialize and disable provider
echo ""
echo "=== STEP 1: Terraform Initialization ==="
terraform init

# Step 2: Disable Kubernetes provider for import
echo ""
echo "=== STEP 2: Disable Kubernetes Provider ==="
../../scripts/terraform/terraform-provider-helper.sh disable

# Step 3: Import existing resources (Critical Step)
echo ""
echo "=== STEP 3: Import Azure Resources ==="

if [ "$SKIP_IMPORT" = "true" ]; then
    echo "⚠️ Skipping import due to missing environment variables"
    echo "IMPORT_SUCCESS=skipped" >> "$GITHUB_OUTPUT"
else
    # First attempt - try standard import
    set +e  # Don't exit on import errors initially
    ../../scripts/terraform/terraform-import-helper.sh
    IMPORT_EXIT_CODE=$?
    set -e

    # Enhanced import handling - retry critical resources if import failed
    if [ $IMPORT_EXIT_CODE -ne 0 ]; then
        echo "⚠️ Initial import process failed - attempting targeted recovery..."
        
        # List of critical resources that must be imported to avoid conflicts
        declare -a critical_resources=(
            "azurerm_log_analytics_workspace.main[0]|/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.OperationalInsights/workspaces/law-devops-eastus|Log Analytics Workspace"
            "azurerm_container_registry.main|/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.ContainerRegistry/registries/acrdevopseastus|Container Registry"  
            "azurerm_network_security_group.aks|/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/networkSecurityGroups/nsg-aks-devops-eastus|AKS NSG"
            "azurerm_network_security_group.appgw|/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/networkSecurityGroups/nsg-appgw-devops-eastus|App Gateway NSG"
            "azurerm_virtual_network.main|/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/vnet-devops-eastus|Virtual Network"
            "azurerm_public_ip.appgw|/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/publicIPAddresses/pip-appgw-devops-eastus|Public IP"
        )
        
        echo "🔄 Attempting targeted import of critical resources..."
        for resource_info in "${critical_resources[@]}"; do
            IFS='|' read -r tf_resource azure_id display_name <<< "$resource_info"
            
            # Check if resource exists and needs import
            if ! terraform state show "$tf_resource" >/dev/null 2>&1; then
                if az resource show --ids "$azure_id" >/dev/null 2>&1; then
                    echo "⚡ Importing critical resource: $display_name"
                    set +e
                    terraform import "$tf_resource" "$azure_id" 2>/dev/null
                    if [ $? -eq 0 ]; then
                        echo "  ✅ Successfully imported $display_name"
                    else
                        echo "  ❌ Failed to import $display_name - will attempt plan anyway"
                    fi
                    set -e
                fi
            else
                echo "  ✅ $display_name already in state"
            fi
        done
        
        echo "IMPORT_SUCCESS=partial" >> "$GITHUB_OUTPUT"
    else
        echo "✅ Import process completed successfully"
        echo "IMPORT_SUCCESS=true" >> "$GITHUB_OUTPUT"
    fi
fi

# Step 4: Re-enable Kubernetes provider
echo ""
echo "=== STEP 4: Enable Kubernetes Provider ==="
if terraform state show "azurerm_kubernetes_cluster.main" >/dev/null 2>&1; then
    echo "✅ AKS cluster found in state - enabling Kubernetes provider"
    ../../scripts/terraform/terraform-provider-helper.sh enable
else
    echo "⚠️ AKS cluster not found in state - keeping Kubernetes provider disabled"
fi

# Step 5: Validate and create plan
echo ""
echo "=== STEP 5: Terraform Planning ==="
../../scripts/terraform/terraform-plan-helper.sh

# Capture the plan file name - try multiple methods
PLAN_FILE=""
# Method 1: Check if there's a plan file info written by the plan helper
if [ -f ".terraform-plan-file" ]; then
    PLAN_FILE=$(cat .terraform-plan-file)
    echo "Found plan file from info file: $PLAN_FILE"
elif [ -n "${GITHUB_ENV:-}" ] && [ -f "$GITHUB_ENV" ]; then
    # Method 2: Try to get from GitHub environment file
    PLAN_FILE=$(grep 'PLAN_FILE=' "$GITHUB_ENV" 2>/dev/null | cut -d'=' -f2 | tail -1)
    echo "Found plan file from GitHub ENV: $PLAN_FILE"
else
    # Method 3: Fallback - find the most recent plan file
    PLAN_FILE=$(ls -t tfplan-* 2>/dev/null | head -n 1 || echo "")
    echo "Found plan file from directory listing: $PLAN_FILE"
fi

echo "Using plan file: $PLAN_FILE"

# Step 6: Apply based on mode
echo ""
echo "=== STEP 6: Terraform Apply ==="
../../scripts/terraform/terraform-apply-helper.sh "$TERRAFORM_MODE" "$PLAN_FILE"

echo ""
echo "✅ Terraform deployment orchestration completed successfully!"

# Cleanup temporary files
rm -f .terraform-plan-file 2>/dev/null || true
