#!/bin/bash
# Local Bicep template testing and validation script
# This script helps test the Bicep template locally before deployment

set -euo pipefail

# Configuration
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-Devops-Test}"
LOCATION="${AZURE_LOCATION:-eastus}"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf}"
ENVIRONMENT_NAME="${ENVIRONMENT_NAME:-zabbix-aks-local-test}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_section() {
    echo -e "\n${BLUE}==== $1 ====${NC}"
}

# Check prerequisites
check_prerequisites() {
    log_section "Checking Prerequisites"
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    log_success "Azure CLI is installed"
    
    # Check if Bicep is available
    if ! az bicep version &> /dev/null; then
        log_warning "Bicep is not installed. Installing..."
        az bicep install
    fi
    log_success "Bicep is available"
    
    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        log_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    log_success "Logged in to Azure"
    
    # Set subscription
    log_info "Setting subscription to: $SUBSCRIPTION_ID"
    az account set --subscription "$SUBSCRIPTION_ID"
    
    # Verify subscription
    CURRENT_SUB=$(az account show --query id -o tsv)
    if [ "$CURRENT_SUB" != "$SUBSCRIPTION_ID" ]; then
        log_error "Failed to set subscription. Current: $CURRENT_SUB, Expected: $SUBSCRIPTION_ID"
        exit 1
    fi
    log_success "Subscription set correctly"
}

# Validate Bicep template syntax
validate_template_syntax() {
    log_section "Validating Bicep Template Syntax"
    
    TEMPLATE_PATH="$(dirname "$0")/../infra/main.bicep"
    
    if [ ! -f "$TEMPLATE_PATH" ]; then
        log_error "Bicep template not found at: $TEMPLATE_PATH"
        exit 1
    fi
    
    log_info "Validating template: $TEMPLATE_PATH"
    
    # Build template to check syntax
    if az bicep build --file "$TEMPLATE_PATH" --stdout > /dev/null; then
        log_success "Template syntax is valid"
    else
        log_error "Template has syntax errors"
        exit 1
    fi
    
    # Show template info
    log_info "Template information:"
    az bicep build --file "$TEMPLATE_PATH" --stdout | jq -r '.metadata // {}'
}

# Check resource group access
check_resource_group() {
    log_section "Checking Resource Group Access"
    
    log_info "Checking access to resource group: $RESOURCE_GROUP"
    
    if az group show --name "$RESOURCE_GROUP" --output table > /dev/null; then
        log_success "Resource group access confirmed"
        
        # Show resource group details
        az group show --name "$RESOURCE_GROUP" --output table
    else
        log_error "Cannot access resource group: $RESOURCE_GROUP"
        log_info "Available resource groups:"
        az group list --output table
        exit 1
    fi
}

# Check resource providers
check_resource_providers() {
    log_section "Checking Resource Provider Registration"
    
    REQUIRED_PROVIDERS=(
        "Microsoft.ContainerService"
        "Microsoft.Network"
        "Microsoft.ContainerRegistry"
        "Microsoft.ManagedIdentity"
        "Microsoft.OperationalInsights"
    )
    
    for provider in "${REQUIRED_PROVIDERS[@]}"; do
        log_info "Checking provider: $provider"
        STATUS=$(az provider show --namespace "$provider" --query registrationState -o tsv)
        
        if [ "$STATUS" = "Registered" ]; then
            log_success "$provider is registered"
        else
            log_warning "$provider is not registered (Status: $STATUS)"
            log_info "Registering provider: $provider"
            az provider register --namespace "$provider" --wait
            log_success "$provider registered successfully"
        fi
    done
}

# Check for naming conflicts
check_naming_conflicts() {
    log_section "Checking for Naming Conflicts"
    
    # Generate resource token same way as Bicep template
    RESOURCE_TOKEN=$(echo -n "${SUBSCRIPTION_ID}${RESOURCE_GROUP}${ENVIRONMENT_NAME}" | sha256sum | cut -c1-8)
    
    log_info "Environment name: $ENVIRONMENT_NAME"
    log_info "Resource token: $RESOURCE_TOKEN"
    
    # Check ACR name availability
    ACR_NAME="acr${ENVIRONMENT_NAME//-/}${RESOURCE_TOKEN}"
    log_info "Checking ACR name availability: $ACR_NAME"
    
    ACR_AVAILABLE=$(az acr check-name --name "$ACR_NAME" --query nameAvailable -o tsv)
    if [ "$ACR_AVAILABLE" = "true" ]; then
        log_success "ACR name is available"
    else
        log_warning "ACR name may not be available"
        REASON=$(az acr check-name --name "$ACR_NAME" --query reason -o tsv)
        log_info "Reason: $REASON"
    fi
}

