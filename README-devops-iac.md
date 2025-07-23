# 🚀 DevOps Infrastructure as Code (IaC)

> **Enterprise-grade Infrastructure as Code for Azure Kubernetes Service (AKS) with Zabbix Monitoring**

This repository contains production-ready Infrastructure as Code (IaC) templates and automation scripts for deploying a comprehensive Zabbix monitoring solution on Azure Kubernetes Service (AKS).

## 🏗️ Architecture Overview

```
Internet
    │
    ▼
┌─────────────────┐
│ Application     │
│ Gateway         │ ← SSL Termination & External Access
│ (Azure)         │
└─────────────────┘
    │
    ▼ 
┌─────────────────┐
│ AKS Cluster     │
│                 │
│ ┌─────────────┐ │
│ │ Zabbix Web  │ │ ← NGINX Frontend
│ │ Interface   │ │
│ └─────────────┘ │
│        │        │
│        ▼        │
│ ┌─────────────┐ │
│ │ Zabbix      │ │ ← Monitoring Engine
│ │ Server      │ │
│ └─────────────┘ │
│        │        │
│        ▼        │
│ ┌─────────────┐ │
│ │ MySQL       │ │ ← Database Backend
│ │ Database    │ │
│ └─────────────┘ │
└─────────────────┘
```

## 🎯 Features

### ✅ **Infrastructure Components**
- **AKS Cluster** with optimized node pools
- **Application Gateway** with SSL termination
- **Virtual Network** with security groups
- **Container Registry** for custom images
- **Log Analytics** for monitoring and diagnostics
- **Managed Identity** for secure authentication

### ✅ **Zabbix Monitoring Stack**
- **Zabbix Server 6.0** - Latest stable version
- **MySQL Database** - Optimized for performance
- **Web Interface** - Modern NGINX-based frontend
- **Auto-scaling** - Kubernetes HPA support
- **Persistent Storage** - Azure Disk integration

### ✅ **DevOps & Automation**
- **GitHub Actions** - Complete CI/CD pipeline
- **Terraform** - Infrastructure as Code
- **Kubernetes Manifests** - Application deployment
- **Automated Testing** - Infrastructure validation
- **Recovery Scripts** - Automated issue resolution

## 🚀 Quick Start

### Prerequisites
- Azure Subscription with appropriate permissions
- GitHub repository with Actions enabled
- Azure CLI installed (for local development)
- kubectl installed (for cluster management)

### 1. **Fork & Configure Repository**
```bash
# Fork this repository to your GitHub account
# Configure the following secrets in your GitHub repository:

AZURE_CLIENT_ID       # Service Principal App ID
AZURE_CLIENT_SECRET   # Service Principal Secret
AZURE_SUBSCRIPTION_ID # Azure Subscription ID
AZURE_TENANT_ID       # Azure Tenant ID
```

### 2. **Deploy Infrastructure**
```bash
# Trigger deployment via GitHub Actions
# Push to main branch or manually trigger the workflow

# Or deploy locally:
cd infra/terraform
terraform init
terraform plan
terraform apply
```

### 3. **Access Zabbix**
```bash
# Get the Application Gateway URL
az network public-ip show \
  --resource-group rg-devops-pops-eastus \
  --name pip-appgw-devops-eastus \
  --query ipAddress --output tsv

# Default credentials:
# Username: Admin
# Password: zabbix
```

## 📋 Resource Naming Convention

All resources follow a standardized DevOps naming pattern:

**Pattern**: `{resource-type}-devops-{region}`

### Examples:
- AKS Cluster: `aks-devops-eastus`
- Virtual Network: `vnet-devops-eastus`
- Application Gateway: `appgw-devops-eastus`
- Container Registry: `acrdevopseastus`
- Log Analytics: `law-devops-eastus`

## 🔧 Configuration

### **Environment Variables**
Key configuration settings in `.github/workflows/deploy.yml`:

```yaml
env:
  AZURE_REGION: "eastus"
  RESOURCE_GROUP: "rg-devops-pops-eastus"
  AKS_CLUSTER_NAME: "aks-devops-eastus"
  APPLICATION_GATEWAY_NAME: "appgw-devops-eastus"
```

### **Terraform Variables**
Customize deployment in `infra/terraform/terraform.tfvars`:

```hcl
location = "East US"
environment = "production"
node_count = 3
vm_size = "Standard_D2s_v3"
```

### **Kubernetes Configuration**
Application settings in `applications/zabbix/k8s/`:

- `zabbix-mysql.yaml` - Database configuration
- `zabbix-server.yaml` - Server configuration  
- `zabbix-web.yaml` - Web interface configuration
- `zabbix-config.yaml` - ConfigMaps and Secrets

## 🛡️ Security & Best Practices

