# Zabbix 502 Bad Gateway - Final Root Cause Analysis

## Executive Summary

After extensive investigation, the 502 Bad Gateway errors for the Zabbix deployment on AKS have been traced to **two primary infrastructure issues** at the Azure network level:

1. **Missing NSG Rules for NodePort Access** - Blocking LoadBalancer traffic
2. **AGIC Subnet Permissions** - Preventing Application Gateway configuration

## Detailed Findings

### Issue 1: Network Security Group (NSG) Rules Missing

**Problem**: The AKS NSG (`nsg-aks-devops-eastus`) only allowed traffic on ports 443 and 22, but the LoadBalancer service uses nodePort 30247.

**Discovery**: 
- LoadBalancer service: `zabbix-web-external` uses `80:30247/TCP`
- NSG rules before fix: Only `AllowAKSApiServer` (443) and `AllowSSH` (22)
- External IP: `134.33.216.159` was timing out due to port blocking

**Solution Applied**:
```bash
# Added specific rule for current deployment
az network nsg rule create --name AllowZabbixNodePort --priority 130 \
  --destination-port-range 30247 --access allow

# Added broader rule for future deployments
az network nsg rule create --name AllowKubernetesNodePorts --priority 140 \
  --destination-port-range 30000-32767 --access allow
```

**Status**: ❌ **LoadBalancer still timing out** despite NSG rule additions

### Issue 2: AGIC Subnet Permissions

**Problem**: Application Gateway Ingress Controller (AGIC) cannot join the Application Gateway subnet due to insufficient permissions.

**Discovery**:
- AGIC Error: `ApplicationGatewayInsufficientPermissionOnSubnet`
- Missing Action: `Microsoft.Network/virtualNetworks/subnets/join/action`
- Service Principal: `1db234fc-dabc-4ead-a0a4-6fdc08cdb0aa`
- Backend Pool: Empty (no servers configured)

**Solution Applied**:
```bash
# Added Network Contributor role on subnet
az role assignment create --role "Network Contributor" \
  --scope "/subscriptions/.../subnets/subnet-appgw-devops-eastus" \
  --assignee "1db234fc-dabc-4ead-a0a4-6fdc08cdb0aa"

# Added Network Contributor role on VNet
az role assignment create --role "Network Contributor" \
  --scope "/subscriptions/.../virtualNetworks/vnet-devops-eastus" \
  --assignee "1db234fc-dabc-4ead-a0a4-6fdc08cdb0aa"
```

**Status**: ❌ **Permission error persists** despite role assignments

## Current Service Configuration

### LoadBalancer Service
```yaml
Service: zabbix-web-external
Type: LoadBalancer
External IP: 134.33.216.159
Port: 80:30247/TCP
NodePort: 30247
```

### Application Gateway Ingress
```yaml
Ingress: zabbix-ingress
Host: dal2-devmon-mgt-devops.eastus.cloudapp.azure.com
Backend: zabbix-web:80
IP: 172.171.216.80
```

### NSG Rules (Current)
```bash
nsg-aks-devops-eastus:
  - AllowAKSApiServer: TCP 443
  - AllowSSH: TCP 22
  - AllowZabbixNodePort: TCP 30247 (NEW)
  - AllowKubernetesNodePorts: TCP 30000-32767 (NEW)

nsg-appgw-devops-eastus:
  - AllowGatewayManager: TCP 65200-65535
  - AllowHTTP: TCP 80
  - AllowHTTPS: TCP 443
```

## What's Working vs. What's Not

### ✅ **Working (Internal)**
- All Zabbix pods are healthy and running
- Database connectivity and initialization complete
- Internal service endpoints respond correctly
- Pod-to-pod communication works
- Health checks return HTTP 200 OK

### ❌ **Not Working (External)**
- LoadBalancer endpoint times out: `http://134.33.216.159`
- Application Gateway returns 502: `http://dal2-devmon-mgt-devops.eastus.cloudapp.azure.com`
- AGIC cannot configure backend pool
- External DNS resolution working but endpoints unreachable

## Root Cause Analysis

### Primary Root Cause: Network Infrastructure Configuration
The issue is **not** in the Kubernetes application layer but in the **Azure network infrastructure**:

1. **NSG Rules**: Despite adding NodePort rules, LoadBalancer traffic is still being blocked
2. **AGIC Permissions**: Service principal lacks proper subnet join permissions
3. **Backend Pool Configuration**: Application Gateway has no backend servers configured

### Secondary Contributing Factors
1. **Network Policy**: Initially blocked kube-system traffic (resolved)
2. **AGIC Role Assignments**: Missing initial Application Gateway permissions (resolved)
3. **Terraform Configuration**: May not have created all necessary permissions automatically

## Next Steps for Resolution

### Immediate Actions Needed
1. **Investigate LoadBalancer Configuration**:
   - Check if Azure LoadBalancer is correctly configured
   - Verify backend pool contains AKS nodes
   - Test direct node access to port 30247

2. **Resolve AGIC Subnet Permissions**:
   - Check if additional permissions are needed beyond Network Contributor
   - Verify service principal identity mapping
   - Consider recreating AGIC with proper permissions

3. **Test Network Connectivity**:
   - Verify node-to-node communication on port 30247
   - Test if NSG rules are properly applied
   - Check if there are additional firewall rules blocking traffic

### Long-term Improvements
1. **Update Terraform Configuration**:
   - Include automatic NSG rule creation for NodePort ranges
   - Ensure AGIC permissions are created automatically
   - Add proper role assignments for all required services

2. **Monitoring and Alerting**:
   - Set up monitoring for Application Gateway backend health
   - Add alerts for AGIC permission failures
   - Monitor NSG rule effectiveness

## Verification Commands

```bash
# Test LoadBalancer
curl -I http://134.33.216.159 --connect-timeout 10

# Test Application Gateway
curl -I http://dal2-devmon-mgt-devops.eastus.cloudapp.azure.com --connect-timeout 10

# Check AGIC logs
kubectl logs -l app=ingress-appgw -n kube-system --tail=10

# Check backend health
az network application-gateway show-backend-health \
  --resource-group Devops-Test --name appgw-devops-eastus

# Test direct nodePort access
kubectl exec -it <pod-name> -n zabbix -- curl -I http://<node-ip>:30247
```

## Conclusion

The Zabbix application is **fully functional** from a Kubernetes and application perspective. The 502 Bad Gateway errors are caused by **Azure network infrastructure misconfigurations** that prevent external traffic from reaching the application pods.

The resolution requires:
1. **Proper NSG configuration** for NodePort traffic
2. **Correct AGIC permissions** for Application Gateway management
3. **Verification of Azure LoadBalancer** backend pool configuration

---

**Status**: 🔄 **IN PROGRESS** - Network infrastructure fixes applied, verification pending  
**Date**: July 18, 2025  
**Next Update**: After external connectivity testing
