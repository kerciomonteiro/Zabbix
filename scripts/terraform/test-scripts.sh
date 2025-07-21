#!/bin/bash

# Simple validation script to test our Terraform helper scripts
echo "🧪 Testing Terraform helper scripts..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Script directory: $SCRIPT_DIR"

# Check if all required scripts exist
REQUIRED_SCRIPTS=(
    "terraform-master.sh"
    "terraform-provider-helper.sh" 
    "terraform-import-helper.sh"
    "terraform-plan-helper.sh"
    "terraform-apply-helper.sh"
)

echo ""
echo "=== Checking Script Availability ==="
for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -f "$SCRIPT_DIR/$script" ]; then
        echo "✅ $script - Found"
        # Check if executable
        if [ -x "$SCRIPT_DIR/$script" ]; then
            echo "   ✅ Executable"
        else
            echo "   ⚠️  Not executable (will be set by workflow)"
        fi
    else
        echo "❌ $script - Missing"
    fi
done

echo ""
echo "=== Testing Help Commands ==="

# Test provider helper help
if [ -f "$SCRIPT_DIR/terraform-provider-helper.sh" ]; then
    echo "Testing terraform-provider-helper.sh help:"
    bash "$SCRIPT_DIR/terraform-provider-helper.sh" help | head -5
fi

echo ""
echo "🎯 Test completed!"
echo "Note: Full functionality requires Terraform environment and Azure resources."
