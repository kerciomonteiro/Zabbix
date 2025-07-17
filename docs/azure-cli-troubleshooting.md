# Azure CLI and Bicep Deployment Troubleshooting Guide

This guide covers common Azure CLI and Bicep deployment errors and their solutions, particularly for the persistent "content already consumed" error.

## Critical Error: "The content for this response was already consumed"

### Problem Description
This error occurs when Azure CLI attempts to read an HTTP response stream that has already been processed. It's often related to:
- Network connectivity issues
- Azure CLI internal buffer management
- Concurrent requests or authentication token conflicts
- Azure CLI version bugs

### Solutions Implemented

#### 1. Retry Logic with Exponential Backoff
The workflow now includes retry logic that:
- Attempts deployment up to 3 times
- Uses exponential backoff (30s, 60s, 120s)
- Clears Azure CLI cache between attempts
- Uses fresh deployment names to avoid conflicts

#### 2. Azure CLI Cache Management
```bash
# Clear CLI cache before retry
rm -rf ~/.azure/azureProfile.json ~/.azure/clouds.config 2>/dev/null || true
```

#### 3. Timeout Management
```bash
# Set deployment timeout (30 minutes)
timeout 1800 az deployment group create ...
```

#### 4. Alternative HTTP User Agent
```bash
export AZURE_HTTP_USER_AGENT="GitHub-Actions-Zabbix-Deploy"
```

#### 5. Incremental Deployment Mode
```bash
--mode Incremental
```

#### 6. Minimal Output Options
```bash
--only-show-errors
```

### Fallback Strategy
The deployment uses a cascade of methods:
1. **Azure Developer CLI (AZD)** - Primary method
2. **Azure CLI with retry logic** - First fallback
3. **Azure PowerShell** - Final fallback

## Other Common Errors and Solutions

### Error: "No subscriptions found"
**Cause**: Authentication issue or insufficient permissions
**Solution**:
```bash
az account show
az account set --subscription "your-subscription-id"
```

### Error: "Invalid authentication type"
**Cause**: Service principal authentication problems
**Solution**:
1. Verify AZURE_CREDENTIALS secret format
2. Check service principal permissions
3. Ensure subscription ID is correct

### Error: "Resource provider not registered"
**Cause**: Required Azure resource providers not enabled
**Solution**:
```bash
az provider register --namespace Microsoft.ContainerService --wait
az provider register --namespace Microsoft.Network --wait
az provider register --namespace Microsoft.ContainerRegistry --wait
```

### Error: "Resource name conflicts"
**Cause**: Resource names not globally unique
**Solution**:
- Use resource tokens for unique naming
- Check name availability before deployment
- Use timestamp-based deployment names

### Error: "Deployment validation failed"
**Cause**: Template errors or parameter issues
**Solution**:
```bash
# Validate template first
az deployment group what-if --resource-group "rg-name" --template-file main.bicep
az deployment group validate --resource-group "rg-name" --template-file main.bicep
```

## Diagnostic Commands

### Check Azure CLI Version and Status
```bash
az version
az account show
az account list-locations --output table
```

### Verify Resource Group Access
```bash
az group show --name "your-resource-group" --output table
```

### Check Resource Provider Status
```bash
az provider list --query "[?registrationState=='Registered']" --output table
```

### Test Bicep Template
```bash
az bicep build --file main.bicep --stdout
az deployment group what-if --resource-group "rg" --template-file main.bicep
```

## Prevention Strategies

### 1. Template Best Practices
- Always use resource tokens for unique naming
- Include proper parameter validation
- Use conditional resource creation
- Implement proper tagging strategy

### 2. Authentication Best Practices
- Use service principals for CI/CD
- Implement proper secret rotation
- Use minimal required permissions
- Enable audit logging

### 3. Deployment Best Practices
- Always run what-if analysis first
- Use incremental deployment mode
- Implement proper error handling
- Use structured logging

