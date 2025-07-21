# Zabbix Deployment Recovery Guide (PowerShell)

## 🚨 Quick Recovery Commands for Windows/PowerShell Users

### 🔧 Primary Fix (Solves 90%+ of Issues)
```powershell
# Run the comprehensive Zabbix fix script
./scripts/terraform/post-deployment-zabbix-fix.ps1
```

### 🔍 Diagnose Issues First
```powershell
# Check what's actually failing
kubectl get pods -n zabbix
kubectl get services -n zabbix
kubectl logs -n zabbix deployment/zabbix-server --tail=50

# Check Application Gateway health
az network application-gateway show-backend-health `
  --name appgw-devops-eastus `
  --resource-group rg-devops-pops-eastus
```

### 🛠️ Fix Terraform Import Issues
```powershell
# Convert and run the import script
# (First convert resolve-k8s-conflicts.sh to PowerShell or use WSL)
wsl ./scripts/terraform/resolve-k8s-conflicts.sh
```

### 🚀 Emergency Cluster Deletion (Last Resort)
```powershell
# Only if cluster is truly failed and unfixable
./scripts/terraform/emergency-aks-delete.sh
```

### 🛡️ Prevention - Add to GitHub Actions
Add this step to your `.github/workflows/deploy.yml`:

```yaml
- name: Verify and Fix Zabbix Deployment (PowerShell)
  if: success() && runner.os == 'Windows'
  run: |
    az aks get-credentials --resource-group rg-devops-pops-eastus --name aks-devops-eastus --overwrite-existing
    Start-Sleep -Seconds 30
    ./scripts/terraform/post-deployment-zabbix-fix.ps1
  shell: pwsh
```

## 📋 Success Check
```powershell
# Verify everything is working
kubectl get pods -n zabbix
Invoke-RestMethod -Uri "http://dal2-devmon-mgt-devops.eastus.cloudapp.azure.com/" -Method Head
```

## 🆘 When All Else Fails
1. Check the full recovery guide: `./scripts/terraform/RECOVERY-GUIDE.md`
2. Use WSL for bash scripts: `wsl ./scripts/terraform/post-deployment-zabbix-fix.sh`
3. Run individual kubectl/az commands to isolate the issue

**Remember: Always try the fix script before considering cluster deletion!**
