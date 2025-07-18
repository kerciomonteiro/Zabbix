# Multi-Application AKS Platform

This infrastructure creates a production-ready Azure Kubernetes Service (AKS) cluster designed to host multiple applications with proper isolation, monitoring, and security.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Azure Resource Group                         │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   Virtual       │  │  Application    │  │   Container     │ │
│  │   Network       │  │   Gateway       │  │   Registry      │ │
│  │                 │  │                 │  │                 │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                AKS Cluster                                   │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │ │
│  │  │ Namespace   │  │ Namespace   │  │   System Namespace  │ │ │
│  │  │  (Zabbix)   │  │ (Future App)│  │   (Kube-system)     │ │ │
│  │  │             │  │             │  │                     │ │ │
│  │  └─────────────┘  └─────────────┘  └─────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  Log Analytics  │  │  Application    │  │   Monitoring    │ │
│  │   Workspace     │  │   Insights      │  │   (Optional)    │ │
│  │                 │  │                 │  │                 │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Features

### 🏗️ **Infrastructure**
- **AKS Cluster**: Production-ready Kubernetes cluster with:
  - System and user node pools with auto-scaling
  - Workload identity enabled for secure authentication
  - Azure CNI networking with network policies
  - Integration with Azure Application Gateway
  - Pod Security Standards enforcement
  - Azure RBAC for Kubernetes authorization

### 🔒 **Security**
- **Namespace Isolation**: Each application runs in its own namespace
- **Network Policies**: Traffic isolation between applications
- **Resource Quotas**: Prevent resource exhaustion per application
- **Pod Security Standards**: Enforce security policies (baseline/restricted)
- **Azure AD Integration**: RBAC with Azure Active Directory
- **Workload Identity**: Secure authentication for pods
- **Private Cluster Support**: Optional private API server access

### 📊 **Monitoring & Observability**
- **Azure Monitor**: Container insights and metrics
- **Application Insights**: APM and distributed tracing
- **Log Analytics**: Centralized logging with configurable retention
- **Optional Prometheus Stack**: Advanced monitoring and alerting
- **Resource Usage Tracking**: Quota monitoring per namespace

### 🚀 **Multi-Application Support**
- **Dedicated Namespaces**: Isolated environments for each application
- **Resource Quotas**: CPU, memory, and storage limits per application
- **Storage Classes**: Different storage tiers for different workloads
- **Ingress Management**: Centralized ingress with Application Gateway
- **Pod Security Standards**: Configurable security enforcement
- **Network Policies**: Fine-grained traffic control

### ⚡ **Scalability & Performance**
- **Cluster Autoscaler**: Automatic node scaling based on demand
- **Application Gateway**: Load balancing with auto-scaling
- **Multiple Node Pools**: Separate system and user workloads
- **High Availability**: Multi-zone deployments
- **Container Registry**: Integrated Azure Container Registry

## Application Namespaces

### Current Applications
- **Zabbix**: Monitoring and alerting system
  - Namespace: `zabbix`
  - Resources: 2 CPU cores, 4GB RAM, 5 PVCs
  - Components: Zabbix Server, Web UI, MySQL

### Adding New Applications

To add a new application, update the `application_namespaces` variable in `terraform.tfvars`:

```hcl
application_namespaces = {
  zabbix = {
    name = "zabbix"
    labels = {
      "app.kubernetes.io/name"      = "zabbix"
      "app.kubernetes.io/component" = "monitoring"
      "app.kubernetes.io/part-of"   = "observability"
    }
    annotations = {
      "description" = "Zabbix monitoring application"
    }
    quotas = {
      requests_cpu    = "2000m"
      requests_memory = "4Gi"
      limits_cpu      = "4000m"
      limits_memory   = "8Gi"
      pods            = 20
      services        = 10
      pvcs            = 5
    }
  }
  
  # New application example
  prometheus = {
    name = "prometheus"
    labels = {
      "app.kubernetes.io/name"      = "prometheus"
      "app.kubernetes.io/component" = "metrics"
      "app.kubernetes.io/part-of"   = "observability"
    }
    annotations = {
      "description" = "Prometheus metrics collection"
    }
    quotas = {
      requests_cpu    = "1000m"
      requests_memory = "2Gi"
      limits_cpu      = "2000m"
      limits_memory   = "4Gi"
      pods            = 10
      services        = 5
      pvcs            = 3
    }
  }
}
```

## Configuration Variables

The platform supports extensive configuration through variables. Here are the key categories:

### Core Infrastructure
- `resource_group_name`: Azure resource group name
- `location`: Azure region for deployment
- `environment_name`: Environment identifier