# Run what-if analysis
run_whatif_analysis() {
    log_section "Running What-If Analysis"
    
    TEMPLATE_PATH="$(dirname "$0")/../infra/main.bicep"
    DEPLOYMENT_NAME="zabbix-whatif-$(date +%s)"
    
    log_info "Running what-if analysis for deployment: $DEPLOYMENT_NAME"
    log_info "Parameters:"
    log_info "  Environment Name: $ENVIRONMENT_NAME"
    log_info "  Location: $LOCATION"
    
    if az deployment group what-if \
        --resource-group "$RESOURCE_GROUP" \
        --template-file "$TEMPLATE_PATH" \
        --parameters environmentName="$ENVIRONMENT_NAME" \
                     location="$LOCATION" \
        --name "$DEPLOYMENT_NAME"; then
        log_success "What-if analysis completed successfully"
    else
        log_error "What-if analysis failed"
        exit 1
    fi
}

# Validate deployment
validate_deployment() {
    log_section "Validating Deployment"
    
    TEMPLATE_PATH="$(dirname "$0")/../infra/main.bicep"
    
    log_info "Validating deployment parameters and template"
    
    if az deployment group validate \
        --resource-group "$RESOURCE_GROUP" \
        --template-file "$TEMPLATE_PATH" \
        --parameters environmentName="$ENVIRONMENT_NAME" \
                     location="$LOCATION"; then
        log_success "Deployment validation passed"
    else
        log_error "Deployment validation failed"
        exit 1
    fi
}

# Check quotas
check_quotas() {
    log_section "Checking Azure Quotas"
    
    log_info "Checking compute quotas in region: $LOCATION"
    
    # Check VM quotas
    log_info "VM Family quotas:"
    az vm list-usage --location "$LOCATION" --output table | grep -E "(Standard_D|Standard_B)" | head -10
    
    # Check AKS specific quotas
    log_info "Checking AKS service availability in region: $LOCATION"
    if az provider show --namespace Microsoft.ContainerService --query "resourceTypes[?resourceType=='managedClusters'].locations[]" -o tsv | grep -i "$LOCATION" > /dev/null; then
        log_success "AKS is available in $LOCATION"
    else
        log_warning "AKS may not be available in $LOCATION"
    fi
}

# Show estimated costs
show_estimated_costs() {
    log_section "Estimated Costs"
    
    log_info "Estimated monthly costs for this deployment:"
    echo "  - AKS Cluster (Standard_B2s nodes): ~\$50-100/month"
    echo "  - Container Registry (Basic): ~\$5/month"
    echo "  - Log Analytics Workspace: ~\$10-30/month"
    echo "  - Virtual Network: Free"
    echo "  - Application Gateway: ~\$20-50/month"
    echo "  Total estimated: ~\$85-185/month"
    echo ""
    log_warning "Actual costs may vary based on usage and region"
}

# Main execution
main() {
    echo -e "${CYAN}"
    echo "=========================================="
    echo "  Zabbix AKS Bicep Template Validator"
    echo "=========================================="
    echo -e "${NC}"
    
    echo "Configuration:"
    echo "  Resource Group: $RESOURCE_GROUP"
    echo "  Location: $LOCATION"
    echo "  Subscription: $SUBSCRIPTION_ID"
    echo "  Environment Name: $ENVIRONMENT_NAME"
    echo ""
    
    # Run all checks
    check_prerequisites
    validate_template_syntax
    check_resource_group
    check_resource_providers
    check_naming_conflicts
    check_quotas
    run_whatif_analysis
    validate_deployment
    show_estimated_costs
    
    log_section "Validation Complete"
    log_success "All validations passed! The template is ready for deployment."
    echo ""
    log_info "To deploy manually, run:"
    echo "  az deployment group create \\"
    echo "    --resource-group '$RESOURCE_GROUP' \\"
    echo "    --template-file 'infra/main.bicep' \\"
    echo "    --parameters environmentName='$ENVIRONMENT_NAME' location='$LOCATION'"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo ""
        echo "Environment variables:"
        echo "  AZURE_RESOURCE_GROUP    Resource group name (default: Devops-Test)"
        echo "  AZURE_LOCATION          Azure region (default: eastus)"
        echo "  AZURE_SUBSCRIPTION_ID   Subscription ID"
        echo "  ENVIRONMENT_NAME        Environment name (default: zabbix-aks-local-test)"
        echo ""
        echo "Options:"
        echo "  --help, -h              Show this help message"
        echo "  --syntax-only           Only validate template syntax"
        echo "  --whatif-only           Only run what-if analysis"
        exit 0
        ;;
    --syntax-only)
        check_prerequisites
        validate_template_syntax
        exit 0
        ;;
    --whatif-only)
        check_prerequisites
        validate_template_syntax
        check_resource_group
        run_whatif_analysis
        exit 0
        ;;
    *)
        main
        ;;
esac
