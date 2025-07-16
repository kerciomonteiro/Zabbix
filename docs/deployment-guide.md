# AKS Zabbix Deployment Guide

This guide provides detailed step-by-step instructions for deploying Zabbix monitoring server on Azure Kubernetes Service (AKS).

## Table of Contents

- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
- [Pre-Deployment Setup](#pre-deployment-setup)
- [Infrastructure Deployment](#infrastructure-deployment)
- [Application Deployment](#application-deployment)
- [SSL Configuration](#ssl-configuration)
- [DNS Configuration](#dns-configuration)
- [Post-Deployment Configuration](#post-deployment-configuration)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Azure Requirements

- Azure subscription with Contributor access
- Resource Group: `Devops-Test` (or custom)
- Azure CLI installed and configured
- Subscription ID: `d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf`

### Local Tools

```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install kubectl
az aks install-cli

# Install Helm
curl https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz | tar xz
sudo mv linux-amd64/helm /usr/local/bin/

# Install Azure Developer CLI
curl -fsSL https://aka.ms/install-azd.sh | bash
```

### GitHub Setup

1. **Fork the repository** to your GitHub account
2. **Configure repository secrets**:
   - `AZURE_CREDENTIALS`: Service Principal JSON

### Service Principal Creation

```bash
# Create service principal
az ad sp create-for-rbac \
  --name "github-actions-zabbix" \
  --role contributor \
  --scopes /subscriptions/d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf/resourceGroups/Devops-Test \
  --sdk-auth

# Output will be the AZURE_CREDENTIALS secret value
```

## Architecture Overview

### Network Architecture

```
Virtual Network (10.224.0.0/12)
├── AKS Subnet (10.224.0.0/16)
│   ├── System Node Pool (2-5 nodes)
│   ├── Worker Node Pool (2-10 nodes)
│   └── Zabbix Pods
└── Application Gateway Subnet (10.225.0.0/24)
    └── Application Gateway (External IP)
```

### Component Architecture

1. **Infrastructure Layer**:
   - AKS Cluster with managed identity
   - Virtual Network with NSGs
   - Application Gateway for SSL termination
   - Container Registry for images
   - Log Analytics for monitoring

2. **Application Layer**:
   - Zabbix Server (monitoring engine)
   - MySQL Database (persistent storage)
   - Zabbix Web Interface (NGINX-based)
   - Java Gateway (JMX monitoring)

3. **Networking Layer**:
   - Application Gateway Ingress Controller
   - LoadBalancer services
   - Network policies for security

## Pre-Deployment Setup

### 1. Environment Preparation

```bash
# Clone repository
git clone <your-forked-repo>
cd Zabbix

# Set up Azure CLI
az login
az account set --subscription d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf
```

### 2. Configuration Review

Review and customize these files:
- `infra/main.bicep` - Infrastructure configuration
- `k8s/zabbix-config.yaml` - Database passwords
- `.github/workflows/deploy.yml` - CI/CD pipeline

### 3. Security Configuration

**⚠️ Important**: Change default passwords in `k8s/zabbix-config.yaml`:

```bash
# Generate secure passwords
openssl rand -base64 32  # For MySQL root
openssl rand -base64 32  # For Zabbix user

# Encode in base64
echo -n "your-new-password" | base64
```

Update the secrets in `k8s/zabbix-config.yaml`:
```yaml
data:
  mysql-root-password: <base64-encoded-root-password>
  mysql-password: <base64-encoded-zabbix-password>
```

## Infrastructure Deployment

### Method 1: GitHub Actions (Recommended)

1. **Push to main branch**:
   ```bash
   git add .
   git commit -m "Initial Zabbix deployment"
   git push origin main
   ```

2. **Monitor deployment**:
   - Go to GitHub Actions tab
   - Watch the "Deploy AKS Zabbix Infrastructure" workflow
   - Review deployment logs

3. **Get deployment outputs**:
   - Check the workflow artifacts for deployment report
   - Note the Application Gateway IP address

### Method 2: Manual Deployment

```bash
# Initialize AZD
azd auth login
azd init

# Set environment variables
azd env set AZURE_ENV_NAME "zabbix-prod"
azd env set AZURE_LOCATION "eastus2" 
azd env set AZURE_SUBSCRIPTION_ID "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"
azd env set AZURE_RESOURCE_GROUP "Devops-Test"
azd env set AZURE_PRINCIPAL_ID "$(az ad signed-in-user show --query id -o tsv)"

# Deploy infrastructure
azd provision --no-prompt

# Get AKS credentials
az aks get-credentials \
  --resource-group Devops-Test \
  --name $(azd env get-value AKS_CLUSTER_NAME) \
  --overwrite-existing
```

### Verify Infrastructure

```bash
# Check AKS cluster
kubectl cluster-info
kubectl get nodes

# Check Application Gateway
az network application-gateway show \
  --resource-group Devops-Test \
  --name $(azd env get-value APPLICATION_GATEWAY_NAME)
```

## Application Deployment

### 1. Deploy Base Components

```bash
# Create namespace and configuration
kubectl apply -f k8s/zabbix-config.yaml

# Deploy MySQL database
kubectl apply -f k8s/zabbix-mysql.yaml

# Wait for MySQL to be ready
kubectl wait --for=condition=ready pod -l app=zabbix-mysql -n zabbix --timeout=300s
```

### 2. Initialize Database

```bash
# Get MySQL pod name
MYSQL_POD=$(kubectl get pods -n zabbix -l app=zabbix-mysql -o jsonpath='{.items[0].metadata.name}')

# Create Zabbix database and user
kubectl exec -n zabbix $MYSQL_POD -- mysql -u root -p<your-root-password> -e "
CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8 COLLATE utf8_bin;
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'%' IDENTIFIED BY '<your-zabbix-password>';
FLUSH PRIVILEGES;"

# Download and import Zabbix schema (this step requires manual intervention)
# You may need to download the Zabbix SQL schema and import it
```

### 3. Deploy Zabbix Services

```bash
# Deploy Java Gateway
kubectl apply -f k8s/zabbix-additional.yaml
kubectl wait --for=condition=available deployment/zabbix-java-gateway -n zabbix --timeout=300s

# Deploy Zabbix Server
kubectl apply -f k8s/zabbix-server.yaml
kubectl wait --for=condition=available deployment/zabbix-server -n zabbix --timeout=300s

# Deploy Web Interface
kubectl apply -f k8s/zabbix-web.yaml
kubectl wait --for=condition=available deployment/zabbix-web -n zabbix --timeout=300s
```

### 4. Configure Ingress

```bash
# Deploy ingress configuration
kubectl apply -f k8s/zabbix-ingress.yaml

# Get LoadBalancer IP
kubectl get services -n zabbix zabbix-web-external
```

## SSL Configuration

### Option 1: Azure Key Vault Certificate

1. **Upload certificate to Key Vault**:
   ```bash
   # Create Key Vault
   az keyvault create \
     --name "kv-zabbix-$(openssl rand -hex 4)" \
     --resource-group Devops-Test \
     --location eastus2

   # Upload PFX certificate
   az keyvault certificate import \
     --vault-name "your-keyvault-name" \
     --name "zabbix-ssl-cert" \
     --file "/path/to/certificate.pfx" \
     --password "certificate-password"
   ```

2. **Configure Application Gateway**:
   ```bash
   az network application-gateway ssl-cert create \
     --resource-group Devops-Test \
     --gateway-name $(azd env get-value APPLICATION_GATEWAY_NAME) \
     --name "zabbix-ssl-cert" \
     --key-vault-secret-id "https://your-keyvault.vault.azure.net/secrets/zabbix-ssl-cert"
   ```

3. **Update ingress annotations** in `k8s/zabbix-ingress.yaml`:
   ```yaml
   annotations:
     appgw.ingress.kubernetes.io/appgw-ssl-certificate: "zabbix-ssl-cert"
   ```

### Option 2: Let's Encrypt (cert-manager)

1. **Install cert-manager**:
   ```bash
   helm repo add jetstack https://charts.jetstack.io
   helm repo update
   helm install cert-manager jetstack/cert-manager \
     --namespace cert-manager \
     --create-namespace \
     --version v1.13.0 \
     --set installCRDs=true
   ```

2. **Create ClusterIssuer**:
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: letsencrypt-prod
   spec:
     acme:
       server: https://acme-v02.api.letsencrypt.org/directory
       email: admin@forescout.com
       privateKeySecretRef:
         name: letsencrypt-prod
       solvers:
       - http01:
           ingress:
             class: azure/application-gateway
   ```

3. **Update ingress for automatic certificate**:
   ```yaml
   annotations:
     cert-manager.io/cluster-issuer: "letsencrypt-prod"
   ```

## DNS Configuration

### 1. Get Public IP

```bash
# Get Application Gateway public IP
PUBLIC_IP=$(az network public-ip show \
  --resource-group Devops-Test \
  --name $(azd env get-value PUBLIC_IP_NAME) \
  --query ipAddress \
  --output tsv)

echo "Configure DNS A record: dal2-devmon-mgt.forescout.com -> $PUBLIC_IP"
```

### 2. Configure DNS Record

Create DNS A record:
- **Host**: dal2-devmon-mgt
- **Domain**: forescout.com
- **Type**: A
- **Value**: [Public IP from above]
- **TTL**: 300

### 3. Verify DNS Resolution

```bash
# Test DNS resolution
nslookup dal2-devmon-mgt.forescout.com

# Test HTTP access
curl -I http://dal2-devmon-mgt.forescout.com

# Test HTTPS access (after SSL setup)
curl -I https://dal2-devmon-mgt.forescout.com
```

## Post-Deployment Configuration

### 1. Access Zabbix Web Interface

1. **Open browser** to https://dal2-devmon-mgt.forescout.com
2. **Login** with default credentials:
   - Username: `Admin`
   - Password: `zabbix`

### 2. Initial Zabbix Configuration

1. **Change admin password**:
   - Go to Administration → Users
   - Click on Admin user
   - Change password to a secure one

2. **Configure monitoring**:
   - Add hosts to monitor
   - Configure templates
   - Set up alerting

### 3. Security Hardening

```bash
# Update database passwords
kubectl patch secret zabbix-db-secret -n zabbix --type merge -p '{
  "data": {
    "mysql-password": "'$(echo -n "new-secure-password" | base64)'"
  }
}'

# Restart pods to pick up new passwords
kubectl rollout restart deployment/zabbix-server -n zabbix
kubectl rollout restart deployment/zabbix-web -n zabbix
```

### 4. Configure Backup

```bash
# Create backup script
cat > backup-zabbix.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backup/zabbix"
mkdir -p $BACKUP_DIR

# Backup MySQL database
kubectl exec -n zabbix deployment/zabbix-mysql -- mysqldump \
  -u root -p$MYSQL_ROOT_PASSWORD zabbix > $BACKUP_DIR/zabbix-db-$DATE.sql

# Backup Kubernetes configurations
kubectl get all -n zabbix -o yaml > $BACKUP_DIR/zabbix-k8s-$DATE.yaml

echo "Backup completed: $BACKUP_DIR/zabbix-*-$DATE.*"
EOF

chmod +x backup-zabbix.sh
```

## Monitoring and Maintenance

### Health Monitoring

```bash
# Check all pods
kubectl get pods -n zabbix -o wide

# Check services
kubectl get services -n zabbix

# Check persistent volumes
kubectl get pv,pvc -n zabbix

# View pod logs
kubectl logs -n zabbix deployment/zabbix-server --tail=100
kubectl logs -n zabbix deployment/zabbix-web --tail=100
```

### Performance Monitoring

```bash
# Check resource usage
kubectl top pods -n zabbix
kubectl top nodes

# Check Application Gateway metrics
az monitor metrics list \
  --resource $(azd env get-value APPLICATION_GATEWAY_ID) \
  --metric "RequestCount,ResponseTime" \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S)
```

### Scaling

```bash
# Scale Zabbix Web frontend
kubectl scale deployment zabbix-web -n zabbix --replicas=3

# Scale AKS node pool
az aks nodepool scale \
  --resource-group Devops-Test \
  --cluster-name $(azd env get-value AKS_CLUSTER_NAME) \
  --name workerpool \
  --node-count 5
```

### Updates and Upgrades

```bash
# Update Zabbix container images
kubectl set image deployment/zabbix-server -n zabbix \
  zabbix-server=zabbix/zabbix-server-mysql:6.4-alpine-latest

kubectl set image deployment/zabbix-web -n zabbix \
  zabbix-web=zabbix/zabbix-web-nginx-mysql:6.4-alpine-latest

# Update AKS cluster
az aks upgrade \
  --resource-group Devops-Test \
  --name $(azd env get-value AKS_CLUSTER_NAME) \
  --kubernetes-version 1.28.9
```

## Troubleshooting

### Common Issues

#### 1. Pods Not Starting

```bash
# Check pod status and events
kubectl describe pod <pod-name> -n zabbix

# Check node resources
kubectl top nodes
kubectl describe nodes

# Check for resource constraints
kubectl get events -n zabbix --sort-by='.lastTimestamp'
```

#### 2. Database Connection Issues

```bash
# Test MySQL connectivity
kubectl exec -n zabbix deployment/zabbix-mysql -- mysql \
  -u zabbix -p<password> -e "SELECT VERSION();"

# Check database logs
kubectl logs -n zabbix deployment/zabbix-mysql

# Verify secrets
kubectl get secret zabbix-db-secret -n zabbix -o yaml
```

#### 3. Web Interface Not Accessible

```bash
# Check web service
kubectl get svc -n zabbix zabbix-web

# Check ingress status
kubectl get ingress -n zabbix zabbix-ingress

# Test internal connectivity
kubectl port-forward -n zabbix svc/zabbix-web 8080:80
curl http://localhost:8080
```

#### 4. SSL Certificate Issues

```bash
# Check certificate in Key Vault
az keyvault certificate show \
  --vault-name "your-keyvault" \
  --name "zabbix-ssl-cert"

# Check Application Gateway SSL configuration
az network application-gateway ssl-cert list \
  --resource-group Devops-Test \
  --gateway-name $(azd env get-value APPLICATION_GATEWAY_NAME)

# Test SSL handshake
openssl s_client -connect dal2-devmon-mgt.forescout.com:443 -servername dal2-devmon-mgt.forescout.com
```

### Debugging Commands

```bash
# Get cluster info
kubectl cluster-info dump > cluster-info.txt

# Export all Zabbix resources
kubectl get all -n zabbix -o yaml > zabbix-debug.yaml

# Check Application Gateway configuration
az network application-gateway show \
  --resource-group Devops-Test \
  --name $(azd env get-value APPLICATION_GATEWAY_NAME) > appgw-config.json

# Check NSG rules
az network nsg show \
  --resource-group Devops-Test \
  --name $(azd env get-value NSG_NAME)
```

### Log Collection

```bash
# Collect all logs
mkdir zabbix-logs
kubectl logs -n zabbix deployment/zabbix-server > zabbix-logs/server.log
kubectl logs -n zabbix deployment/zabbix-web > zabbix-logs/web.log
kubectl logs -n zabbix deployment/zabbix-mysql > zabbix-logs/mysql.log

# Application Gateway logs (requires Log Analytics)
az monitor log-analytics query \
  --workspace $(azd env get-value LOG_ANALYTICS_WORKSPACE_ID) \
  --analytics-query "AzureDiagnostics | where ResourceProvider == 'MICROSOFT.NETWORK' | limit 100"
```

## Support and Resources

### Documentation Links

- [Zabbix Documentation](https://www.zabbix.com/documentation)
- [AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Application Gateway Documentation](https://docs.microsoft.com/en-us/azure/application-gateway/)

### Support Contacts

- **DevOps Team**: devops@forescout.com
- **GitHub Issues**: [Repository Issues](../../issues)
- **Emergency Contact**: On-call DevOps rotation

---

**✅ Deployment Complete!**

Your Zabbix monitoring server should now be accessible at https://dal2-devmon-mgt.forescout.com with SSL termination, high availability, and automated scaling capabilities.
