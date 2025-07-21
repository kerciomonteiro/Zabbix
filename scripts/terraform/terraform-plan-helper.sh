#!/bin/bash
set -e

# Terraform Validation and Plan Helper Script
# This script handles validation, planning, and output management

echo "🔍 Validating Terraform configuration..."
if ! terraform validate; then
    echo "❌ Terraform validation failed"
    exit 1
fi
echo "✅ Terraform configuration is valid"

# Generate plan file name with timestamp
PLAN_FILE="tfplan-${GITHUB_RUN_NUMBER:-$(date +%s)}-$(date +%s)"
echo "PLAN_FILE=$PLAN_FILE" >> "$GITHUB_ENV"

# Also write to a local file for the master script to read
echo "$PLAN_FILE" > .terraform-plan-file
echo "Plan file name saved: $PLAN_FILE"

# Create plan
echo "📋 Creating Terraform plan after import..."
set +e  # Don't exit on plan errors
terraform plan -out="$PLAN_FILE" -detailed-exitcode 2>&1 | tee terraform-plan-output.txt
PLAN_EXIT_CODE=${PIPESTATUS[0]}
set -e  # Re-enable exit on error

if [ $PLAN_EXIT_CODE -eq 1 ]; then
    echo ""
    echo "❌ Terraform plan failed due to errors"
    echo ">> Plan error details:"
    echo "====================="
    cat terraform-plan-output.txt | tail -50
    echo ""
    echo "🔍 Common causes of plan failures after import:"
    echo "  - Terraform resource configuration doesn't match actual Azure resource"
    echo "  - Missing or incorrect resource dependencies"
    echo "  - Imported resource has properties not defined in Terraform"
    echo "  - Azure resource was modified outside of Terraform"
    echo ""
    echo "💡 Troubleshooting steps:"
    echo "  1. Check if resource definitions in Terraform match actual Azure resources"
    echo "  2. Verify all required properties are defined in Terraform configuration"
    echo "  3. Consider updating Terraform config to match current Azure resource state"
    echo "  4. Check for missing dependencies between resources"
    exit 1
elif [ $PLAN_EXIT_CODE -eq 2 ]; then
    echo "📋 Terraform plan created with changes to apply"
    echo "PLAN_HAS_CHANGES=true" >> "$GITHUB_ENV"
    echo ">> Plan summary (first 30 lines):"
    terraform show -no-color "$PLAN_FILE" 2>/dev/null | head -30 || echo "Could not show plan details"
else
    echo "📋 Terraform plan created with no changes"
    echo "PLAN_HAS_CHANGES=false" >> "$GITHUB_ENV"
fi

# Display plan summary
echo "📋 Terraform Plan Summary:"
terraform show -no-color "$PLAN_FILE"

# Save plan as artifact for manual review
echo "💾 Saving plan for review..."
terraform show -json "$PLAN_FILE" > terraform-plan.json
terraform show -no-color "$PLAN_FILE" > terraform-plan.txt

# Set outputs
echo "PLAN_EXIT_CODE=$PLAN_EXIT_CODE" >> "$GITHUB_OUTPUT"
echo "PLAN_FILE=$PLAN_FILE" >> "$GITHUB_OUTPUT"
