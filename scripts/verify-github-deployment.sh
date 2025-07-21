#!/bin/bash

# GitHub Actions Deployment Verification Script
# This script verifies that your repository is ready for GitHub Actions deployment

echo "🔍 Verifying GitHub Actions Deployment Setup..."
echo "================================================="

# Check if we're in a Git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not in a Git repository"
    exit 1
fi

echo "✅ Git repository detected"

# Check if workflow file exists
WORKFLOW_FILE=".github/workflows/deploy.yml"
if [ ! -f "$WORKFLOW_FILE" ]; then
    echo "❌ GitHub Actions workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

echo "✅ GitHub Actions workflow file found"

# Check workflow configuration
echo ""
echo "📋 Workflow Configuration:"
echo "------------------------"

# Extract key configuration values
RESOURCE_GROUP=$(grep "AZURE_RESOURCE_GROUP:" "$WORKFLOW_FILE" | cut -d"'" -f2)
LOCATION=$(grep "AZURE_LOCATION:" "$WORKFLOW_FILE" | cut -d"'" -f2)
SUBSCRIPTION_ID=$(grep "AZURE_SUBSCRIPTION_ID:" "$WORKFLOW_FILE" | cut -d"'" -f2)

echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "Subscription ID: $SUBSCRIPTION_ID"

# Check if infrastructure files exist
echo ""
echo "🏗️ Infrastructure Files:"
echo "------------------------"

if [ -d "infra/terraform" ]; then
    echo "✅ Terraform infrastructure found"
    TERRAFORM_FILES=$(find infra/terraform -name "*.tf" | wc -l)
    echo "   └── Terraform files: $TERRAFORM_FILES"
else
    echo "⚠️ Terraform infrastructure not found"
fi

if [ -f "infra/main-arm.json" ]; then
    echo "✅ ARM template found"
else
    echo "⚠️ ARM template not found"
fi

# Check Kubernetes manifests
echo ""
echo "☸️ Kubernetes Manifests:"
echo "------------------------"

if [ -d "k8s" ] || [ -d "applications/zabbix/k8s" ]; then
    echo "✅ Kubernetes manifests found"
    
    # Count manifest files
    if [ -d "k8s" ]; then
        K8S_FILES=$(find k8s -name "*.yaml" -o -name "*.yml" | wc -l)
        echo "   └── k8s/ files: $K8S_FILES"
    fi
    
    if [ -d "applications/zabbix/k8s" ]; then
        ZABBIX_K8S_FILES=$(find applications/zabbix/k8s -name "*.yaml" -o -name "*.yml" | wc -l)
        echo "   └── applications/zabbix/k8s/ files: $ZABBIX_K8S_FILES"
    fi
else
    echo "❌ Kubernetes manifests not found"
    echo "   Expected: k8s/ or applications/zabbix/k8s/ directory"
fi

# Check for required secrets (can't verify actual values, just remind user)
echo ""
echo "🔐 Required GitHub Secrets:"
echo "-------------------------"
echo "⚠️ Please ensure you have configured the following secret in GitHub:"
echo "   - AZURE_CREDENTIALS (JSON format with Service Principal details)"
echo ""
echo "To set this up:"
echo "1. Go to GitHub repository → Settings → Secrets and variables → Actions"
echo "2. Add new repository secret named 'AZURE_CREDENTIALS'"
echo "3. Use the JSON output from 'az ad sp create-for-rbac --sdk-auth'"

# Check Git status
echo ""
echo "📤 Git Status:"
echo "-------------"

if [ -n "$(git status --porcelain)" ]; then
    echo "⚠️ You have uncommitted changes:"
    git status --porcelain | head -10
    echo ""
    echo "💡 Commit and push changes before running GitHub Actions workflow"
else
    echo "✅ Working tree is clean"
fi

# Check if we're on main branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: $CURRENT_BRANCH"

if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "develop" ]; then
    echo "✅ On deployment branch"
else
    echo "⚠️ Not on main/develop branch (workflow may not trigger automatically)"
fi

echo ""
echo "🚀 Deployment Instructions:"
echo "============================"
echo "1. Ensure AZURE_CREDENTIALS secret is configured in GitHub"
echo "2. Go to GitHub repository → Actions tab"
echo "3. Select 'Deploy AKS Zabbix Infrastructure (Terraform & ARM)' workflow"
echo "4. Click 'Run workflow'"
echo "5. Choose deployment options:"
echo "   - Type: 'full' for complete deployment"
echo "   - Method: 'terraform' (recommended)"
echo "   - Leave other options as default for first deployment"
echo "6. Click 'Run workflow' button"
echo ""
echo "📖 For detailed instructions, see: GITHUB-DEPLOYMENT-GUIDE.md"
echo ""
echo "✅ Repository appears ready for GitHub Actions deployment!"
