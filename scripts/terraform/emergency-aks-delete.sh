#!/bin/bash
set -e

# Emergency AKS Cluster Deletion Script
# This script deletes the failed AKS cluster to allow Terraform to create a new one
# 
# ⚠️  WARNING: Cluster deletion should be a LAST RESORT!
# 
# 🛡️  PREVENTION IS BETTER THAN CURE:
# Most Zabbix deployment issues can be prevented by:
# 1. Adding the GitHub Actions workflow step (see ./scripts/terraform/github-actions-zabbix-fix.yml)
# 2. Running post-deployment fix scripts automatically
# 3. Using the comprehensive fix scripts we've developed
#
# 🔧 BEFORE RUNNING THIS SCRIPT, TRY:
# • ./scripts/terraform/post-deployment-zabbix-fix.sh (fixes 90%+ of issues)
# • ./scripts/terraform/resolve-k8s-conflicts.sh (fixes Terraform import issues)
# • Check: kubectl get pods -n zabbix (verify what's actually failing)
#
# 📚 DOCUMENTATION: ./scripts/terraform/README-zabbix-fix.md
# 🆘 RECOVERY GUIDE: ./scripts/terraform/RECOVERY-GUIDE.md

echo "🚨 Emergency AKS Cluster Deletion"
echo "=================================="
echo ""
echo "⚠️  WARNING: This script will DELETE the existing AKS cluster!"
echo "⚠️  This action is IRREVERSIBLE and will cause downtime."
echo "⚠️  Only run this if the cluster is in a failed state and cannot be recovered."
echo ""
echo "🤔 DID YOU TRY THE FIX SCRIPTS FIRST?"
echo "   Most Zabbix issues are fixable without cluster deletion!"
echo "   • Missing Zabbix web frontend: Fixed by post-deployment script"
echo "   • Database schema issues: Fixed by post-deployment script"
echo "   • Application Gateway misconfig: Fixed by post-deployment script"
echo "   • Terraform import conflicts: Fixed by resolve-k8s-conflicts script"
echo ""
echo "   📖 FULL RECOVERY GUIDE: ./scripts/terraform/RECOVERY-GUIDE.md"
echo "   🔧 QUICK FIX: ./scripts/terraform/post-deployment-zabbix-fix.sh"
echo ""
echo "Continue only if you've tried the recovery options and they failed."
echo ""

# Set the resource details
SUBSCRIPTION_ID="d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"
RESOURCE_GROUP="rg-devops-pops-eastus"
AKS_CLUSTER_NAME="aks-devops-eastus"

echo "📋 Target Cluster:"
echo "  Subscription: $SUBSCRIPTION_ID"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  AKS Cluster: $AKS_CLUSTER_NAME"
echo ""

# Check if cluster exists and get its state
echo "🔍 Step 1: Checking cluster status..."
if ! az aks show --name "$AKS_CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "✅ Cluster does not exist - no deletion needed"
    echo "   Terraform can proceed with creating a new cluster"
    exit 0
fi

