# Zabbix Deployment Fix Scripts

This directory contains scripts to prevent and fix Zabbix deployment issues that could occur after AKS cluster recreation or failed deployments.

## Problem Solved

The original issue was that after AKS cluster creation, only the Zabbix MySQL database and server were deployed, but the **Zabbix web frontend was missing**. This caused:

- ❌ 502 Bad Gateway errors when accessing the Zabbix URL
- ❌ Application Gateway had no healthy backend servers
- ❌ Incomplete Zabbix stack deployment

## Solution Overview

The fix scripts ensure a complete Zabbix deployment by:

1. ✅ **Verifying all three Zabbix components are deployed:**
   - `zabbix-mysql` (Database)
   - `zabbix-server` (Backend server)
   - `zabbix-web` (Web frontend) ← **This was missing**

2. ✅ **Checking and initializing the database schema**
3. ✅ **Configuring Application Gateway with correct backend IPs and ports**
4. ✅ **Ensuring all health checks pass**

## Files

### 1. `post-deployment-zabbix-fix.sh` (Bash)
Main fix script for Linux/WSL environments.

**Usage:**
```bash
chmod +x ./scripts/terraform/post-deployment-zabbix-fix.sh
./scripts/terraform/post-deployment-zabbix-fix.sh
```

### 2. `post-deployment-zabbix-fix.ps1` (PowerShell)
PowerShell version for Windows environments.

**Usage:**
```powershell
./scripts/terraform/post-deployment-zabbix-fix.ps1
```

### 3. `emergency-aks-delete.sh` (Updated)
Enhanced emergency deletion script that now references the fix scripts.

**Usage:**
```bash
./scripts/terraform/emergency-aks-delete.sh
# After cluster recreation, run:
./scripts/terraform/post-deployment-zabbix-fix.sh
```

### 4. `github-actions-zabbix-fix.yml`
GitHub Actions workflow step to automatically run the fix after deployment.

**Integration:** Add this step to your `.github/workflows/deploy.yml` file after the Terraform apply step.

## When to Use

### Automatic (Recommended)
- **GitHub Actions Integration**: Add the workflow step to automatically run after every deployment
- **CI/CD Pipeline**: Integrate into your deployment pipeline

### Manual
- **After AKS cluster recreation**
- **When seeing 502 Bad Gateway errors**
- **After any failed Zabbix deployment**
- **As a health check for existing deployments**

## What the Scripts Do

### 1. Component Verification
```bash
# Checks for missing deployments and creates them
✓ zabbix-mysql deployment exists and running
✓ zabbix-server deployment exists and running  
✓ zabbix-web deployment exists and running (often missing)
```

### 2. Database Schema Initialization
```bash
# Ensures database has proper Zabbix schema
✓ 166+ tables created
✓ Default admin users present
✓ Proper character set (utf8)
```

### 3. Application Gateway Configuration
```bash
# Updates Application Gateway to route to Zabbix web pods
✓ Backend pool contains Zabbix web pod IPs
✓ HTTP settings use port 8080 (container port)
✓ Health probes return "Healthy" status
```

### 4. Final Verification
```bash
# Confirms complete working stack
✓ All pods running (1/1 or 2/2 Ready)
✓ All services created and accessible
✓ Application Gateway backends healthy
```

## Expected Results

After running the fix script:

```
🎉 SUCCESS: Complete Zabbix stack is operational!

🌐 Your Zabbix installation should now be accessible at:
   http://dal2-devmon-mgt-devops.eastus.cloudapp.azure.com/

📝 Default login credentials:
   Username: Admin
   Password: zabbix
```

## Troubleshooting

If the script fails:

1. **Check kubectl connectivity:**
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```

2. **Verify namespace exists:**
   ```bash
   kubectl get namespace zabbix
   ```

3. **Check individual components:**
   ```bash
   kubectl get pods -n zabbix
   kubectl get services -n zabbix
   kubectl logs -n zabbix deployment/zabbix-web
   ```

4. **Verify Azure CLI:**
   ```bash
   az account show
   az network application-gateway show-backend-health \
     --name appgw-devops-eastus \
     --resource-group rg-devops-pops-eastus
   ```

## Prevention

To prevent this issue in the future:

1. **Add to CI/CD**: Include the fix script in your deployment pipeline
2. **Infrastructure as Code**: Ensure all Zabbix manifests are applied during deployment
3. **Health Checks**: Run the verification script after any cluster changes
4. **Documentation**: Keep this README updated with any environment changes

## Configuration

The scripts use these default values (can be modified):

```bash
NAMESPACE="zabbix"
RESOURCE_GROUP="rg-devops-pops-eastus"
APP_GATEWAY_NAME="appgw-devops-eastus"
SUBSCRIPTION_ID="d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"
```

For different environments, either:
- Modify the values in the script, or
- Pass parameters (PowerShell version supports parameters)

## Security Notes

- Database credentials are hardcoded (change after deployment)
- Default Zabbix admin password is "zabbix" (change immediately)
- Scripts have necessary Azure permissions through service principal

## Support

If you encounter issues:

1. Check the [troubleshooting section](#troubleshooting) above
2. Review the script logs and error messages
3. Verify all prerequisites (kubectl, Azure CLI, permissions)
4. Test individual components manually

The scripts are idempotent - safe to run multiple times.
