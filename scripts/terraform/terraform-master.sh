#!/bin/bash
set -e

# Terraform Deployment Master Script
# This script orchestrates the complete Terraform deployment process

TERRAFORM_MODE="${1:-plan-and-apply}"
DEBUG_MODE="${2:-false}"

echo "🚀 Starting Terraform deployment orchestration..."
echo "Mode: $TERRAFORM_MODE"
echo "Debug: $DEBUG_MODE"

# Step 1: Initialize and disable provider
echo ""
echo "=== STEP 1: Terraform Initialization ==="
terraform init

# Step 2: Disable Kubernetes provider for import
echo ""
echo "=== STEP 2: Disable Kubernetes Provider ==="
../../scripts/terraform/terraform-provider-helper.sh disable

# Step 3: Import existing resources
echo ""
echo "=== STEP 3: Import Azure Resources ==="
set +e  # Don't exit on import errors initially
../../scripts/terraform/terraform-import-helper.sh
IMPORT_EXIT_CODE=$?
set -e

if [ $IMPORT_EXIT_CODE -ne 0 ]; then
    echo "⚠️ Import process encountered issues but continuing..."
    echo "IMPORT_SUCCESS=partial" >> "$GITHUB_OUTPUT"
else
    echo "✅ Import process completed successfully"
    echo "IMPORT_SUCCESS=true" >> "$GITHUB_OUTPUT"
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

# Step 6: Apply based on mode
echo ""
echo "=== STEP 6: Terraform Apply ==="
../../scripts/terraform/terraform-apply-helper.sh "$TERRAFORM_MODE" "$PLAN_FILE"

echo ""
echo "✅ Terraform deployment orchestration completed successfully!"