### AKS Configuration
- `kubernetes_version`: Kubernetes version (default: "1.32")
- `aks_system_node_count`: System node pool size
- `aks_user_node_count`: User node pool initial size
- `aks_user_node_min_count`: Minimum nodes for auto-scaling
- `aks_user_node_max_count`: Maximum nodes for auto-scaling
- `aks_system_vm_size`: VM size for system nodes
- `aks_user_vm_size`: VM size for user nodes

### Security Settings
- `enable_pod_security_standards`: Enable Pod Security Standards
- `default_pod_security_standard`: Default security level (restricted/baseline/privileged)
- `enable_workload_identity`: Enable Azure Workload Identity
- `enable_azure_rbac`: Enable Azure RBAC for Kubernetes
- `enable_network_policies`: Enable network policies for isolation
- `enable_private_cluster`: Enable private cluster mode
- `authorized_ip_ranges`: Authorized IP ranges for API server access

### Application Gateway
- `appgw_sku_name`: Application Gateway SKU (Standard_v2/WAF_v2)
- `appgw_min_capacity`: Minimum capacity for auto-scaling
- `appgw_max_capacity`: Maximum capacity for auto-scaling
- `enable_waf`: Enable Web Application Firewall

### Container Registry
- `acr_sku`: Azure Container Registry SKU (Basic/Standard/Premium)
- `acr_admin_enabled`: Enable admin user for ACR

### Monitoring
- `enable_log_analytics`: Enable Log Analytics workspace
- `log_analytics_retention_days`: Log retention period
- `enable_application_insights`: Enable Application Insights
- `application_insights_retention_days`: APM data retention

### Networking
- `vnet_address_space`: Virtual network address space
- `aks_subnet_address_prefix`: AKS subnet address prefix
- `appgw_subnet_address_prefix`: Application Gateway subnet prefix
- `aks_service_cidr`: Kubernetes service CIDR
- `aks_dns_service_ip`: Kubernetes DNS service IP

### Scaling
- `enable_cluster_autoscaler`: Enable cluster autoscaler
- `max_pods_per_node`: Maximum pods per node
- `enable_azure_policy`: Enable Azure Policy addon

## Storage Classes

Two storage classes are available:

1. **fast-ssd**: Premium SSD storage for high-performance workloads
2. **standard-ssd**: Standard SSD storage for general workloads

## Deployment

### Prerequisites
- Azure CLI installed and configured
- Terraform >= 1.0
- kubectl configured
- Appropriate Azure permissions

### Deploy Infrastructure

```bash
# Initialize Terraform
cd infra/terraform
terraform init

# Plan deployment
terraform plan

# Apply deployment
terraform apply
```

### Deploy Applications

```bash
# Get AKS credentials
az aks get-credentials --resource-group <resource-group> --name <cluster-name>

# Deploy Zabbix
kubectl apply -f k8s/zabbix/

# Deploy other applications
kubectl apply -f k8s/<app-name>/
```

## Best Practices

### 🔧 **Resource Management**
- Use resource quotas to prevent resource exhaustion
- Set appropriate resource requests and limits
- Use horizontal pod autoscaling for variable workloads

### 🛡️ **Security**
- Follow principle of least privilege
- Use network policies for traffic isolation
- Enable pod security standards
- Regular security updates

### 📈 **Monitoring**
- Enable Azure Monitor container insights
- Set up Application Insights for APM
- Configure alerts for critical metrics
- Use log analytics for troubleshooting

### 🚀 **CI/CD Integration**
- Use GitHub Actions for automated deployments
- Separate infrastructure and application deployments
- Implement proper testing and validation
- Use staging environments

## Troubleshooting

### Common Issues

1. **Resource Quota Exceeded**
   ```bash
   kubectl describe quota -n <namespace>
   ```

2. **Network Policy Issues**
   ```bash
   kubectl get networkpolicies -n <namespace>
   kubectl describe networkpolicy <policy-name> -n <namespace>
   ```

3. **Storage Issues**
   ```bash
   kubectl get pvc -n <namespace>
   kubectl describe pvc <pvc-name> -n <namespace>
   ```

### Monitoring and Logs

```bash
# View cluster logs
kubectl logs -n kube-system -l app=azure-cni-networkmonitor

# Check application logs
kubectl logs -n <namespace> -l app=<app-name>

# View metrics
kubectl top nodes
kubectl top pods -n <namespace>
```

## Contributing

When adding new applications or modifying the infrastructure:

1. Update the appropriate Terraform configuration
2. Test changes in a non-production environment
3. Update documentation
4. Follow security best practices
5. Ensure proper monitoring and alerting

## Support

For issues and questions:
- Check the troubleshooting section
- Review Azure AKS documentation
- Consult Kubernetes documentation
- Review application-specific logs and metrics
