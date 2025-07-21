#!/bin/bash
# kubernetes-resource-import.sh
# Manual import script for existing Kubernetes resources to ensure idempotent CI/CD deployments

set -e

echo "🔧 Kubernetes Resource Import Script"
echo "===================================="
echo ""
echo "This script imports existing Kubernetes resources into Terraform state"
echo "to prevent 'resource already exists' errors during CI/CD deployments."
echo ""

# Set resource details
RESOURCE_GROUP="rg-devops-pops-eastus"
CLUSTER_NAME="aks-devops-eastus"

echo "📋 Target Cluster:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  AKS Cluster: $CLUSTER_NAME"
echo ""

# Get kubeconfig
echo "🔗 Step 1: Getting cluster credentials..."
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing --only-show-errors
echo "✅ Kubeconfig updated"
echo ""

# Function to import Kubernetes resource if it exists and is not in Terraform state
import_k8s_resource() {
    local resource_type=$1
    local terraform_address=$2
    local k8s_name=$3
    local description=$4
    
    echo "Checking $description..."
    
    # Check if resource exists in Kubernetes
    if kubectl get $resource_type $k8s_name >/dev/null 2>&1; then
        echo "  ✓ Found existing $resource_type: $k8s_name"
        
        # Check if it's already in Terraform state
        if ! terraform state show $terraform_address >/dev/null 2>&1; then
            echo "  📥 Importing $resource_type $k8s_name to $terraform_address"
            if terraform import $terraform_address $k8s_name; then
                echo "  ✅ Successfully imported $description"
            else
                echo "  ⚠️  Failed to import $description (may already be managed)"
            fi
        else
            echo "  ✓ $description already in Terraform state"
        fi
    else
        echo "  ✓ $description does not exist, will be created by Terraform"
    fi
    echo ""
}

echo "🔍 Step 2: Checking and importing Kubernetes resources..."
echo ""

# Import namespaces
import_k8s_resource "namespace" "kubernetes_namespace.applications[\\\"zabbix\\\"]" "zabbix" "Zabbix namespace"

# Import storage classes
import_k8s_resource "storageclass" "kubernetes_storage_class.workload_storage[\\\"fast\\\"]" "fast-ssd" "Fast SSD storage class"
import_k8s_resource "storageclass" "kubernetes_storage_class.workload_storage[\\\"standard\\\"]" "standard-ssd" "Standard SSD storage class"

# Import resource quotas (if they exist)
import_k8s_resource "resourcequota" "kubernetes_resource_quota.application_quotas[\\\"zabbix\\\"]" "zabbix/zabbix-quota" "Zabbix resource quota"

# Import network policies (if they exist)
import_k8s_resource "networkpolicy" "kubernetes_network_policy.namespace_isolation[\\\"zabbix\\\"]" "zabbix/zabbix-isolation" "Zabbix network policy"

echo "🎯 Import process completed!"
echo ""
echo "Next steps:"
echo "1. Run 'terraform plan' to verify no creation conflicts"
echo "2. Run 'terraform apply' for idempotent deployment"
echo "3. All existing resources should now be managed by Terraform"
echo ""
echo "Expected outcome:"
echo "✓ No 'resource already exists' errors"
echo "✓ Terraform manages all Kubernetes resources"
echo "✓ CI/CD deployments will be idempotent"
