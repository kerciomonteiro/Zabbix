#  Zabbix Server on Azure Kubernetes Service (AKS)

> **⚠️ Status: AKS CLUSTER IMPORT CONFLICT - ENHANCED TROUBLESHOOTING DEPLOYED** - Comprehensive import fix and diagnostics applied

**Latest Update**: Enhanced AKS cluster import error handling with detailed diagnostics and recovery options  
**Access URL**: http://dal2-devmon-mgt-devops.eastus.cloudapp.azure.com  
**Credentials**: Admin / zabbix

> **📋 Current Issue**: AKS cluster exists in Azure but needs to be imported into Terraform state  
> **📋 Root Cause**: Resource exists from previous deployment but not in current Terraform state  
> **📋 Solution Applied**: Enhanced import script with diagnostics, troubleshooting tools, and recovery options  
> **📋 Status**: Enhanced fix deployed - monitoring GitHub Actions for automated resolution  
> **📋 Details**: See [AKS Cluster Import Issues](#aks-cluster-import-issues-️) section below

This repository contains the Infrastructure as Code (IaC) and Kubernetes manifests to deploy a complete Zabbix monitoring solution on Azure Kubernetes Service (AKS) with the following components:r on Azure Kubernetes Service (AKS)

> **� Status: MANAGED IDENTITY CREDENTIAL ISSUE - ACTIVELY RESOLVING** - Enhanced dependency management and propagation delay applied

**Latest Update**: Applied comprehensive fix for managed identity credential reconciliation failure  
**Access URL**: http://dal2-devmon-mgt-devops.eastus.cloudapp.azure.com  
**Credentials**: Admin / zabbix

> **📋 Current Issue**: AKS cluster creation fails due to managed identity credential reconciliation error  
> **📋 Root Cause**: Timing issue between identity creation/role assignments and AKS cluster usage  
> **📋 Solution### AKS Cluster Import Issues ⚡

**Status**: **ACTIVELY RESOLVING** - Enhanced import diagnostics and automated resolution applied

**Latest Issue**: AKS cluster import conflict during Terraform deployment:
```
Error: A resource with the ID "...managedClusters/aks-devops-eastus" already exists - to be managed via Terraform this resource needs to be imported into the State.
```

**Root Cause**: The AKS cluster `aks-devops-eastus` exists in Azure but is not in the current Terraform state, causing conflicts when Terraform attempts to create it.

**Solutions Applied**:
- **Enhanced Import Script**: Updated `terraform-import-fix.sh` with detailed AKS cluster diagnostics
- **Dedicated Troubleshooting Tool**: New `aks-import-troubleshoot.sh` script for step-by-step analysis
- **Configuration Compatibility Checks**: Detects if existing cluster matches Terraform configuration
- **Multiple Resolution Paths**: Automated import, manual troubleshooting, or cluster recreation options

**Resource Group Clarification**:
- **Main Resource Group**: `rg-devops-pops-eastus` (contains all infrastructure, used by Terraform)
- **AKS Node Resource Group**: `rg-aks-nodes-devops-eastus` (automatically created by Azure for AKS infrastructure - this is expected)

See comprehensive analysis and recovery options:
- **[AKS_CLUSTER_IMPORT_FIX.md](AKS_CLUSTER_IMPORT_FIX.md)** - Detailed analysis, resolution options, and troubleshooting
- **[scripts/terraform/aks-import-troubleshoot.sh](scripts/terraform/aks-import-troubleshoot.sh)** - Dedicated AKS import troubleshooting script

**Resolution Options**:
1. **Automated**: Enhanced import script runs automatically in GitHub Actions
2. **Manual Troubleshooting**: Use dedicated AKS troubleshooting script for detailed analysis
3. **Configuration Update**: Adjust Terraform to match existing cluster if needed
4. **Cluster Recreation**: Delete and recreate if configuration drift is too significant (causes downtime)

### Managed Identity Issues �

**Status**: **ACTIVELY RESOLVING** - Comprehensive fix applied for credential reconciliation failureplied**: Enhanced dependencies, 60-second propagation delay, comprehensive recovery tools  
> **📋 Status**: Fix deployed - monitoring GitHub Actions for resolution  
> **📋 Details**: See [MANAGED_IDENTITY_FIX.md](MANAGED_IDENTITY_FIX.md) and [DEPLOYMENT_STATUS_UPDATE.md](DEPLOYMENT_STATUS_UPDATE.md)

This repository contains the Infrastructure as Code (IaC) and Kubernetes manifests to deploy a complete Zabbix monitoring solution on Azure Kubernetes Service (AKS) with the following components:

- **AKS Cluster** with system and worker node pools ✅
- **Zabbix Server** with MySQL database backend ✅
- **Zabbix Web Interface** with NGINX ✅
- **Application Gateway** for external access with SSL termination ✅
- **AGIC (Application Gateway Ingress Controller)** properly configured ✅
- **LoadBalancer Services** with HTTP health checks ✅
- **Network Policies** allowing required traffic ✅

## 🔧 Infrastructure Deployment Methods

This deployment supports **multiple infrastructure deployment methods** for maximum flexibility:

1. **Terraform** (Recommended) - Modern IaC with advanced state management
2. **ARM Templates** - Native Azure resource management with fallback support
3. **Both** - Try Terraform first, fallback to ARM templates if needed

The GitHub Actions workflow automatically handles method selection and fallback logic.

## 🏗️ Architecture Overview

```
Internet
    │
    ▼
┌─────────────────┐
│ Application     │
│ Gateway         │ ← SSL Termination & External IP
│ (Azure)         │
└─────────────────┘
    │
    ▼ 
┌─────────────────┐
│ AKS Cluster     │
│                 │
│ ┌─────────────┐ │
│ │ Zabbix Web  │ │ ← HTTP Service
│ │ (NGINX)     │ │
│ └─────────────┘ │
│        │        │
│        ▼        │
│ ┌─────────────┐ │
│ │ Zabbix      │ │ ← Monitoring Server
│ │ Server      │ │
│ └─────────────┘ │
│        │        │
│        ▼        │
│ ┌─────────────┐ │
│ │ MySQL       │ │ ← Database
│ │ Database    │ │
│ └─────────────┘ │
└─────────────────┘
```

## 📋 Resource Naming Convention

This deployment follows a standardized DevOps naming convention for all Azure resources:

**Pattern**: `resourcename-devops-regionname`

### Example Resource Names (East US region):
- AKS Cluster: `aks-devops-eastus`
- Virtual Network: `vnet-devops-eastus`
- Application Gateway: `appgw-devops-eastus`
- Container Registry: `acr{envname}devopseastus`
- Log Analytics Workspace: `law-devops-eastus`
- Public IP: `pip-appgw-devops-eastus`
- Network Security Groups: `nsg-aks-devops-eastus`, `nsg-appgw-devops-eastus`

### Benefits:
- **Consistency**: All resources follow the same pattern
- **Readability**: Easy to identify resource type, purpose, and region
- **Organization**: Clear grouping by environment and location
- **Scalability**: Simple to extend to multiple regions/environments

### Environment Naming:
The GitHub Actions workflow creates environments with the pattern:
`zabbix-devops-{region}-{run-number}[-suffix]`

Example: `zabbix-devops-eastus-123` or `zabbix-devops-eastus-123-staging`

## 🚀 Quick Start

### Prerequisites

1. **Azure CLI** installed and configured
2. **GitHub** repository with secrets configured  
3. **Domain name** configured (dal2-devmon-mgt.forescout.com)
4. **SSL Certificate** for HTTPS (optional but recommended)

### Required GitHub Secrets

Configure the following secrets in your GitHub repository:

```bash
AZURE_CREDENTIALS  # Azure Service Principal JSON
```

The `AZURE_CREDENTIALS` should be in the following format:
```json
{
  "clientId": "your-client-id",
  "clientSecret": "your-client-secret", 
  "subscriptionId": "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf",
  "tenantId": "your-tenant-id"
}
```

### Deployment

1. **Fork this repository** to your GitHub account

2. **Configure the workflow** in `.github/workflows/deploy.yml`:
   - Update the resource group name if needed
   - Modify the Azure location if required

3. **Choose deployment method** via GitHub Actions workflow inputs:
   - **Infrastructure Method**: `terraform` (recommended), `arm`, or `both`
   - **Deployment Type**: `full`, `infrastructure-only`, `application-only`, or `redeploy-clean`

4. **Push to main branch** or manually trigger the workflow:
   ```bash
   git push origin main
   ```

5. **Monitor the deployment** in GitHub Actions

6. **Configure DNS** once deployment completes:
   - Point `dal2-devmon-mgt.forescout.com` to the Application Gateway IP

## 🔧 Manual Deployment

If you prefer to deploy manually:

### Option 1: Terraform Deployment

```bash
# Clone the repository
git clone <your-repo-url>
cd Zabbix

# Navigate to Terraform directory
cd infra/terraform

# Initialize Terraform
terraform init

# Create terraform.tfvars file (see terraform.tfvars.example)
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Plan deployment
terraform plan

# Deploy infrastructure
terraform apply
```

### Option 2: ARM Template Deployment

```bash
# Clone the repository
git clone <your-repo-url>
cd Zabbix

# Deploy using Azure CLI
az deployment group create \
  --resource-group Devops-Test \
  --template-file infra/main-arm.json \
  --parameters environmentName="zabbix-devops-eastus-manual" \
               location="eastus"
```

### Deploy Zabbix Application

```bash
# Get AKS credentials (replace with your cluster name)
az aks get-credentials \
  --resource-group Devops-Test \
  --name aks-devops-eastus

# Deploy Zabbix components
kubectl apply -f applications/zabbix/k8s/zabbix-config.yaml
kubectl apply -f applications/zabbix/k8s/zabbix-mysql.yaml
kubectl apply -f applications/zabbix/k8s/zabbix-additional.yaml
kubectl apply -f applications/zabbix/k8s/zabbix-server.yaml
kubectl apply -f applications/zabbix/k8s/zabbix-web.yaml
kubectl apply -f applications/zabbix/k8s/zabbix-ingress.yaml

# Wait for deployment
kubectl wait --for=condition=available deployment --all -n zabbix --timeout=600s
```

## 🔐 Security Configuration

### Default Credentials

**⚠️ Change these immediately after deployment!**

- **Zabbix Web Interface**: Admin / zabbix
- **MySQL Root**: ZabbixRoot123!
- **MySQL Zabbix User**: zabbix123!

### SSL Certificate Setup

See [SSL Configuration Guide](docs/ssl-configuration.md) for detailed instructions on:
- Azure Key Vault certificate configuration
- Let's Encrypt automatic certificates
- Manual certificate deployment

### Security Hardening

1. **Change default passwords**:
   ```bash
   # Update Zabbix admin password via web interface
   # Update database passwords in secrets
   kubectl patch secret zabbix-db-secret -n zabbix --type merge -p '{"data":{"mysql-password":"<new-base64-password>"}}'
   ```

2. **Configure network security groups**:
   - Restrict SSH access to specific IP ranges
   - Limit database access to AKS subnet only

3. **Enable Azure Policy** for compliance scanning

## 📊 Monitoring and Maintenance

### Health Checks

```bash
# Check all components
kubectl get all -n zabbix

# Check specific deployments
kubectl get pods -n zabbix -w

# View logs
kubectl logs -n zabbix deployment/zabbix-server
kubectl logs -n zabbix deployment/zabbix-web
```

### Scaling

```bash
# Scale Zabbix Web frontend
kubectl scale deployment zabbix-web -n zabbix --replicas=3

# Scale AKS worker nodes
az aks nodepool scale \
  --resource-group Devops-Test \
  --cluster-name aks-devops-eastus \
  --name workerpool \
  --node-count 5
```

### Backup

```bash
# Backup MySQL database
kubectl exec -n zabbix deployment/zabbix-mysql -- mysqldump -u root -pZabbixRoot123! zabbix > zabbix-backup-$(date +%Y%m%d).sql

# Backup Zabbix configuration
kubectl get configmap -n zabbix zabbix-config -o yaml > zabbix-config-backup.yaml
```

## 🌐 Access URLs

After successful deployment:

- **Zabbix Web Interface**: https://dal2-devmon-mgt.forescout.com
- **LoadBalancer IP**: Check with `kubectl get svc -n zabbix zabbix-web-external`

## 📁 Project Structure

```
├── .github/workflows/
│   └── deploy.yml              # GitHub Actions CI/CD pipeline
├── infra/
│   ├── terraform/              # Terraform configuration (recommended)
│   │   ├── main.tf            # Main infrastructure configuration
│   │   ├── variables.tf       # Variable definitions
│   │   ├── network.tf         # Network resources
│   │   ├── aks.tf            # AKS cluster configuration
│   │   ├── identity.tf       # Managed identities
│   │   ├── monitoring.tf     # Log Analytics and monitoring
│   │   ├── appgateway.tf     # Application Gateway
│   │   ├── outputs.tf        # Output values
│   │   ├── terraform.tfvars.example  # Example variables file
│   │   └── README.md         # Terraform-specific documentation
│   └── main-arm.json         # ARM template (fallback)
├── applications/
│   └── zabbix/
│       └── k8s/                # Zabbix Kubernetes manifests  
│           ├── zabbix-config.yaml   # Namespace and configuration
│           ├── zabbix-mysql.yaml    # MySQL database
│           ├── zabbix-server.yaml   # Zabbix server
│           ├── zabbix-web.yaml      # Web interface
│           ├── zabbix-ingress.yaml  # Ingress configuration
│           └── zabbix-additional.yaml # Java Gateway and Proxy
├── scripts/
│   ├── deploy-infrastructure-pwsh.ps1  # PowerShell deployment script
│   └── verify-deployment-readiness.ps1 # Validation script
├── docs/
│   ├── ssl-configuration.md   # SSL setup guide
│   ├── deployment-guide.md    # Detailed deployment guide
│   ├── manual-service-principal-setup.md  # Service principal setup
│   └── terraform-migration-complete.md    # Migration documentation
└── README.md                  # This file
```

## 🛠️ Customization

### Resource Sizing

Modify the resource requests and limits in the Kubernetes manifests:

```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi" 
    cpu: "1000m"
```

### Database Configuration

Update MySQL configuration in `applications/zabbix/k8s/zabbix-mysql.yaml`:

```yaml
args:
- "--innodb-buffer-pool-size=2G"
- "--max-connections=500"
- "--character-set-server=utf8"
```

### Zabbix Server Parameters

Modify Zabbix server configuration in `applications/zabbix/k8s/zabbix-config.yaml`:

```yaml
data:
  zabbix_server.conf: |
    StartPollers=10
    StartTrappers=10
    CacheSize=32M
    # ... other configurations
```

## 🔄 CI/CD Pipeline

The GitHub Actions workflow includes:

1. **Infrastructure Deployment** - Provisions AKS and supporting resources using Terraform or ARM templates
2. **Application Deployment** - Deploys Zabbix components to Kubernetes
3. **Security Configuration** - Applies security settings
4. **Health Verification** - Validates deployment success

### Infrastructure Methods

- **Terraform** (Recommended): Modern IaC with state management, plan/apply workflow
- **ARM Templates**: Native Azure deployment with JSON templates
- **Both**: Intelligent fallback - tries Terraform first, falls back to ARM if needed

### Workflow Triggers

- Push to `main` branch
- Pull requests to `main`
- Manual workflow dispatch

## 🔄 GitHub Actions Deployment Options

This repository includes a comprehensive GitHub Actions workflow (`deploy.yml`) that supports multiple deployment scenarios and infrastructure methods:

### Infrastructure Method Selection

1. **Terraform** (Recommended)
   - Modern Infrastructure as Code with state management
   - Advanced planning and validation capabilities
   - Better error handling and rollback support

2. **ARM Templates**
   - Native Azure Resource Manager templates
   - Fast deployment for simple scenarios
   - Reliable fallback option

3. **Both** (Smart Fallback)
   - Attempts Terraform deployment first
   - Automatically falls back to ARM templates if Terraform fails
   - Best of both worlds for maximum reliability

### Deployment Types

1. **Full Deployment** (Default)
   - Deploys both infrastructure and Zabbix application
   - Use for initial deployment or complete refresh

2. **Infrastructure Only**
   - Deploys only the AKS cluster and Azure resources
   - Use when you want to set up infrastructure first

3. **Application Only**
   - Deploys only Zabbix to existing AKS cluster
   - Use for application updates or when infrastructure already exists

4. **Clean Redeploy**
   - Performs complete cleanup and fresh deployment
   - Use when you need to start completely fresh

### Workflow Options

You can customize your deployment by using **GitHub Actions → Run workflow** with these options:

- **Infrastructure Method**: Choose from `terraform` (recommended), `arm`, or `both`
- **Deployment Type**: Choose from full, infrastructure-only, application-only, or redeploy-clean
- **Force PowerShell**: Use Azure PowerShell instead of Azure CLI (fallback option)
- **Reset Database**: ⚠️ **WARNING**: Destroys all Zabbix data and creates fresh database
- **Environment Suffix**: Add custom suffix to resource names (optional)
- **Debug Mode**: Enable detailed logging for troubleshooting

### How to Redeploy

#### Quick Application Update
1. Go to **Actions** tab in GitHub
2. Select **Deploy AKS Zabbix Infrastructure** workflow
3. Click **Run workflow**
4. Select **Deployment type**: `application-only`
5. Click **Run workflow**

#### Complete Clean Redeploy
1. Go to **Actions** tab in GitHub
2. Select **Deploy AKS Zabbix Infrastructure** workflow
3. Click **Run workflow**
4. Select **Deployment type**: `redeploy-clean`
5. ⚠️ Enable **Reset Database** if you want fresh data (destroys existing data)
6. Click **Run workflow**

#### Infrastructure Only Update
1. Go to **Actions** tab in GitHub
2. Select **Deploy AKS Zabbix Infrastructure** workflow
3. Click **Run workflow**
4. Select **Deployment type**: `infrastructure-only`
5. Click **Run workflow**

### Fallback Options

The workflow includes multiple fallback mechanisms:
- **Terraform** → **ARM Templates** → **PowerShell** deployment methods
- Built-in retry logic for network issues
- Automatic session reset for "content consumed" errors
- Smart cleanup that preserves data by default

## 🛠️ Troubleshooting and Testing

### Infrastructure Validation

**Terraform:**
```bash
# Navigate to Terraform directory
cd infra/terraform

# Validate configuration
terraform validate

# Check formatting
terraform fmt -check

# Plan deployment (dry run)
terraform plan
```

**ARM Template:**
```bash
# Validate ARM template
az deployment group validate \
  --resource-group Devops-Test \
  --template-file infra/main-arm.json \
  --parameters environmentName="test-validation"
```

# Run what-if analysis only
./scripts/test-template-local.sh --whatif-only
```

### Common Issues and Solutions

#### "Content Already Consumed" Error
This Azure CLI error is addressed with multiple fallback strategies:

1. **Azure CLI with retry logic** (primary fallback)
2. **Azure PowerShell** (final fallback)
3. **Enhanced error handling** with cache clearing

See [`docs/azure-cli-troubleshooting.md`](docs/azure-cli-troubleshooting.md) for detailed troubleshooting.

#### Authentication Issues
- Verify `AZURE_CREDENTIALS` secret format
- Check service principal permissions
- Ensure subscription ID is correct

#### Resource Naming Conflicts
- The template uses resource tokens for unique naming
- Check Azure Container Registry name availability
- Use different environment names if conflicts occur

#### Deployment Validation Failures
- Run template validation locally first
- Check resource provider registration
- Verify quota availability in target region

### Manual Fallback Deployment

If automated deployment fails, use the PowerShell script:

```powershell
# Install Azure PowerShell
Install-Module -Name Az -Force

# Run deployment
./scripts/deploy-infrastructure-pwsh.ps1 -ResourceGroupName "Devops-Test" -Location "eastus" -EnvironmentName "zabbix-aks-manual" -SubscriptionId "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"
```

### Monitoring Deployment

The workflow includes comprehensive monitoring:
- Pre-deployment diagnostics
- Resource provider checks
- Naming conflict detection
- Template validation
- Deployment retry logic
- Multiple fallback methods

## 🆘 Troubleshooting

### Common Issues

1. **Pod not starting**: Check resource constraints and node capacity
   ```bash
   kubectl describe pod <pod-name> -n zabbix
   kubectl top nodes
   ```

2. **Database connection issues**: Verify MySQL is running and credentials are correct
   ```bash
   kubectl logs -n zabbix deployment/zabbix-mysql
   kubectl exec -n zabbix deployment/zabbix-mysql -- mysql -u zabbix -pzabbix123! -e "SHOW DATABASES;"
   ```

3. **Ingress not working**: Check Application Gateway and DNS configuration
   ```bash
   kubectl get ingress -n zabbix
   nslookup dal2-devmon-mgt.forescout.com
   ```

### Support Commands

```bash
# Get cluster info
kubectl cluster-info

# Check node status
kubectl get nodes -o wide

# View events
kubectl get events -n zabbix --sort-by='.lastTimestamp'

# Port forward for local testing
kubectl port-forward -n zabbix svc/zabbix-web 8080:80
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the deployment
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## � Troubleshooting

### Recent Issue Resolution: 502 Bad Gateway ✅

**Status**: **RESOLVED** - Zabbix is now fully operational

The deployment experienced and successfully resolved a 502 Bad Gateway issue. The complete troubleshooting process and solution are documented in:

- **[502-BAD-GATEWAY-RESOLUTION.md](502-BAD-GATEWAY-RESOLUTION.md)** - Complete step-by-step troubleshooting
- **[FINAL-ROOT-CAUSE-ANALYSIS.md](FINAL-ROOT-CAUSE-ANALYSIS.md)** - Detailed root cause analysis
- **[applications/zabbix/k8s/TROUBLESHOOTING-SUMMARY.md](applications/zabbix/k8s/TROUBLESHOOTING-SUMMARY.md)** - Quick reference

### AGIC Installation Issues ✅

**Status**: **RESOLVED** - Modern Azure CLI approach implemented

The workflow now uses the modern Azure CLI AKS addon method for installing Application Gateway Ingress Controller (AGIC) instead of the deprecated Helm repository. See:

- **[AGIC_INSTALLATION_FIX.md](AGIC_INSTALLATION_FIX.md)** - Complete AGIC installation fix documentation

**Root Causes Identified and Fixed**:
1. **AGIC Permissions** - Missing Network Contributor role on VNet/subnet
2. **Network Policies** - Blocking traffic from kube-system namespace
3. **LoadBalancer Health Checks** - Using TCP instead of HTTP probes
4. **NSG Rules** - Missing rules for NodePort ranges
5. **AGIC Installation** - Replaced deprecated Helm repo with Azure CLI AKS addon

**Key Learnings**:
- Always check AGIC pod logs for permission errors
- Network policies must allow kube-system traffic for AGIC
- LoadBalancer services need proper HTTP health check annotations
- NSG rules are required for NodePort access

### Managed Identity Issues �

**Status**: **ACTIVELY RESOLVING** - Comprehensive fix applied for credential reconciliation failure

The deployment encountered a managed identity credential reconciliation issue during AKS cluster creation. This is a critical Azure infrastructure issue that has been comprehensively addressed:

**Error Details:**
```
"Reconcile managed identity credential failed. Details: unexpected response from MSI data plane, length of returned certificate: 0"
```

**Solutions Applied:**
- **Enhanced Dependency Management**: All role assignments must complete before AKS creation
- **Identity Propagation Delay**: 60-second time delay to ensure managed identity is accessible
- **Comprehensive Recovery Tools**: Scripts and documentation for manual troubleshooting

**Latest Fix (99a5c67)**: Complete managed identity credential reconciliation resolution

See comprehensive analysis and recovery options:
- **[MANAGED_IDENTITY_FIX.md](MANAGED_IDENTITY_FIX.md)** - Detailed analysis, root cause, and solutions
- **[DEPLOYMENT_STATUS_UPDATE.md](DEPLOYMENT_STATUS_UPDATE.md)** - Real-time deployment status and monitoring
- **[scripts/terraform/managed-identity-recovery.sh](scripts/terraform/managed-identity-recovery.sh)** - Manual recovery script

**Current Import Resources Being Handled**:
- `azurerm_user_assigned_identity.aks`
- `azurerm_log_analytics_solution.container_insights[0]`
- `azurerm_application_insights.main[0]`
- `azurerm_kubernetes_cluster.main` **[LATEST]**
- `azurerm_application_gateway.main`
- `azurerm_subnet_network_security_group_association.aks`
- `azurerm_subnet_network_security_group_association.appgw`

### AKS Node Resource Group Naming ✅

**Status**: **RESOLVED** - Consistent naming pattern implemented

Fixed the AKS node resource group naming to follow the consistent DevOps naming convention. See:

- **[AKS_NODE_RESOURCE_GROUP_FIX.md](AKS_NODE_RESOURCE_GROUP_FIX.md)** - Complete naming fix documentation

**Before**: `rg-zabbix-devops-eastus-aks-nodes-devops-eastus` (malformed, duplicated suffix)
**After**: `rg-aks-nodes-devops-eastus` (consistent pattern)

### Common Issues

#### 1. 502 Bad Gateway
- **Status**: ✅ RESOLVED
- **Solution**: See documentation above

#### 2. AGIC Not Starting
```bash
# Check AGIC logs
kubectl logs -n kube-system -l app=ingress-appgw

# Verify role assignments
az role assignment list --assignee <agic-identity-id>
```

#### 3. Database Connection Issues
```bash
# Check database pod
kubectl get pods -n zabbix
kubectl logs zabbix-mysql-<pod-id> -n zabbix

# Test database connectivity
kubectl exec -it zabbix-server-<pod-id> -n zabbix -- mysql -h zabbix-mysql -u zabbix -p
```

## �📞 Support

For issues and questions:
- Create a GitHub issue
- Contact the DevOps team
- Check the [troubleshooting section](#-troubleshooting)

---

**⚠️ Important Security Notes:**
- Change all default passwords immediately after deployment
- Configure SSL certificates for production use
- Regularly update container images and apply security patches
- Monitor access logs and set up alerting