### 4. Network Considerations
- Ensure stable internet connectivity
- Consider using Azure DevOps agents in Azure
- Implement timeout and retry logic
- Monitor Azure service health

## Monitoring and Debugging

### Enable Verbose Logging
```bash
export AZURE_CLI_ENABLE_TRACE=1
az deployment group create ... --verbose --debug
```

### PowerShell Alternative
```powershell
# Install and use Azure PowerShell as alternative
Install-Module -Name Az -Force
Connect-AzAccount -ServicePrincipal -Credential $cred
New-AzResourceGroupDeployment -ResourceGroupName "rg" -TemplateFile "main.bicep"
```

### GitHub Actions Debugging
```yaml
- name: Enable debug logging
  run: |
    echo "ACTIONS_STEP_DEBUG=true" >> $GITHUB_ENV
    echo "ACTIONS_RUNNER_DEBUG=true" >> $GITHUB_ENV
```

## Emergency Procedures

### If All Automated Methods Fail
1. **Manual Azure Portal Deployment**:
   - Download Bicep template
   - Use Azure Portal custom deployment
   - Upload template and parameters

2. **Azure Cloud Shell Deployment**:
   - Use Azure Cloud Shell in portal
   - Clone repository
   - Run deployment manually

3. **Local Deployment with Azure CLI**:
   - Install Azure CLI locally
   - Authenticate with service principal
   - Run deployment from local machine

### Rollback Procedures
```bash
# Delete failed deployment
az deployment group delete --resource-group "rg" --name "deployment-name"

# Clean up partial resources
az resource list --resource-group "rg" --output table
az resource delete --ids "/subscriptions/.../resourceGroups/rg/providers/..."
```

## Contact and Support

For persistent issues:
1. Check Azure Status: https://status.azure.com/
2. Review Azure CLI GitHub issues
3. Consider opening Azure support ticket
4. Check regional service availability

## Version Information

- Azure CLI: Latest stable (updated in workflow)
- Bicep: Latest (auto-updated with Azure CLI)
- PowerShell: 7.x (installed in workflow)
- AZD: Latest stable (fallback installation)

Last updated: January 2025

## ARM Templates vs Bicep

**Question: Should I use ARM templates instead of Bicep?**

Both approaches are included in the deployment workflow:

### Bicep Templates (Primary)
- **Advantages**: Cleaner syntax, better readability, better tooling support
- **Used by**: Azure CLI fallback method
- **Location**: `infra/main.bicep`

### ARM Templates (Alternative)
- **Advantages**: JSON format, sometimes better compatibility with certain Azure CLI versions
- **Used by**: ARM template fallback method
- **Location**: `infra/main-arm.json`

### Deployment Cascade
The workflow attempts deployment in this order:
1. **Azure Developer CLI (AZD)** with Bicep - Primary method
2. **Azure CLI with Bicep** - First fallback (with retry logic)
3. **ARM template with Azure CLI** - Alternative fallback 
4. **Azure PowerShell with Bicep** - Final fallback

### When to Use ARM vs Bicep
- **Bicep is recommended** for most scenarios (cleaner, modern)
- **ARM templates** can be useful when:
  - Bicep compilation has issues
  - Specific Azure CLI versions have Bicep bugs
  - JSON format is preferred for tooling compatibility

### Authentication Error Resolution
The **"Please run 'az login' to setup account"** error is now handled by:
- **Smart re-authentication**: Automatically detects auth loss and re-authenticates
- **Selective cache clearing**: Only clears problematic cache files, preserves auth tokens
- **Multiple fallback methods**: If one method fails, others will attempt with fresh auth

### Current Enhancement Features
✅ **Authentication persistence**: Maintains login across retry attempts  
✅ **Selective cache management**: Avoids breaking authentication  
✅ **Multiple template formats**: Both Bicep and ARM available  
✅ **Enhanced retry logic**: 3 attempts with exponential backoff  
✅ **PowerShell alternative**: Uses completely different Azure SDK  

The workflow is now highly resilient and should handle most authentication and deployment issues automatically.
