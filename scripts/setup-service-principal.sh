#!/bin/bash

# Azure Service Principal Setup Script for GitHub Actions
# This script creates a service principal for GitHub Actions deployment

set -e

# Configuration
SUBSCRIPTION_ID="d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"
RESOURCE_GROUP="Devops-Test"
SP_NAME="github-actions-zabbix-deployment"

echo "🚀 Setting up Azure Service Principal for GitHub Actions"
echo "=================================================="

# Check if user is logged in
echo "📋 Checking Azure CLI login status..."
if ! az account show &> /dev/null; then
    echo "❌ Not logged into Azure CLI. Please run 'az login' first."
    exit 1
fi

# Set subscription
echo "📋 Setting Azure subscription..."
az account set --subscription "$SUBSCRIPTION_ID"
echo "✅ Using subscription: $(az account show --query name -o tsv)"

# Verify resource group exists
echo "🔍 Verifying resource group exists..."
if ! az group exists --name "$RESOURCE_GROUP" --output tsv; then
    echo "❌ Resource group '$RESOURCE_GROUP' does not exist."
    echo "   Please create it first or update the RESOURCE_GROUP variable."
    exit 1
fi
echo "✅ Resource group '$RESOURCE_GROUP' exists"

# Create service principal
echo "👤 Creating service principal..."
echo "   Name: $SP_NAME"
echo "   Scope: /subscriptions/$SUBSCRIPTION_ID"

SP_JSON=$(az ad sp create-for-rbac \
  --name "$SP_NAME" \
  --role "Contributor" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID" \
  --sdk-auth)

echo ""
echo "✅ Service Principal created successfully!"
echo ""
echo "=================================================="
echo "🔑 GITHUB SECRET CONFIGURATION"
echo "=================================================="
echo ""
echo "1. Go to your GitHub repository"
echo "2. Navigate to: Settings → Secrets and variables → Actions"
echo "3. Click 'New repository secret'"
echo "4. Name: AZURE_CREDENTIALS"
echo "5. Value: Copy the JSON below (including the curly braces)"
echo ""
echo "--- COPY THIS JSON (START) ---"
echo "$SP_JSON"
echo "--- COPY THIS JSON (END) ---"
echo ""
echo "=================================================="
echo "⚠️  IMPORTANT SECURITY NOTES"
echo "=================================================="
echo ""
echo "1. The JSON above contains sensitive credentials"
echo "2. Do NOT commit this to your repository"
echo "3. Only store it in GitHub Secrets"
echo "4. Consider rotating the secret periodically"
echo ""
echo "=================================================="
echo "🎉 Setup Complete!"
echo "=================================================="
echo ""
echo "Next steps:"
echo "1. Add the JSON as AZURE_CREDENTIALS secret in GitHub"
echo "2. Commit your code to the repository"
echo "3. Push to main branch to trigger deployment"
echo ""
echo "For detailed instructions, see: docs/github-deployment-guide.md"
