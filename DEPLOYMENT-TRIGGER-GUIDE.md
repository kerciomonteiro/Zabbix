# GitHub Actions Deployment Triggers Guide

## Updated Behavior (After Latest Changes)

### ✅ **Push to `main` or `develop` now WILL deploy full infrastructure**

After the recent update, pushes that include changes to:
- `infra/**` (Terraform files)
- `k8s/**` (Kubernetes manifests) 
- `.github/workflows/**` (GitHub Actions)

Will trigger a **FULL DEPLOYMENT** by default, including:
- ✅ AKS Cluster
- ✅ Virtual Network (VNet)
- ✅ Network Security Groups (NSG)
- ✅ Application Gateway
- ✅ Container Registry
- ✅ Log Analytics Workspace
- ✅ Managed Identity
- ✅ Zabbix Application (MySQL, Server, Web UI)

## Deployment Options

### 1. Automatic Push Deployment
```bash
# Any change to infra/, k8s/, or .github/workflows/ will trigger deployment
git add .
git commit -m "Update infrastructure"
git push
```
**Result**: Full infrastructure + application deployment to `rg-devops-pops-eastus`

### 2. Manual Workflow Dispatch (More Control)
1. Go to GitHub → Actions → "Deploy AKS Zabbix Infrastructure"
2. Click "Run workflow"
3. Choose options:
   - **Deployment Type**: 
     - `full` - Complete infrastructure + application
     - `infrastructure-only` - Just Azure resources
     - `application-only` - Just Zabbix (assumes AKS exists)
     - `redeploy-clean` - Fresh deployment (destroys existing)
   - **Infrastructure Method**: `terraform` (recommended) or `arm`
   - **Reset Database**: `true` to wipe Zabbix data
   - **Debug Mode**: `true` for detailed logging

### 3. Pull Request Deployment
Pull requests to `main` also trigger deployment for testing.

## Target Environment

- **Resource Group**: `rg-devops-pops-eastus`
- **Location**: `eastus`  
- **Subscription**: `d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf`

## Prerequisites

Ensure your GitHub repository has the `AZURE_CREDENTIALS` secret configured with:
```json
{
  "clientId": "<service-principal-app-id>",
  "clientSecret": "<service-principal-password>",
  "subscriptionId": "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf",
  "tenantId": "<azure-tenant-id>"
}
```

## What Gets Created

### Infrastructure (Terraform)
- AKS cluster: `aks-devops-eastus`
- Virtual Network: `vnet-devops-eastus`
- Subnets: `subnet-aks-devops-eastus`, `subnet-appgw-devops-eastus`
- NSGs: `nsg-aks-devops-eastus`, `nsg-appgw-devops-eastus`
- Application Gateway: `appgw-devops-eastus`
- Public IP: `pip-appgw-devops-eastus`
- Container Registry: `acrzabbixdevopseastus`
- Log Analytics: `law-devops-eastus`
- Managed Identity: `id-devops-eastus`

### Application (Kubernetes)
- Namespace: `zabbix`
- MySQL database with persistent storage
- Zabbix server components
- Zabbix web interface
- NGINX Ingress Controller
- LoadBalancer services
- Network policies

## Access After Deployment

- **Zabbix Web UI**: Via LoadBalancer IP or Application Gateway
- **Default Credentials**: Admin / zabbix
- **Database**: MySQL with persistent volumes
- **Monitoring**: Integrated with Log Analytics

## Important Notes

⚠️ **This will create real Azure resources that incur costs**

🔒 **Change default passwords immediately after deployment**

📊 **Check Azure portal to monitor resource costs**

🔄 **Use `redeploy-clean` option to start fresh if needed**
