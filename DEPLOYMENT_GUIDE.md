# Zabbix AKS Deployment Guide

## Overview
This repository contains infrastructure-as-code and Kubernetes manifests to deploy Zabbix monitoring system on Azure Kubernetes Service (AKS) with Application Gateway integration.

## Quick Start

### Prerequisites
1. Azure CLI or Azure PowerShell
2. kubectl 
3. Helm 3.x
4. Terraform (for infrastructure deployments)
5. GitHub Personal Access Token (for automated deployments)

### Environment
- **Resource Group**: `rg-devops-pops-eastus`
- **Location**: `eastus`
- **AKS Cluster**: `aks-devops-eastus`
- **Container Registry**: `acrdevopseastus`

## Deployment Options

### 1. Using GitHub Actions (Recommended)

#### Manual Workflow Trigger
1. Go to GitHub Actions → Deploy AKS Zabbix Infrastructure
2. Click "Run workflow"
3. Select your options:
   - **Deployment Type**: What to deploy
   - **Infrastructure Method**: How to deploy infrastructure
   - **Terraform Mode**: How to handle Terraform
   - **Reset Database**: ⚠️ Destroys data
   - **Debug Mode**: Enable detailed logging

#### Using PowerShell Helper Script
```powershell
# Plan infrastructure changes only (for review)
.\scripts\deploy-helper.ps1 -DeploymentType infrastructure-only -TerraformMode plan-only

# Apply infrastructure after review
.\scripts\deploy-helper.ps1 -DeploymentType infrastructure-only -TerraformMode apply-existing-plan

# Full deployment (infra + app)
.\scripts\deploy-helper.ps1 -DeploymentType full -TerraformMode plan-and-apply

# Application only (use existing AKS)
.\scripts\deploy-helper.ps1 -DeploymentType application-only

# Clean redeploy with database reset
.\scripts\deploy-helper.ps1 -DeploymentType redeploy-clean -ResetDatabase
```

### 2. Local Deployment

#### Deploy Infrastructure
```bash
cd infra/terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

#### Deploy Application
```bash
# Get AKS credentials
az aks get-credentials --resource-group rg-devops-pops-eastus --name aks-devops-eastus

# Deploy Zabbix
kubectl apply -f k8s/zabbix-config.yaml
kubectl apply -f k8s/zabbix-mysql.yaml
kubectl apply -f k8s/zabbix-additional.yaml
kubectl apply -f k8s/zabbix-server.yaml
kubectl apply -f k8s/zabbix-web.yaml
kubectl apply -f k8s/zabbix-ingress.yaml
```

## Deployment Types Explained

### `full`
- Deploys infrastructure (AKS, networking, etc.)
- Deploys Zabbix application
- Sets up ingress and networking

### `infrastructure-only`
- Only deploys Azure infrastructure
- Creates AKS cluster, VNet, Application Gateway
- No application deployment

### `application-only` 
- Assumes AKS cluster exists
- Only deploys Zabbix application components
- Configures ingress and services

### `redeploy-clean`
- Clean slate deployment
- Removes existing Zabbix resources
- Redeploys everything fresh

## Terraform Modes

### `plan-only`
- Creates Terraform plan for review
- **Does not apply changes**
- Saves plan as GitHub Actions artifact
- Use for reviewing infrastructure changes

### `plan-and-apply`
- Creates plan and applies immediately
- Default behavior for automated deployments
- Best for trusted changes

### `apply-existing-plan`
- Applies a previously created plan
- Use after reviewing plan from `plan-only`
- Ensures no configuration drift

## Manual Review Workflow

1. **Create Plan**:
   ```powershell
   .\scripts\deploy-helper.ps1 -DeploymentType infrastructure-only -TerraformMode plan-only
   ```

2. **Review in GitHub Actions**:
   - Check the workflow run
   - Download terraform-plan artifacts
   - Review terraform-plan.txt

3. **Apply if Approved**:
   ```powershell  
   .\scripts\deploy-helper.ps1 -DeploymentType infrastructure-only -TerraformMode apply-existing-plan
   ```

## Accessing Zabbix

### Default Credentials
- **Username**: `Admin`
- **Password**: `zabbix`

### URLs
- **LoadBalancer IP**: Check `kubectl get svc -n zabbix`
- **Application Gateway**: Configure DNS for `dal2-devmon-mgt.forescout.com`

### Services
```bash
# Check all Zabbix services
kubectl get all -n zabbix

# Check ingress
kubectl get ingress -n zabbix

# Check service endpoints
kubectl get svc -n zabbix zabbix-web-external
```

## Troubleshooting

### Check Deployment Status
```bash
kubectl get pods -n zabbix
kubectl logs -n zabbix deployment/zabbix-server
kubectl logs -n zabbix deployment/zabbix-web
```

### Database Issues
```bash
# Check MySQL
kubectl exec -n zabbix deployment/zabbix-mysql -- mysql -u root -pZabbixRoot123! -e "SHOW DATABASES;"

# Check Zabbix schema
kubectl exec -n zabbix deployment/zabbix-mysql -- mysql -u root -pZabbixRoot123! -e "USE zabbix; SHOW TABLES;"
```

### Ingress Issues
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl get pods -n agic

# Check Application Gateway
az network application-gateway show --name appgw-devops-eastus --resource-group rg-devops-pops-eastus
```

## Security Notes

### Immediate Actions Required
1. **Change Zabbix admin password** from default `zabbix`
2. **Update database passwords** in production
3. **Configure SSL certificate** for HTTPS
4. **Restrict network access** via NSG rules

### Database Passwords
- MySQL root: `ZabbixRoot123!`
- Zabbix DB user: `zabbix123!`

**⚠️ Change these in production!**

## File Structure
```
├── .github/workflows/
│   └── deploy.yml              # GitHub Actions workflow
├── infra/
│   ├── terraform/              # Terraform infrastructure code
│   ├── main-arm.json          # ARM template (fallback)
│   └── main.bicep             # Bicep template
├── k8s/                       # Kubernetes manifests
│   ├── zabbix-config.yaml     # Namespace and config
│   ├── zabbix-mysql.yaml      # MySQL database
│   ├── zabbix-server.yaml     # Zabbix server
│   ├── zabbix-web.yaml        # Web interface
│   └── zabbix-ingress.yaml    # Ingress configuration
└── scripts/
    └── deploy-helper.ps1       # PowerShell deployment helper
```

## Environment Variables

The workflow uses these environment variables:
- `AZURE_RESOURCE_GROUP`: Target resource group
- `AZURE_LOCATION`: Azure region
- `AKS_CLUSTER_NAME`: AKS cluster name
- `CONTAINER_REGISTRY_NAME`: ACR name

## GitHub Secrets Required

- `AZURE_CREDENTIALS`: Service principal JSON for Azure authentication

```json
{
  "clientId": "...",
  "clientSecret": "...", 
  "subscriptionId": "...",
  "tenantId": "..."
}
```
