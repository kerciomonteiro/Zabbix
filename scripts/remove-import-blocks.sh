#!/bin/bash
# Script to remove import blocks from main.tf after successful deployment
# This should be run after GitHub Actions successfully imports and manages all resources

echo "🧹 Removing import blocks from main.tf after successful deployment..."

MAIN_TF_FILE="infra/terraform/main.tf"

if [ ! -f "$MAIN_TF_FILE" ]; then
    echo "❌ main.tf file not found at $MAIN_TF_FILE"
    exit 1
fi

# Create backup
cp "$MAIN_TF_FILE" "$MAIN_TF_FILE.backup"
echo "✅ Backup created: $MAIN_TF_FILE.backup"

# Remove import blocks (from first import to last closing brace before data sources)
sed -i '/^# Import blocks for existing resources/,/^# Data sources for existing resources/c\
# Import blocks removed - resources are now managed by Terraform\
\
# Data sources for existing resources' "$MAIN_TF_FILE"

echo "✅ Import blocks removed from $MAIN_TF_FILE"
echo "📝 Remember to commit and push these changes after verifying deployment works"
echo ""
echo "To verify the change:"
echo "git diff $MAIN_TF_FILE"
echo ""
echo "To commit:"
echo "git add $MAIN_TF_FILE"
echo "git commit -m 'Remove import blocks after successful deployment'"
echo "git push origin main"
