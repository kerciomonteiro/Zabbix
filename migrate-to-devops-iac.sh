#!/bin/bash

# DevOps-IAC Repository Migration Script
# This script prepares the code for migration to the new devops-iac repository

set -e

echo "🚀 DevOps-IAC Repository Migration"
echo "=================================="
echo ""

# Configuration
NEW_REPO_NAME="devops-iac"
CURRENT_REPO_URL="https://github.com/kerciomonteiro/Zabbix.git"
NEW_REPO_URL="https://github.com/kerciomonteiro/devops-iac.git"  # Update with your actual URL

echo "📋 Migration Plan:"
echo "  Source: Zabbix repository"
echo "  Target: $NEW_REPO_NAME repository"
echo "  URL: $NEW_REPO_URL"
echo ""

# Step 1: Create fresh clone
echo "🔄 Step 1: Creating fresh clone..."
if [ -d "$NEW_REPO_NAME" ]; then
    echo "⚠️  Directory $NEW_REPO_NAME already exists. Removing..."
    rm -rf "$NEW_REPO_NAME"
fi

git clone "$CURRENT_REPO_URL" "$NEW_REPO_NAME"
cd "$NEW_REPO_NAME"

echo "✅ Repository cloned successfully"
echo ""

# Step 2: Remove troubleshooting files
echo "🧹 Step 2: Removing troubleshooting documentation..."

# Remove troubleshooting .md files (these are now in .gitignore)
find . -name "TERRAFORM_*.md" -delete 2>/dev/null || true
find . -name "WORKFLOW_*.md" -delete 2>/dev/null || true
find . -name "ZABBIX-*.md" -delete 2>/dev/null || true
find . -name "NODE_POOL_*.md" -delete 2>/dev/null || true
find . -name "NGINX_*.md" -delete 2>/dev/null || true
find . -name "KUBERNETES_*.md" -delete 2>/dev/null || true
find . -name "PLATFORM-*.md" -delete 2>/dev/null || true
find . -name "REPOSITORY-*.md" -delete 2>/dev/null || true
find . -name "troubleshooting-*.md" -delete 2>/dev/null || true
find . -name "*-SUMMARY.md" -delete 2>/dev/null || true
find . -name "*-SUCCESS.md" -delete 2>/dev/null || true
find . -name "*-FIX.md" -delete 2>/dev/null || true
find . -name "*-RESOLUTION.md" -delete 2>/dev/null || true
find . -name "scripts/terraform/RECOVERY-*.md" -delete 2>/dev/null || true

# Remove other troubleshooting artifacts
rm -f debug-pod.yaml 2>/dev/null || true
rm -f zabbix-db-init-*.yaml 2>/dev/null || true

echo "✅ Troubleshooting files removed"
echo ""

# Step 3: Replace README
echo "📚 Step 3: Updating README for DevOps-IAC..."
if [ -f "README-devops-iac.md" ]; then
    mv README-devops-iac.md README.md
    echo "✅ README updated with DevOps-IAC content"
else
    echo "⚠️  README-devops-iac.md not found, keeping existing README"
fi
echo ""

# Step 4: Update remote origin
echo "🔗 Step 4: Updating git remote..."
git remote remove origin
git remote add origin "$NEW_REPO_URL"

echo "✅ Remote updated to: $NEW_REPO_URL"
echo ""

# Step 5: Clean up git history (optional)
echo "🔄 Step 5: Preparing clean commit..."

# Stage all changes
git add -A

# Commit the cleanup
git commit -m "🚀 INITIAL DEVOPS-IAC REPOSITORY

✅ CLEAN PROFESSIONAL REPOSITORY:
- Removed all troubleshooting documentation
- Updated README for DevOps-IAC focus
- Professional documentation and structure
- Production-ready Infrastructure as Code

📦 INCLUDED COMPONENTS:
- Complete Terraform infrastructure
- Kubernetes manifests for Zabbix stack
- GitHub Actions CI/CD workflows
- Automated deployment and recovery scripts
- Comprehensive documentation

🎯 READY FOR PRODUCTION:
- Enterprise-grade IaC templates
- Automated Zabbix monitoring deployment
- Professional DevOps workflows
- Complete Azure AKS solution

Repository migrated from Zabbix troubleshooting to clean DevOps-IAC"

echo "✅ Clean commit created"
echo ""

# Step 6: Instructions for pushing
echo "🎯 Step 6: Ready to push to new repository!"
echo ""
echo "📋 Next steps:"
echo "1. Create the new repository on GitHub: $NEW_REPO_URL"
echo "2. Run the following command to push:"
echo "   cd $NEW_REPO_NAME"
echo "   git push -u origin main"
echo ""
echo "3. Verify the repository looks clean and professional"
echo "4. Set up GitHub Actions secrets:"
echo "   - AZURE_CLIENT_ID"
echo "   - AZURE_CLIENT_SECRET" 
echo "   - AZURE_SUBSCRIPTION_ID"
echo "   - AZURE_TENANT_ID"
echo ""

# Summary
echo "🎉 MIGRATION SUMMARY:"
echo "=================================="
echo "✅ Fresh clone created in ./$NEW_REPO_NAME/"
echo "✅ Troubleshooting files removed"
echo "✅ Professional README installed"
echo "✅ Git remote updated"
echo "✅ Clean commit prepared"
echo ""
echo "📂 Repository structure:"
find . -type d -name ".git" -prune -o -type d -print | head -20
echo ""
echo "🚀 Ready for production DevOps environment!"
echo ""
echo "⚠️  Remember to:"
echo "  1. Create the GitHub repository first"
echo "  2. Configure GitHub Actions secrets"
echo "  3. Test the deployment workflow"
echo ""

echo "Migration script completed successfully! 🎉"