### **Security Features**
- **Managed Identity** - No stored credentials
- **Network Policies** - Micro-segmentation
- **Azure Key Vault** - Secret management
- **RBAC** - Role-based access control
- **Private Endpoints** - Secure connectivity

### **Production Readiness**
- **High Availability** - Multi-zone deployment
- **Auto-scaling** - HPA and VPA support
- **Monitoring** - Comprehensive logging
- **Backup** - Automated database backups
- **Disaster Recovery** - Cross-region replication

## 🔍 Troubleshooting & Support

### **Automated Recovery**
The repository includes comprehensive recovery scripts:

```bash
# Fix common deployment issues
./scripts/terraform/post-deployment-zabbix-fix.sh

# Resolve Kubernetes resource conflicts
./scripts/terraform/resolve-k8s-conflicts.sh

# Emergency cluster recovery (last resort)
./scripts/terraform/emergency-aks-delete.sh
```

### **Common Issues**

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **Missing Web Frontend** | 502 Bad Gateway | Run post-deployment fix script |
| **Database Version Mismatch** | Server fails to start | Script auto-updates to compatible version |
| **Resource Conflicts** | "Already exists" errors | Import existing resources automatically |
| **Gateway Misconfiguration** | 503 Service Unavailable | Script updates backend configuration |

### **Getting Help**
1. Check the workflow logs in GitHub Actions
2. Run diagnostic scripts in `scripts/terraform/`
3. Review Kubernetes logs: `kubectl logs -n zabbix`
4. Check Azure Portal for resource status

## 📚 Documentation

### **Repository Structure**
```
devops-iac/
├── .github/workflows/     # CI/CD pipelines
├── infra/terraform/       # Infrastructure as Code
├── applications/zabbix/   # Kubernetes manifests
├── scripts/terraform/     # Automation scripts
└── docs/                  # Additional documentation
```

### **Key Files**
- `deploy.yml` - Main CI/CD workflow
- `main.tf` - Core infrastructure definition
- `kubernetes.tf` - AKS and K8s resources
- `zabbix-*.yaml` - Application manifests

## 🚀 Deployment Workflow

### **Automated Deployment**
1. **Infrastructure Provisioning** (Terraform)
   - Azure resources created
   - AKS cluster deployed
   - Networking configured

2. **Application Deployment** (Kubernetes)
   - Zabbix components deployed
   - Database initialized
   - Services configured

3. **Post-Deployment Verification**
   - Health checks performed
   - Gateway configuration validated
   - URLs tested and verified

4. **Automated Recovery** (If needed)
   - Issues detected and resolved
   - Components restarted if necessary
   - Full stack verification

## 🎯 Production Deployment

### **Environment Preparation**
1. **Azure Setup**
   - Create service principal
   - Assign appropriate permissions
   - Configure DNS (if custom domain needed)

2. **GitHub Configuration**
   - Set repository secrets
   - Enable GitHub Actions
   - Configure branch protection

3. **Deployment**
   - Push to main branch
   - Monitor workflow execution
   - Verify successful deployment

### **Post-Deployment**
1. **Security Hardening**
   - Change default passwords
   - Configure SSL certificates
   - Set up monitoring alerts

2. **Customization**
   - Configure Zabbix monitoring rules
   - Set up user accounts
   - Configure notifications

## 📈 Monitoring & Maintenance

### **Built-in Monitoring**
- **Azure Monitor** - Infrastructure metrics
- **Log Analytics** - Centralized logging
- **Application Insights** - Performance monitoring
- **Zabbix** - Custom monitoring rules

### **Maintenance Tasks**
- Regular security updates
- Database maintenance
- Certificate renewal
- Capacity planning

## 🔄 Updates & Upgrades

### **Version Management**
- All components use pinned versions
- Controlled upgrade process
- Rollback capabilities
- Testing in staging environment

### **Upgrade Process**
1. Update version tags in manifests
2. Test in non-production environment
3. Deploy via GitHub Actions
4. Verify functionality
5. Monitor for issues

## 📝 Contributing

### **Development Workflow**
1. Fork the repository
2. Create feature branch
3. Make changes and test
4. Submit pull request
5. Review and merge

### **Testing**
- Infrastructure validation
- Application deployment testing
- End-to-end functionality testing
- Security scanning

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Support

For issues, questions, or contributions:
- Create GitHub Issues for bugs or feature requests
- Submit Pull Requests for improvements
- Check existing documentation and scripts

---

**Status**: ✅ **Production Ready**  
**Maintained by**: DevOps Team  
**Last Updated**: January 2025

**Quick Links**:
- [Deployment Guide](#quick-start)
- [Troubleshooting](#troubleshooting--support)
- [Architecture](#architecture-overview)
- [Security](#security--best-practices)
