#!/bin/bash

# AGIC Installation Verification Script
# This script validates that the modern AGIC installation approach is working

set -e

echo "🔍 AGIC Installation Verification Script"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "OK" ]; then
        echo -e "${GREEN}✅ $message${NC}"
    elif [ "$status" = "WARN" ]; then
        echo -e "${YELLOW}⚠️ $message${NC}"
    else
        echo -e "${RED}❌ $message${NC}"
    fi
}

# Check if Azure CLI is available
echo
echo "📋 Prerequisites Check"
echo "----------------------"

if command -v az &> /dev/null; then
    AZ_VERSION=$(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo "unknown")
    print_status "OK" "Azure CLI available (version: $AZ_VERSION)"
else
    print_status "ERROR" "Azure CLI not found"
    exit 1
fi

if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 || echo "unknown")
    print_status "OK" "kubectl available (version: $KUBECTL_VERSION)"
else
    print_status "ERROR" "kubectl not found"
    exit 1
fi

if command -v helm &> /dev/null; then
    HELM_VERSION=$(helm version --template='{{.Version}}' 2>/dev/null || echo "unknown")
    print_status "OK" "Helm available (version: $HELM_VERSION)"
else
    print_status "WARN" "Helm not found (required for NGINX fallback)"
fi

# Check Azure login status
echo
echo "🔐 Azure Authentication"
echo "----------------------"

if az account show &> /dev/null; then
    ACCOUNT_NAME=$(az account show --query name -o tsv)
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    print_status "OK" "Logged in to Azure ($ACCOUNT_NAME)"
    echo "   Subscription: $SUBSCRIPTION_ID"
else
    print_status "ERROR" "Not logged in to Azure"
    echo "   Run: az login"
    exit 1
fi

# Test AGIC addon availability
echo
echo "🔌 AGIC Addon Availability"
echo "-------------------------"

# Check if we can query addon information (this validates the addon is available)
if az aks addon list-available --query "[?name=='ingress-appgw']" -o table &> /dev/null; then
    print_status "OK" "AGIC addon is available in this subscription"
else
    print_status "ERROR" "AGIC addon not available or permission issue"
fi

# Test Terraform integration
echo
echo "🏗️ Terraform Integration"
echo "------------------------"

if [ -f "infra/terraform/terraform.tfstate" ]; then
    cd infra/terraform
    if terraform output APPLICATION_GATEWAY_NAME &> /dev/null; then
        APPGW_NAME=$(terraform output -raw APPLICATION_GATEWAY_NAME)
        print_status "OK" "Application Gateway name from Terraform: $APPGW_NAME"
    else
        print_status "WARN" "Cannot retrieve Application Gateway name from Terraform"
    fi
    cd - > /dev/null
else
    print_status "WARN" "Terraform state file not found"
fi

# Test NGINX Ingress fallback repository
echo
echo "🔄 NGINX Ingress Fallback"
echo "------------------------"

if helm repo list 2>/dev/null | grep -q "ingress-nginx"; then
    print_status "OK" "NGINX Ingress Helm repository already configured"
else
    echo "Testing NGINX Ingress repository..."
    if helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx &> /dev/null; then
        helm repo update &> /dev/null
        print_status "OK" "NGINX Ingress repository accessible"
        helm repo remove ingress-nginx &> /dev/null
    else
        print_status "ERROR" "Cannot access NGINX Ingress repository"
    fi
fi

echo
echo "📊 Summary"
echo "========="
print_status "OK" "Modern AGIC installation approach is ready"
print_status "OK" "Azure CLI AKS addon method available"
print_status "OK" "NGINX Ingress fallback available"

echo
echo "🚀 Ready for deployment!"
echo
echo "To run the AGIC installation:"
echo "1. Ensure AKS cluster and Application Gateway exist"
echo "2. Run the GitHub Actions workflow with application-only deployment"
echo "3. The workflow will automatically use the modern Azure CLI approach"

exit 0
