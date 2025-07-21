# Zabbix on AKS - GitHub Actions Deployment

This repository contains an optimized GitHub Actions workflow for deploying Zabbix monitoring system on Azure Kubernetes Service (AKS) with full infrastructure as code support.

## 🚀 Quick Start

### Prerequisites
- Azure subscription with appropriate permissions
- GitHub repository with secrets configured
- Azure CLI or GitHub CLI (optional, for local triggers)

### Required GitHub Secrets
Add these secrets to your GitHub repository (`Settings` → `Secrets and variables` → `Actions`):

```
AZURE_CREDENTIALS: {
  "clientId": "your-service-principal-client-id",
  "clientSecret": "your-service-principal-secret", 
  "subscriptionId": "your-azure-subscription-id",
  "tenantId": "your-azure-tenant-id"
}
```

## 📋 Deployment Options

### 1. Full Deployment (Infrastructure + Application)
Deploys both Azure infrastructure and Zabbix application:
```bash
# Via GitHub CLI
gh workflow run deploy-optimized.yml \
  --field deployment_type=full \
  --field infrastructure_method=terraform

# Via PowerShell helper
.\trigger-deployment.ps1 -DeploymentType full
```

### 2. Infrastructure Only
Deploys only the Azure infrastructure (AKS, Application Gateway, etc.):
```bash
gh workflow run deploy-optimized.yml \
  --field deployment_type=infrastructure-only \
  --field infrastructure_method=terraform
```

### 3. Application Only  
Deploys only Zabbix to existing AKS cluster:
```bash
gh workflow run deploy-optimized.yml \
  --field deployment_type=application-only

# Or via PowerShell
.\trigger-deployment.ps1 -DeploymentType application-only
```

### 4. Clean Redeploy
Completely redeploys everything with fresh state:
```bash
gh workflow run deploy-optimized.yml \
  --field deployment_type=redeploy-clean \
  --field reset_database=true

# Or via PowerShell  
.\trigger-deployment.ps1 -DeploymentType redeploy-clean -ResetDatabase $true
```

## 🏗️ Infrastructure Components

The deployment creates these Azure resources:

- **AKS Cluster** (`aks-devops-eastus`)
  - System node pool: 2x Standard_D2s_v3
  - User node pool: 2-10x Standard_D4s_v3 (auto-scaling)
  - Kubernetes 1.32

- **Application Gateway** (`appgw-devops-eastus`)
  - Public IP with custom domain
  - SSL termination ready
  - Integrated with AKS via AGIC

- **Container Registry** (`acrdevopseastus`)
  - For custom Zabbix images (future use)

- **Networking**
  - VNet with dedicated subnets
  - Network Security Groups
  - Application Gateway Ingress Controller (AGIC)

- **Monitoring**
  - Log Analytics workspace
  - Azure Monitor integration

## 🐳 Kubernetes Components

### Zabbix Stack
- **MySQL Database** (persistent storage)
- **Zabbix Server** (monitoring engine) 
- **Zabbix Web Interface** (frontend)
- **Zabbix Java Gateway** (JMX monitoring)

### Ingress Controllers
- **AGIC** (Azure Application Gateway Ingress Controller) - preferred
- **NGINX Ingress** (fallback if AGIC unavailable)

## 🌐 Access Information

After successful deployment:
- **URL**: http://dal2-devmon-mgt-devops.eastus.cloudapp.azure.com
- **Public IP**: 20.185.208.193  
- **Default Login**: Admin / zabbix

## 🔧 Helper Scripts

### `trigger-deployment.ps1`
PowerShell script to easily trigger GitHub Actions deployments:
```powershell
# Basic application deployment
.\trigger-deployment.ps1 -DeploymentType application-only

# Full deployment with debug
.\trigger-deployment.ps1 -DeploymentType full -DebugMode $true

# Clean redeploy with database reset
.\trigger-deployment.ps1 -DeploymentType redeploy-clean -ResetDatabase $true
```

