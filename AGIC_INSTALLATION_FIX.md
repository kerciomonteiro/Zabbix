# AGIC Installation Fix - Modern Azure CLI Approach

## Problem
The original deployment was failing due to attempting to use a deprecated AGIC Helm repository (`https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/`) that is no longer publicly accessible.

## Solution
Replaced the deprecated Helm-based AGIC installation with the modern Azure CLI AKS addon approach, which is the recommended method for installing Application Gateway Ingress Controller (AGIC).

## Implementation Details

### 1. Modern AGIC Installation Method
The workflow now uses the Azure CLI AKS addon to install AGIC:

```bash
# Check if AGIC addon is already enabled
AGIC_STATUS=$(az aks addon show \
  --name ${{ env.AKS_CLUSTER_NAME }} \
  --resource-group ${{ env.AZURE_RESOURCE_GROUP }} \
  --addon ingress-appgw \
  --query "enabled" \
  -o tsv 2>/dev/null || echo "false")

# Enable AGIC addon if not already enabled
az aks addon enable \
  --name ${{ env.AKS_CLUSTER_NAME }} \
  --resource-group ${{ env.AZURE_RESOURCE_GROUP }} \
  --addon ingress-appgw \
  --appgw-name $APPGW_NAME
```

### 2. Dynamic Application Gateway Name Resolution
Instead of hardcoding the Application Gateway name, the workflow now:
- Attempts to retrieve the name from Terraform outputs
- Falls back to a default name if Terraform outputs are not available

```bash
# Get Application Gateway name from Terraform outputs or use default
if [ -f "infra/terraform/terraform.tfstate" ]; then
  APPGW_NAME=$(cd infra/terraform && terraform output -raw APPLICATION_GATEWAY_NAME 2>/dev/null || echo "")
fi

if [ -z "$APPGW_NAME" ]; then
  APPGW_NAME="appgw-devops-eastus"
  echo "⚠️ Could not retrieve APPGW name from Terraform, using default: $APPGW_NAME"
else
  echo "✅ Retrieved Application Gateway name from Terraform: $APPGW_NAME"
fi
```

### 3. Robust Fallback Strategy
The installation process includes multiple fallback mechanisms:

1. **Primary**: AKS addon with Application Gateway name
2. **Secondary**: AKS addon with Application Gateway resource ID
3. **Tertiary**: NGINX Ingress Controller (using official Kubernetes Helm repository)

### 4. Idempotent Installation
The workflow now checks if AGIC is already installed before attempting installation, preventing conflicts and errors.

## Benefits of This Approach

1. **Microsoft Recommended**: Uses the officially supported Azure CLI method
2. **Integrated Management**: AGIC is managed as an AKS addon, integrated with Azure RBAC
3. **Automatic Updates**: Microsoft manages the AGIC version and updates
4. **Better Security**: Uses managed identities and integrated Azure authentication
5. **Simplified Configuration**: No need to manage Helm repositories or manual deployments

## Terraform Integration

The Terraform configuration supports this approach by:
- Creating the Application Gateway resource
- Configuring the AKS cluster with the `ingress_application_gateway` block
- Outputting the Application Gateway name and ID for use in the workflow

```hcl
# In aks.tf
ingress_application_gateway {
  gateway_id = azurerm_application_gateway.main.id
}

# In outputs.tf
output "APPLICATION_GATEWAY_NAME" {
  description = "Application Gateway name"
  value       = azurerm_application_gateway.main.name
}
```

## Troubleshooting

### AGIC Not Installing
If AGIC installation fails:
1. Check that the Application Gateway exists and is in the same resource group
2. Verify that the AKS cluster has the necessary permissions
3. Check the Azure CLI version (should be latest)
4. Review the managed identity permissions

### Fallback to NGINX
If the workflow falls back to NGINX Ingress:
1. AGIC installation failed - check Azure CLI logs
2. NGINX will be used for ingress routing instead
3. Update your ingress resources to use `nginx` as the ingress class

### Verification Commands
```bash
# Check AGIC addon status
az aks addon show --name $AKS_CLUSTER_NAME --resource-group $RESOURCE_GROUP --addon ingress-appgw

# Check AGIC pods
kubectl get pods -n kube-system -l app=ingress-appgw

# Check ingress controllers
kubectl get pods --all-namespaces | grep -E "(ingress|agic)"

# Check ingress classes
kubectl get ingressclass
```

## References
- [Azure Application Gateway Ingress Controller Documentation](https://docs.microsoft.com/en-us/azure/application-gateway/ingress-controller-overview)
- [Enable AGIC add-on for existing AKS cluster](https://docs.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-existing)
- [Azure CLI az aks addon documentation](https://docs.microsoft.com/en-us/cli/azure/aks/addon)
