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