### `validate-deployment.ps1` 
Comprehensive deployment validation and troubleshooting:
```powershell
.\validate-deployment.ps1
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Pods Not Starting
```bash
kubectl get pods -n zabbix
kubectl describe pod <pod-name> -n zabbix
kubectl logs <pod-name> -n zabbix
```

#### 2. Database Issues
```bash
# Check MySQL pod
kubectl exec -it <mysql-pod> -n zabbix -- mysql -u root -pZabbixRoot123! -e "SHOW DATABASES;"

# Reinitialize database
kubectl delete job zabbix-db-init -n zabbix
kubectl apply -f applications/zabbix/k8s/zabbix-db-init-direct.yaml
```

#### 3. Ingress Not Working
```bash
# Check ingress controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=ingress-appgw
kubectl get pods -n ingress-nginx

# Check ingress rules
kubectl get ingress -n zabbix
kubectl describe ingress zabbix-ingress -n zabbix
```

#### 4. Application Gateway Issues
```bash
# Check AGIC status
kubectl logs -l app.kubernetes.io/name=ingress-appgw -n kube-system

# Restart AGIC
kubectl rollout restart deployment/ingress-appgw -n kube-system
```

### Manual Recovery

#### Reset Application Only
```bash
kubectl delete deployment,service,ingress -n zabbix --all
kubectl apply -f k8s/
```

#### Reset Database (⚠️ Data Loss)
```bash
kubectl delete pvc -n zabbix --all
kubectl delete job zabbix-db-init -n zabbix
kubectl apply -f applications/zabbix/k8s/zabbix-mysql.yaml
kubectl apply -f applications/zabbix/k8s/zabbix-db-init-direct.yaml
```

## 🔒 Security Considerations

### Immediate Actions After Deployment
1. **Change default passwords**:
   - Zabbix Admin: Login → Administration → Users → Admin
   - Database passwords (in production)

2. **Configure SSL/TLS**:
   - Upload SSL certificate to Application Gateway
   - Update ingress to redirect HTTP → HTTPS

3. **Network Security**:
   - Review NSG rules
   - Configure Azure Firewall if needed
   - Restrict AKS API server access

4. **Monitoring**:
   - Set up Azure Monitor alerts
   - Configure Log Analytics queries
   - Enable Azure Security Center

## 📊 Monitoring & Maintenance

### Health Checks
- Use `validate-deployment.ps1` for regular health checks
- Monitor GitHub Actions workflow runs
- Check Azure Monitor dashboards

### Updates
- Kubernetes version updates via Terraform
- Zabbix version updates via container image tags
- Infrastructure updates via Terraform

### Backup Strategy
- Database backups via MySQL dump or Azure Backup
- Terraform state backups (already in Azure Storage)
- Kubernetes manifests in Git

## 🆘 Support & Documentation

### Useful Commands
```bash
# Get all resources
kubectl get all -n zabbix

# Check logs
kubectl logs -l app=zabbix-server -n zabbix

# Port forward for direct access
kubectl port-forward service/zabbix-web 8080:80 -n zabbix

# Terraform operations
cd infra/terraform
terraform plan
terraform apply
terraform output
```

### External Links
- [Zabbix Documentation](https://www.zabbix.com/documentation/current/)
- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Application Gateway Ingress Controller](https://docs.microsoft.com/en-us/azure/application-gateway/ingress-controller-overview)

---

## 🎯 Workflow Features

### Optimization Highlights
- ✅ **Smart resource imports** - Handles existing infrastructure gracefully
- ✅ **AGIC integration** - Uses Application Gateway when available, NGINX as fallback  
- ✅ **Database persistence** - Preserves data between deployments unless explicitly reset
- ✅ **Comprehensive validation** - Built-in health checks and troubleshooting
- ✅ **Flexible deployment** - Infrastructure-only, app-only, or full deployment options
- ✅ **Error resilience** - Continues on non-critical failures with helpful warnings
- ✅ **Rich logging** - Detailed deployment progress with emojis for clarity
- ✅ **Helper scripts** - PowerShell utilities for easy triggering and validation

### Improvements Over Original
- Fixed kubectl/helm installation steps  
- Added proper AGIC setup with NGINX fallback
- Improved error handling and logging
- Added comprehensive validation and troubleshooting
- Simplified trigger mechanisms
- Better resource cleanup strategies
- Enhanced security considerations
