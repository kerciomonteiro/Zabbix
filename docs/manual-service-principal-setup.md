# Manual Azure Service Principal Setup for GitHub Actions

Since your account doesn't have permissions to create service principals via Azure CLI, you'll need to either:

1. **Request assistance from your Azure administrator**, or
2. **Use the Azure Portal method** (if you have the necessary permissions)

## Option 1: Azure Portal Setup (Recommended)

### Step 1: Create App Registration

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Microsoft Entra ID** > **App registrations**
3. Click **New registration**
4. Fill in the details:
   - **Name**: `github-actions-zabbix-deployment`
   - **Supported account types**: Accounts in this organizational directory only
   - **Redirect URI**: Leave blank
5. Click **Register**

### Step 2: Create Client Secret

1. In your app registration, go to **Certificates & secrets**
2. Click **New client secret**
3. Add description: `GitHub Actions Secret`
4. Set expiration: `24 months` (or according to your policy)
5. Click **Add**
6. **Copy the secret value immediately** (you won't be able to see it again)

### Step 3: Get Required Values

From your app registration overview page, copy these values:
- **Application (client) ID**
- **Directory (tenant) ID**

Your subscription ID is: `d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf`

### Step 4: Assign Permissions

1. Go to **Subscriptions** or **Resource Groups** 
2. Navigate to your subscription or the `Devops-Test` resource group
3. Click **Access control (IAM)**
4. Click **Add** > **Add role assignment**
5. Select **Contributor** role
6. Select **User, group, or service principal**
7. Search for `github-actions-zabbix-deployment` and select it
8. Click **Review + assign**

### Step 5: Configure GitHub Secrets

In your GitHub repository, go to **Settings** > **Secrets and variables** > **Actions**

Add this repository secret:

| Secret Name | Value |
|-------------|--------|
| `AZURE_CREDENTIALS` | JSON object with service principal details (see format below) |

**AZURE_CREDENTIALS JSON Format:**
```json
{
  "clientId": "Application (client) ID from Step 3",
  "clientSecret": "Client secret value from Step 2",
  "subscriptionId": "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf",
  "tenantId": "Directory (tenant) ID from Step 3"
}
```

**Example:**
```json
{
  "clientId": "12345678-1234-1234-1234-123456789012",
  "clientSecret": "your-client-secret-value",
  "subscriptionId": "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf",
  "tenantId": "87654321-4321-4321-4321-210987654321"
}
```

## Option 2: Request Administrator Assistance

If you don't have permissions for the above steps, contact your Azure administrator with this information:

### Request Details:
- **Purpose**: GitHub Actions deployment for Zabbix monitoring infrastructure
- **Required Service Principal Name**: `github-actions-zabbix-deployment`
- **Required Permissions**: `Contributor` role on Resource Group `Devops-Test`
- **Subscription ID**: `d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf`
- **Resource Group**: `Devops-Test`

### Information Needed from Administrator:
1. Application (client) ID
2. Directory (tenant) ID  
3. Client secret value

Once you have these values, add them as a GitHub secret as described in Step 5 above.

## Option 3: Use Federated Identity (Most Secure)

For enhanced security, you can set up Federated Identity instead of using secrets. This approach doesn't require storing client secrets.

### Step 1: Configure Federated Credential

1. In your app registration, go to **Certificates & secrets**
2. Click **Federated credentials** tab
3. Click **Add credential**
4. Select **GitHub Actions deploying Azure resources**
5. Fill in:
   - **Organization**: Your GitHub username/organization
   - **Repository**: Repository name
   - **Entity type**: Branch
   - **GitHub branch name**: `main`
   - **Name**: `github-actions-main`

### Step 2: Update GitHub Actions Workflow

If using federated identity, update the Azure login step to:

```yaml
- name: Azure CLI Login
  uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

You'll need these GitHub secrets:
- `AZURE_CLIENT_ID`: Application (client) ID
- `AZURE_TENANT_ID`: Directory (tenant) ID  
- `AZURE_SUBSCRIPTION_ID`: `d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf`

You won't need the `AZURE_CLIENT_SECRET` in this case.

## Verification

After setting up the service principal and GitHub secrets, you can test the connection by running the GitHub Actions workflow or by manually triggering it from the Actions tab.

The workflow will automatically deploy your AKS infrastructure and Zabbix application.

## Troubleshooting

### Error: "No subscriptions found"

If you get this error during GitHub Actions deployment, it means the service principal exists but lacks proper permissions.

**Solution 1: Fix Role Assignment at Subscription Level**
1. Go to Azure Portal → Subscriptions
2. Select subscription `On-Prem-Dlv-DevOps` (d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf)
3. Click "Access control (IAM)"
4. Click "Add" → "Add role assignment"
5. Select "Contributor" role → Next
6. Select "User, group, or service principal"
7. Search for "github-actions-zabbix-deployment"
8. Select your service principal → Next → Review + assign

**Solution 2: Resource Group Level Access (Alternative)**
1. Go to Azure Portal → Resource groups
2. Select "Devops-Test" resource group
3. Follow steps 3-8 from Solution 1

**Solution 3: Admin Request Template**
Send this to your Azure administrator:

```
Subject: Service Principal Role Assignment Request

Hi [Admin Name],

I need help assigning permissions to a service principal for automated deployment.

Details:
- Service Principal Name: github-actions-zabbix-deployment
- Application ID: [Your App ID from Azure Portal]
- Required Role: Contributor
- Scope: Subscription "On-Prem-Dlv-DevOps" (d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf)
- Alternative Scope: Resource Group "Devops-Test"
- Purpose: GitHub Actions deployment for Zabbix monitoring infrastructure

Please assign the Contributor role to this service principal at either the subscription or resource group level.

Thank you!
```

### Error: "Invalid authentication type"

This usually means the AZURE_CREDENTIALS JSON format is incorrect. Ensure it follows this exact format:

```json
{
  "clientId": "your-application-client-id",
  "clientSecret": "your-client-secret-value", 
  "subscriptionId": "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf",
  "tenantId": "your-tenant-id"
}
```

Make sure:
- No extra spaces or line breaks
- All IDs are complete GUIDs
- Client secret is the actual secret value, not the secret ID
- All fields are enclosed in double quotes

### Error: "getaddrinfo ENOTFOUND azdrelease.azureedge.net"

This error occurs when GitHub Actions can't download the Azure Developer CLI due to network connectivity issues.

**Solution**: The workflow now includes automatic fallback methods:

1. **First**: Tries the official AZD installation via aka.ms
2. **Second**: Tries package manager installation  
3. **Third**: Falls back to Azure CLI direct Bicep deployment

If you continue to see this error, the workflow will automatically use Azure CLI for deployment instead of AZD. This provides the same functionality but doesn't require the AZD tool.

**Manual workaround** (if needed):
- Re-run the workflow (the network issue is often temporary)
- The fallback Azure CLI method should work even if AZD installation fails

### Error: AZD Environment Name Validation

If you see errors about invalid environment names or AZD hanging on environment setup, this indicates an issue with AZD environment initialization.

**Solution**: The workflow now properly initializes AZD environments non-interactively:

1. Creates a unique environment name using the GitHub run number
2. Initializes the environment with proper location and subscription
3. Automatically falls back to Azure CLI if AZD initialization fails

**Region Setting**: All deployments are configured for **East US (eastus)** region.

If AZD continues to fail, the workflow will automatically use the Azure CLI fallback method.
