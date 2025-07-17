#!/bin/bash

# Azure Credentials JSON Generator for GitHub Actions
# This script helps you generate the correct AZURE_CREDENTIALS JSON format

echo "🔧 Azure Credentials JSON Generator for GitHub Actions"
echo "======================================================"
echo ""

echo "Please provide the following information from your Azure service principal:"
echo ""

# Get client ID
read -p "Enter Application (client) ID: " CLIENT_ID

# Get client secret
echo "Enter Client Secret (input will be hidden):"
read -s CLIENT_SECRET

# Get tenant ID
read -p "Enter Directory (tenant) ID: " TENANT_ID

# Subscription ID is fixed
SUBSCRIPTION_ID="d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"

echo ""
echo "🎯 Generated AZURE_CREDENTIALS JSON:"
echo "======================================"

# Generate the JSON
cat << EOF
{
  "clientId": "$CLIENT_ID",
  "clientSecret": "$CLIENT_SECRET",
  "subscriptionId": "$SUBSCRIPTION_ID",
  "tenantId": "$TENANT_ID"
}
EOF

echo ""
echo "📋 Instructions:"
echo "1. Copy the JSON above (including the curly braces)"
echo "2. Go to your GitHub repository"
echo "3. Navigate to Settings > Secrets and variables > Actions"
echo "4. Click 'New repository secret'"
echo "5. Name: AZURE_CREDENTIALS"
echo "6. Value: Paste the JSON above"
echo "7. Click 'Add secret'"
echo ""
echo "⚠️  Important: Make sure there are no extra spaces or line breaks in the JSON!"
