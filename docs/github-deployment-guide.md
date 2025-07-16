# GitHub Actions Deployment Guide

This guide will help you deploy your Zabbix AKS infrastructure using GitHub Actions.

## Prerequisites

1. **GitHub Repository**: Create a new GitHub repository for this project
2. **Azure Account**: Access to Azure subscription `d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf`
3. **Azure CLI**: For creating service principal (one-time setup)

## Step 1: Create Azure Service Principal

You need to create a service principal for GitHub Actions to authenticate with Azure.

### Option A: Using Azure CLI (Recommended)

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"

# Create service principal with contributor role
az ad sp create-for-rbac \
  --name "github-actions-zabbix-deployment" \
  --role "Contributor" \
  --scopes "/subscriptions/d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf/resourceGroups/Devops-Test" \
  --sdk-auth
```

This command will output JSON credentials. **Copy this JSON output** - you'll need it for the GitHub secret.

### Option B: Using Azure Portal

1. Go to Azure Portal → Azure Active Directory → App registrations
2. Click "New registration"
3. Name: `github-actions-zabbix-deployment`
4. Create the application
5. Go to "Certificates & secrets" → Create new client secret
6. Go to your resource group → Access control (IAM)
7. Add role assignment → Contributor → Select your app registration

## Step 2: Set Up GitHub Repository

### 2.1 Create Repository
1. Create a new GitHub repository (e.g., `zabbix-aks-deployment`)
2. Clone it locally or use GitHub web interface

### 2.2 Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Create the following **Repository Secret**:

- **Name**: `AZURE_CREDENTIALS`
- **Value**: The complete JSON output from the `az ad sp create-for-rbac` command

Example format:
```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

### 2.3 Create Environment Protection (Optional but Recommended)

1. Go to Settings → Environments
2. Create environment named: `production`
3. Add protection rules:
   - Required reviewers (recommended)
   - Deployment branches: `main` only

## Step 3: Commit and Push Code

### 3.1 Initialize Git Repository (if not done)
```bash
git init
git add .
git commit -m "Initial Zabbix AKS deployment setup"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/YOUR-REPO-NAME.git
```

### 3.2 Push to GitHub
```bash
git push -u origin main
```

## Step 4: Trigger Deployment

### Automatic Trigger
The workflow will automatically run when you push to the `main` branch.

### Manual Trigger
1. Go to your GitHub repository
2. Click "Actions" tab
3. Select "Deploy AKS Zabbix Infrastructure" workflow
4. Click "Run workflow" → "Run workflow"

## Step 5: Monitor Deployment

1. **Watch the GitHub Actions run**: You can see real-time progress in the Actions tab
2. **Review deployment logs**: Each step shows detailed output
3. **Check deployment report**: Artifact will be generated with deployment summary

## Step 6: Post-Deployment Configuration

After successful deployment:

### 6.1 DNS Configuration
Point `dal2-devmon-mgt.forescout.com` to the Application Gateway public IP:
- Get the IP from the GitHub Actions output
- Update your DNS A record

### 6.2 SSL Certificate Configuration
Upload your SSL certificate to Azure Key Vault and configure Application Gateway.

### 6.3 Zabbix Initial Setup
1. Access Zabbix web interface at `https://dal2-devmon-mgt.forescout.com`
2. Default credentials:
   - Username: `Admin`
   - Password: `zabbix`
3. **Change the default password immediately**

### 6.4 Security Hardening
1. Update database passwords in Kubernetes secrets
2. Configure proper RBAC in Kubernetes
3. Review and update Network Security Group rules

## Expected Deployment Time

- **Infrastructure Provisioning**: ~15-20 minutes
- **Application Deployment**: ~10-15 minutes
- **Total**: ~25-35 minutes

## Troubleshooting

### Common Issues

1. **Authentication Failed**
   - Verify `AZURE_CREDENTIALS` secret is correct
   - Check service principal permissions

2. **Resource Already Exists**
   - The workflow uses unique naming with run numbers
   - Check if resource group has conflicting resources

3. **Deployment Timeout**
   - AKS cluster creation can take 15-20 minutes
   - Check Azure activity logs for detailed errors

4. **DNS Not Resolving**
   - Verify DNS A record configuration
   - Check Application Gateway public IP in Azure portal

### Getting Help

1. **Check GitHub Actions logs**: Detailed error messages in each step
2. **Azure Activity Log**: Check Azure portal for resource-level errors
3. **Kubernetes logs**: Use `kubectl logs` commands after getting AKS credentials

## Security Considerations

- Service principal has Contributor access to the specific resource group only
- Kubernetes secrets contain database passwords (rotate regularly)
- Network Security Groups restrict traffic to necessary ports only
- Application Gateway provides SSL termination and WAF protection

## Cleanup

To remove all resources:
```bash
az group delete --name Devops-Test --yes --no-wait
```

**Warning**: This will delete ALL resources in the resource group.