# Get cluster details
CLUSTER_INFO=$(az aks show --name "$AKS_CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --output json 2>/dev/null)
CLUSTER_STATE=$(echo "$CLUSTER_INFO" | jq -r '.provisioningState // "unknown"')
CLUSTER_POWER_STATE=$(echo "$CLUSTER_INFO" | jq -r '.powerState.code // "unknown"')

echo "📊 Cluster Details:"
echo "  Provisioning State: $CLUSTER_STATE"
echo "  Power State: $CLUSTER_POWER_STATE"
echo ""

# Check if cluster is in a failed state
if [ "$CLUSTER_STATE" = "Failed" ]; then
    echo "🚨 CONFIRMED: Cluster is in FAILED state"
    echo "   This cluster cannot be recovered and must be deleted"
    echo ""
elif [ "$CLUSTER_STATE" = "Succeeded" ]; then
    echo "⚠️  WARNING: Cluster appears to be in SUCCEEDED state"
    echo "   This cluster may be recoverable without deletion!"
    echo ""
    echo "🔧 BEFORE DELETING - Try these recovery options:"
    echo "   1. Run the Zabbix fix script first:"
    echo "      ./scripts/terraform/post-deployment-zabbix-fix.sh"
    echo ""
    echo "   2. Check for common Zabbix deployment issues:"
    echo "      • Missing Zabbix web frontend (most common)"
    echo "      • Uninitialized database schema"
    echo "      • Misconfigured Application Gateway backends"
    echo "      • Network policy blocking connectivity"
    echo ""
    echo "   3. Verify Terraform import issues:"
    echo "      • Run: ./scripts/terraform/resolve-k8s-conflicts.sh"
    echo "      • Update Terraform configuration to match existing cluster"
    echo "      • Use terraform import instead of recreating resources"
    echo ""
    echo "   4. Check for configuration drift:"
    echo "      • Terraform may be trying to modify existing working resources"
    echo "      • Consider updating terraform/*.tf files to match current state"
    echo ""
    echo "   5. Only delete if absolutely necessary (complete infrastructure failure)"
    echo ""
    echo "💡 Often, Zabbix deployment issues can be fixed without cluster deletion!"
    echo "   The fix scripts resolve 90%+ of common deployment problems."
    echo ""
    read -p "   Type 'DELETE_WORKING_CLUSTER' to confirm deletion of working cluster: " confirm
    if [ "$confirm" != "DELETE_WORKING_CLUSTER" ]; then
        echo "❌ Deletion cancelled by user"
        echo ""
        echo "🔧 Recommended next steps:"
        echo "   1. Try: ./scripts/terraform/post-deployment-zabbix-fix.sh"
        echo "   2. Check: kubectl get pods -n zabbix"
        echo "   3. Review: ./scripts/terraform/README-zabbix-fix.md"
        exit 1
    fi
else
    echo "⚠️  Cluster state is: $CLUSTER_STATE"
    echo "   This may indicate the cluster is in transition or another state"
    echo ""
fi

# Confirm deletion
echo "🚨 FINAL CONFIRMATION REQUIRED"
echo ""
echo "This will:"
echo "  ✓ Delete the AKS cluster: $AKS_CLUSTER_NAME"
echo "  ✓ Delete the node resource group: rg-aks-nodes-devops-eastus"
echo "  ✓ Delete all cluster nodes, load balancers, and associated resources"
echo "  ✓ Allow Terraform to create a fresh, working cluster"
echo ""
echo "This will NOT affect:"
echo "  ✓ Main resource group: $RESOURCE_GROUP"  
echo "  ✓ Virtual network, subnets, NSGs"
echo "  ✓ Application Gateway"
echo "  ✓ User-assigned managed identity"
echo "  ✓ Log Analytics, Application Insights"
echo "  ✓ Container Registry"
echo ""

read -p "Type 'DELETE_CLUSTER_NOW' to proceed with deletion: " final_confirm
if [ "$final_confirm" != "DELETE_CLUSTER_NOW" ]; then
    echo "❌ Deletion cancelled by user"
    exit 1
fi

echo ""
echo "🗑️  Step 2: Deleting AKS cluster..."
echo "   This may take 5-10 minutes..."

# Delete the cluster
echo "   Running: az aks delete --name $AKS_CLUSTER_NAME --resource-group $RESOURCE_GROUP --yes"
if az aks delete --name "$AKS_CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --yes; then
    echo ""
    echo "✅ SUCCESS: AKS cluster deleted successfully!"
    echo ""
    echo "🎯 CRITICAL NEXT STEPS - PREVENTING FUTURE ZABBIX ISSUES:"
    echo "================================================================"
    echo ""
    echo "🚀 STEP 1: Re-run the GitHub Actions deployment"
    echo "   - Trigger the workflow via GitHub Actions UI or push to main"
    echo "   - Terraform will create a new, properly configured AKS cluster"
    echo "   - All imported K8s resources are preserved and will be applied"
    echo ""
    echo "🔧 STEP 2: Automated Zabbix Fix (HIGHLY RECOMMENDED)"
    echo "   Add this step to your .github/workflows/deploy.yml after terraform apply:"
    echo "   ---"
    echo "   - name: Verify and Fix Zabbix Deployment"
    echo "     if: success()"
    echo "     run: |"
    echo "       az aks get-credentials --resource-group rg-devops-pops-eastus --name aks-devops-eastus --overwrite-existing"
    echo "       sleep 30  # Wait for cluster stability"
    echo "       chmod +x ./scripts/terraform/post-deployment-zabbix-fix.sh"
    echo "       ./scripts/terraform/post-deployment-zabbix-fix.sh"
    echo "     shell: bash"
    echo "   ---"
    echo "   See: ./scripts/terraform/github-actions-zabbix-fix.yml for complete config"
    echo ""
    echo "🛠️  STEP 3: Manual Fix (if automation not added yet)"
    echo "   After cluster recreation, run one of these fix scripts:"
    echo "   • Bash/Linux: ./scripts/terraform/post-deployment-zabbix-fix.sh"
    echo "   • PowerShell: ./scripts/terraform/post-deployment-zabbix-fix.ps1"
    echo ""
    echo "📋 What the fix scripts will do:"
    echo "   ✓ Deploy missing Zabbix web frontend (most common issue)"
    echo "   ✓ Initialize Zabbix database schema (166+ tables)"
    echo "   ✓ Configure Application Gateway with correct backend IPs/ports"
    echo "   ✓ Ensure all health checks pass"
    echo "   ✓ Verify complete Zabbix stack is operational"
    echo ""
    echo "🎯 Expected successful deployment outcome:"
    echo "   ✓ New AKS cluster created with correct configuration"
    echo "   ✓ Managed identity and role assignments working"
    echo "   ✓ All network and gateway resources properly connected"
    echo "   ✓ MySQL database running with initialized schema"
    echo "   ✓ Zabbix server connected to database"
    echo "   ✓ Zabbix web frontend deployed and accessible"
    echo "   ✓ Application Gateway routing traffic correctly"
    echo "   ✓ All components healthy and operational"
    echo ""
    echo "🌐 Final URL: http://dal2-devmon-mgt-devops.eastus.cloudapp.azure.com/"
    echo "🔑 Default login: Admin / zabbix (CHANGE IMMEDIATELY!)"
else
    deletion_exit_code=$?
    echo ""
    echo "❌ Failed to delete AKS cluster (exit code: $deletion_exit_code)"
    echo ""
    echo "🔍 Possible causes:"
    echo "   1. Permissions issue - ensure you have Contributor access"
    echo "   2. Cluster is locked or has delete protection"
    echo "   3. Azure service issue - try again in a few minutes"
    echo "   4. Cluster resources are in use by other services"
    echo ""
    echo "🔧 Manual recovery alternatives:"
    echo "   1. Try deletion via Azure Portal:"
    echo "      https://portal.azure.com -> AKS -> $AKS_CLUSTER_NAME -> Delete"
    echo ""
    echo "   2. Use Azure PowerShell:"
    echo "      Remove-AzAksCluster -ResourceGroupName $RESOURCE_GROUP -Name $AKS_CLUSTER_NAME"
    echo ""
    echo "   3. Force delete with Azure CLI:"
    echo "      az aks delete --name $AKS_CLUSTER_NAME --resource-group $RESOURCE_GROUP --yes --no-wait"
    echo ""
    echo "   4. Check for resource locks:"
    echo "      az lock list --resource-group $RESOURCE_GROUP"
    echo "      az lock delete --name [lock-name] --resource-group $RESOURCE_GROUP"
    echo ""
    echo "   5. Contact Azure support if cluster is stuck in transition state"
    echo ""
    echo "💡 Alternative: Skip deletion and fix existing cluster"
    echo "   Instead of deleting, try running the fix script:"
    echo "   ./scripts/terraform/post-deployment-zabbix-fix.sh"
    echo ""
    echo "📚 Documentation:"
    echo "   • Fix scripts: ./scripts/terraform/README-zabbix-fix.md"
    echo "   • Troubleshooting: Check kubectl/az CLI connectivity first"
    echo ""
    exit $deletion_exit_code
fi
