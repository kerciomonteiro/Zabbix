# Zabbix Deployment Recovery Guide

## 🚨 Before You Delete the AKS Cluster

**STOP!** Most Zabbix deployment issues can be fixed without cluster deletion. Cluster deletion should be the **absolute last resort**.

### 🔧 Quick Fixes (Try These First)

#### 1. Run the Comprehensive Fix Script
```bash
# This fixes 90%+ of Zabbix deployment issues
./scripts/terraform/post-deployment-zabbix-fix.sh
```

**What it fixes:**
- ✅ Missing Zabbix web frontend (most common issue)
- ✅ Uninitialized database schema
- ✅ Misconfigured Application Gateway backends
- ✅ Pod connectivity issues

#### 2. Check What's Actually Failing
```bash
# Get the real status of your deployment
kubectl get pods -n zabbix
kubectl get services -n zabbix
kubectl logs -n zabbix deployment/zabbix-server --tail=50
```

#### 3. Fix Terraform Import Conflicts
```bash
# If you're seeing "resource already exists" errors
./scripts/terraform/resolve-k8s-conflicts.sh
```

#### 4. Diagnose Specific Issues
```bash
# Check Application Gateway health
az network application-gateway show-backend-health \
  --name appgw-devops-eastus \
  --resource-group rg-devops-pops-eastus

# Check database connectivity
kubectl exec -n zabbix deployment/zabbix-server -- mysql -h zabbix-mysql -u root -pZabbixRoot123! -e "SHOW DATABASES;"

# Check for version compatibility issues
kubectl get deployment zabbix-server -n zabbix -o jsonpath='{.spec.template.spec.containers[0].image}'
kubectl get deployment zabbix-web -n zabbix -o jsonpath='{.spec.template.spec.containers[0].image}'
```

#### 5. Fix Version Compatibility Issues
If you see "database version does not match current requirements":
```bash
# Check current versions
kubectl get deployments -n zabbix -o custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image

# Update Zabbix server to version 6.0 (if using 5.4)
kubectl patch deployment zabbix-server -n zabbix -p '{"spec":{"template":{"spec":{"containers":[{"name":"zabbix-server","image":"zabbix/zabbix-server-mysql:6.0-alpine-latest"}]}}}}'

# Wait for rollout
kubectl rollout status deployment/zabbix-server -n zabbix
```

### 🚨 Common Issues and Quick Solutions

| Issue | Symptoms | Quick Fix |
|-------|----------|-----------|
| **Missing Web Frontend** | 502 Bad Gateway, no zabbix-web pods | Run fix script (deploys missing frontend) |
| **Database Version Mismatch** | "database version does not match" error | Fix script updates Zabbix server to matching version |
| **Database Not Initialized** | Zabbix server crashes, empty tables | Fix script initializes schema (166+ tables) |
| **Application Gateway Misconfigured** | 502/503 errors, unhealthy backends | Fix script updates backend pool with correct IPs |
| **Pod Crash Loop** | CrashLoopBackOff status | Check logs, usually database connection issue |
| **Terraform Import Errors** | "Resource already exists" | Run resolve-k8s-conflicts script |

### 🛡️ Prevention (Add This to Your Workflow)

To prevent future issues, add this step to your `.github/workflows/deploy.yml`:

```yaml
- name: Verify and Fix Zabbix Deployment
  if: success()
  run: |
    az aks get-credentials --resource-group rg-devops-pops-eastus --name aks-devops-eastus --overwrite-existing
    sleep 30  # Wait for cluster stability
    chmod +x ./scripts/terraform/post-deployment-zabbix-fix.sh
    ./scripts/terraform/post-deployment-zabbix-fix.sh
  shell: bash
```

## 🗑️ When Cluster Deletion is Actually Needed

Only delete the cluster if:

1. **AKS cluster is in "Failed" provisioning state**
   - Check with: `az aks show --name aks-devops-eastus --resource-group rg-devops-pops-eastus`
   - Status shows `"provisioningState": "Failed"`

2. **Complete infrastructure corruption**
   - Nodes are unreachable
   - Kubernetes API is unresponsive
   - Multiple Azure resources are in failed state

3. **You've tried all fix scripts and they fail**
   - Post-deployment fix script failed
   - Manual recovery attempts failed
   - Cluster is genuinely unrecoverable

## 🚀 Recovery After Cluster Deletion

If you must delete and recreate:

### 1. Immediate Steps After Deletion
```bash
# 1. Re-run the GitHub Actions deployment
# 2. Wait for cluster to be created
# 3. Immediately run the fix script
./scripts/terraform/post-deployment-zabbix-fix.sh
```

### 2. Verify Complete Recovery
```bash
# Check all components are healthy
kubectl get pods -n zabbix
curl -I http://dal2-devmon-mgt-devops.eastus.cloudapp.azure.com/
```

### 3. Update Your Workflow
Add the automated fix step to prevent this happening again.

## 📋 Success Metrics

After recovery, you should see:

```bash
✅ All pods running (1/1 Ready)
✅ All services created
✅ Application Gateway backends healthy
✅ Zabbix URL returns HTTP 200
✅ Login page accessible
```

## 🆘 Emergency Contacts

If all else fails:
- Review logs in `kubectl logs` and Azure Portal
- Check Azure Service Health for regional issues
- Consider infrastructure team escalation
- Document the issue for future prevention

---

**Remember: The goal is to prevent cluster deletion entirely by fixing issues proactively!**
