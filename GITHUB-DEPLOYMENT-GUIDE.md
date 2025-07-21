# GitHub Actions Deployment Guide

## Prerequisites

### 1. GitHub Secrets Configuration

Before deploying via GitHub Actions, ensure you have the following secret configured in your GitHub repository:

**Required Secret:**
- `AZURE_CREDENTIALS` - Azure Service Principal credentials in JSON format

#### Setting up AZURE_CREDENTIALS

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `AZURE_CREDENTIALS`
5. Value should be a JSON object with your Azure Service Principal:

```json
{
  "clientId": "your-app-id",
  "clientSecret": "your-app-secret",
  "subscriptionId": "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf",
  "tenantId": "your-tenant-id"
}
```

### 2. Azure Service Principal Setup

If you don't have a Service Principal, create one using Azure CLI:

```bash
# Login to Azure
az login

# Create Service Principal with Contributor role
az ad sp create-for-rbac --name "github-actions-zabbix" \
  --role contributor \
  --scopes /subscriptions/d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf \
  --sdk-auth
```

Copy the output and use it as the `AZURE_CREDENTIALS` secret.

### 3. GitHub Environment Setup (Optional but Recommended)

1. Go to **Settings** → **Environments**
2. Create an environment named `production`
3. Add protection rules if needed (required reviewers, etc.)

## Deployment Options

### Option 1: Manual Workflow Dispatch (Recommended)

1. Go to your GitHub repository
2. Click **Actions** tab
3. Select the workflow **"Deploy AKS Zabbix Infrastructure (Terraform & ARM)"**
4. Click **"Run workflow"**
5. Choose your deployment options:

#### Deployment Types:
- **full**: Deploy infrastructure + Zabbix application
- **infrastructure-only**: Deploy only Azure infrastructure (AKS, networking, etc.)
- **application-only**: Deploy only Zabbix to existing AKS cluster
- **redeploy-clean**: Clean deployment (destroys existing resources)

#### Infrastructure Methods:
- **terraform**: Use Terraform (recommended)
- **arm**: Use ARM templates
- **both**: Try Terraform first, fallback to ARM

#### Additional Options:
- **Force PowerShell**: Alternative deployment method
- **Reset Database**: ⚠️ **WARNING** - Destroys all Zabbix data
- **Environment Suffix**: Optional suffix for resource names
- **Debug Mode**: Enable detailed logging

### Option 2: Automatic Deployment on Push

The workflow automatically triggers on pushes to `main` or `develop` branches when files in these paths change:
- `infra/**`
- `k8s/**`
- `.github/workflows/**`

## Resource Group Configuration

The workflow is currently configured to deploy to:
- **Resource Group**: `rg-devops-pops-eastus`
- **Location**: `eastus`
- **Subscription**: `d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf`

## Post-Deployment Access

After successful deployment, you can access Zabbix via:

1. **LoadBalancer IP**: Check the deployment logs for the external IP
2. **Ingress**: Configure DNS for `dal2-devmon-mgt.forescout.com`

### Default Credentials:
- **Username**: `Admin`
- **Password**: `zabbix`

⚠️ **Security Note**: Change the default password immediately after first login.

## Troubleshooting

### Common Issues:

1. **Authentication Failed**
   - Verify `AZURE_CREDENTIALS` secret is properly formatted
   - Ensure Service Principal has `Contributor` role on the subscription

2. **Resource Group Not Found**
   - The workflow will create the resource group if it doesn't exist
   - Ensure Service Principal has permissions to create resource groups

3. **Terraform State Issues**
   - The workflow includes import logic for existing resources
   - For clean deployment, use `redeploy-clean` option

4. **AKS Connection Issues**
   - Check if AKS cluster was created successfully
   - Verify network security group rules allow required ports

### Monitoring Deployment:

1. Go to **Actions** tab in GitHub
2. Click on the running workflow
3. Monitor each job's progress
4. Check logs for detailed information

### Manual Intervention:

If deployment fails, you can:

1. Check the workflow logs for specific error messages
2. Re-run the workflow with different parameters
3. Use Azure CLI locally for troubleshooting:

```bash
# Connect to AKS cluster
az aks get-credentials --resource-group rg-devops-pops-eastus --name <cluster-name>

# Check cluster status
kubectl get nodes
kubectl get pods -A
```

## Security Considerations

1. **Change default passwords** immediately after deployment
2. **Configure HTTPS** with proper SSL certificates
3. **Restrict network access** using NSG rules
4. **Enable Azure Monitor** for logging and alerting
5. **Regularly update** Zabbix and Kubernetes versions

## Support

For deployment issues:
1. Check the GitHub Actions logs
2. Review the troubleshooting documentation in this repository
3. Verify Azure resource status in Azure Portal
