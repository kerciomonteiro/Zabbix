# Zabbix Server on Azure Kubernetes Service (AKS)

This repository contains the Infrastructure as Code (IaC) and Kubernetes manifests to deploy a complete Zabbix monitoring solution on Azure Kubernetes Service (AKS) with the following components:

- **AKS Cluster** with system and worker node pools
- **Zabbix Server** with MySQL database backend
- **Zabbix Web Interface** with NGINX
- **Application Gateway** for external access with SSL termination
- **NGINX Ingress Controller** for internal routing
- **Automated CI/CD** deployment via GitHub Actions

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

3. **Push to main branch** or manually trigger the workflow:
   ```bash
   git push origin main
   ```

4. **Monitor the deployment** in GitHub Actions

5. **Configure DNS** once deployment completes:
   - Point `dal2-devmon-mgt.forescout.com` to the Application Gateway IP

## 🔧 Manual Deployment

If you prefer to deploy manually:

### 1. Deploy Infrastructure

```bash
# Clone the repository
git clone <your-repo-url>
cd Zabbix

# Install Azure Developer CLI
curl -fsSL https://aka.ms/install-azd.sh | bash

# Login to Azure
azd auth login

# Set environment variables
azd env set AZURE_ENV_NAME "zabbix-production"
azd env set AZURE_LOCATION "eastus"
azd env set AZURE_SUBSCRIPTION_ID "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"
azd env set AZURE_RESOURCE_GROUP "Devops-Test"

# Deploy infrastructure
azd provision
```

### 2. Deploy Zabbix Application

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group Devops-Test \
  --name $(azd env get-value AKS_CLUSTER_NAME)

# Deploy Zabbix components
kubectl apply -f k8s/zabbix-config.yaml
kubectl apply -f k8s/zabbix-mysql.yaml
kubectl apply -f k8s/zabbix-additional.yaml
kubectl apply -f k8s/zabbix-server.yaml
kubectl apply -f k8s/zabbix-web.yaml
kubectl apply -f k8s/zabbix-ingress.yaml

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
  --cluster-name $(azd env get-value AKS_CLUSTER_NAME) \
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
│   ├── main.bicep             # Main infrastructure template
│   └── main.parameters.json   # Infrastructure parameters
├── k8s/
│   ├── zabbix-config.yaml     # Namespace and configuration
│   ├── zabbix-mysql.yaml      # MySQL database
│   ├── zabbix-server.yaml     # Zabbix server
│   ├── zabbix-web.yaml        # Web interface
│   ├── zabbix-ingress.yaml    # Ingress configuration
│   └── zabbix-additional.yaml # Java Gateway and Proxy
├── docs/
│   └── ssl-configuration.md   # SSL setup guide
├── azure.yaml                 # AZD configuration
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

Update MySQL configuration in `k8s/zabbix-mysql.yaml`:

```yaml
args:
- "--innodb-buffer-pool-size=2G"
- "--max-connections=500"
- "--character-set-server=utf8"
```

### Zabbix Server Parameters

Modify Zabbix server configuration in `k8s/zabbix-config.yaml`:

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

1. **Infrastructure Deployment** - Provisions AKS and supporting resources
2. **Application Deployment** - Deploys Zabbix components
3. **Security Configuration** - Applies security settings
4. **Health Verification** - Validates deployment success

### Workflow Triggers

- Push to `main` branch
- Pull requests to `main`
- Manual workflow dispatch

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

## 📞 Support

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
