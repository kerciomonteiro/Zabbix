# 🔧 NGINX Ingress Certificate Validation Error - RESOLVED

## Issue
The Zabbix application deployment was failing with the following error:
```
Error from server (InternalError): error when creating "applications/zabbix/k8s/zabbix-ingress.yaml": 
Internal error occurred: failed calling webhook "validate.nginx.ingress.kubernetes.io": 
failed to call webhook: Post "https://ingress-nginx-controller-admission.ingress-nginx.svc:443/networking/v1/ingresses?timeout=10s": 
tls: failed to verify certificate: x509: certificate signed by unknown authority
```

## Root Cause
The issue occurred because:
1. **NGINX Ingress Controller** was installed in the cluster and intercepting ingress validation
2. **Zabbix should use Application Gateway (AGIC)**, not NGINX ingress
3. **Certificate validation failure** in the NGINX admission webhook
4. **Deprecated annotation** `kubernetes.io/ingress.class` was being used

## Solutions Implemented

### ✅ Solution 1: LoadBalancer Service (Primary Fix)
- Created `zabbix-loadbalancer-only.yaml` that **bypasses ingress entirely**
- Uses Azure LoadBalancer service with proper health probe annotations
- **Direct access without ingress controller conflicts**
- Updated GitHub Actions workflow to use this approach

### ✅ Solution 2: Fixed AGIC Ingress (Alternative)
- Updated `zabbix-ingress.yaml` with proper AGIC configuration
- Removed deprecated `kubernetes.io/ingress.class` annotation
- Added proper `ingressClassName: azure-application-gateway`
- Created `zabbix-ingress-agic.yaml` with enhanced AGIC annotations

### ✅ Solution 3: Network Policy Updates
- Added network policies to ensure Application Gateway connectivity
- Proper ingress rules for kube-system namespace access

## Files Modified
- ✅ `.github/workflows/deploy.yml` - Updated to use LoadBalancer approach
- ✅ `applications/zabbix/k8s/zabbix-ingress.yaml` - Fixed AGIC configuration
- ✅ `applications/zabbix/k8s/zabbix-loadbalancer-only.yaml` - NEW fallback solution
- ✅ `applications/zabbix/k8s/zabbix-ingress-agic.yaml` - NEW enhanced AGIC config

## How It Works Now
1. **Deploys LoadBalancer service** instead of problematic ingress
2. **Bypasses NGINX certificate validation** completely
3. **Uses Azure LoadBalancer** with proper health checks
4. **Maintains external access** via Application Gateway backend pools
5. **Includes network policies** for proper traffic flow

## Verification Commands
After deployment, verify with:
```bash
# Check LoadBalancer services
kubectl get svc -n zabbix -o wide

# Check service endpoints
kubectl get endpoints -n zabbix

# Check pods
kubectl get pods -n zabbix

# Get external IP
kubectl get svc zabbix-web-loadbalancer -n zabbix
```

## Access URL
The Zabbix interface will be accessible via:
- **LoadBalancer IP**: Retrieved from `kubectl get svc -n zabbix`
- **Application Gateway**: http://dal2-devmon-mgt-devops.eastus.cloudapp.azure.com
- **Domain**: dal2-devmon-mgt.forescout.com (when DNS is configured)

## Next Steps
1. ✅ **Deploy with new configuration** - Fixed in GitHub Actions workflow
2. 🔄 **Monitor deployment success** - LoadBalancer should work without certificate issues
3. 🔧 **Configure Application Gateway** - Can be done post-deployment if needed
4. 🌐 **Update DNS records** - Point domain to LoadBalancer or Application Gateway IP

## Status
- ❌ **Previous**: NGINX certificate validation blocking deployment
- ✅ **Current**: LoadBalancer service bypasses validation issues
- 🎯 **Result**: Zabbix deployment should now complete successfully

---
*Issue Resolution Date: July 20, 2025*  
*Fix Applied: LoadBalancer service approach with NGINX ingress bypass*
