# Adding New Applications to the Multi-Application AKS Platform

This guide explains how to add new applications to the existing AKS platform infrastructure.

## Overview

The AKS platform is designed to support multiple applications with proper isolation, security, and resource management. Each application gets its own namespace with defined quotas, network policies, and security standards.

## Step-by-Step Process

### 1. Update Terraform Configuration

Edit the `terraform.tfvars` file to add your new application:

```hcl
application_namespaces = {
  # Existing applications
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
  
  # Your new application
  my_new_app = {
    name = "my-new-app"
    labels = {
      "app.kubernetes.io/name"      = "my-new-app"
      "app.kubernetes.io/component" = "web"
      "app.kubernetes.io/part-of"   = "frontend"
    }
    annotations = {
      "description" = "My new web application"
    }
    quotas = {
      requests_cpu    = "500m"
      requests_memory = "1Gi"
      limits_cpu      = "1000m"
      limits_memory   = "2Gi"
      pods            = 10
      services        = 5
      pvcs            = 2
    }
  }
}
```

### 2. Deploy Infrastructure Changes

Run Terraform to create the new namespace and resources:

```bash
cd infra/terraform
terraform plan
terraform apply
```

### 3. Verify Namespace Creation

Check that the namespace was created:

```bash
kubectl get namespaces
kubectl describe namespace my-new-app
```

Check the resource quota:

```bash
kubectl get resourcequota -n my-new-app
kubectl describe resourcequota -n my-new-app
```

### 4. Deploy Your Application

Create your application manifests in a new directory `k8s/my-new-app/`:

```yaml
# k8s/my-new-app/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-new-app
  namespace: my-new-app
  labels:
    app.kubernetes.io/name: my-new-app
    app.kubernetes.io/component: web
    app.kubernetes.io/part-of: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: my-new-app
  template:
    metadata:
      labels:
        app.kubernetes.io/name: my-new-app
    spec:
      containers:
      - name: web
        image: nginx:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
```

```yaml
# k8s/my-new-app/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: my-new-app-service
  namespace: my-new-app
spec:
  selector:
    app.kubernetes.io/name: my-new-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

### 5. Configure Ingress

Create an ingress resource to expose your application:

```yaml
# k8s/my-new-app/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-new-app-ingress
  namespace: my-new-app
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
spec:
  rules:
  - host: my-new-app.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-new-app-service
            port:
              number: 80
```

### 6. Deploy the Application

Apply the manifests:

```bash
kubectl apply -f k8s/my-new-app/
```

## Resource Quota Guidelines

Choose appropriate resource quotas based on your application requirements:

### Small Applications (e.g., simple web apps)
```hcl
quotas = {
  requests_cpu    = "500m"
  requests_memory = "1Gi"
  limits_cpu      = "1000m"
  limits_memory   = "2Gi"
  pods            = 10
  services        = 5
  pvcs            = 2
}
```

### Medium Applications (e.g., APIs, microservices)
```hcl
quotas = {
  requests_cpu    = "1000m"
  requests_memory = "2Gi"
  limits_cpu      = "2000m"
  limits_memory   = "4Gi"
  pods            = 15
  services        = 8
  pvcs            = 5
}
```

### Large Applications (e.g., databases, monitoring)
```hcl
quotas = {
  requests_cpu    = "2000m"
  requests_memory = "4Gi"
  limits_cpu      = "4000m"
  limits_memory   = "8Gi"
  pods            = 20
  services        = 10
  pvcs            = 10
}
```

## Security Considerations

### Pod Security Standards
All namespaces are configured with Pod Security Standards:
- **Enforce**: `restricted` by default
- **Audit**: `restricted` by default
- **Warn**: `restricted` by default

### Network Policies
Each namespace has network policies that:
- Allow ingress from same namespace
- Allow egress to kube-system for DNS
- Allow egress to internet (customize as needed)

### Resource Quotas
- CPU and memory limits prevent resource exhaustion
- Pod, service, and PVC limits prevent resource sprawl
- Quotas are enforced at the namespace level

## Best Practices

1. **Use meaningful labels**: Follow Kubernetes recommended labels
2. **Set appropriate resource requests/limits**: Ensure efficient resource utilization
3. **Use namespaces for isolation**: Each application should have its own namespace
4. **Monitor resource usage**: Check quota usage regularly
5. **Test in staging**: Always test new applications in a non-production environment first

## Common Labels

Use these standard labels for consistency:

```yaml
labels:
  app.kubernetes.io/name: <application-name>
  app.kubernetes.io/component: <component-type>  # web, database, cache, etc.
  app.kubernetes.io/part-of: <group>             # frontend, backend, monitoring, etc.
  app.kubernetes.io/version: <version>
  app.kubernetes.io/managed-by: <tool>           # terraform, helm, etc.
```

## Monitoring and Troubleshooting

### Check Namespace Status
```bash
kubectl get namespaces
kubectl describe namespace <namespace-name>
```

### Check Resource Quota Usage
```bash
kubectl describe resourcequota -n <namespace-name>
```

### Check Network Policies
```bash
kubectl get networkpolicies -n <namespace-name>
kubectl describe networkpolicy -n <namespace-name>
```

### Check Pod Security Standards
```bash
kubectl get namespace <namespace-name> -o yaml | grep pod-security
```

## Removing Applications

To remove an application:

1. Delete the application resources:
   ```bash
   kubectl delete -f k8s/my-new-app/
   ```

2. Remove the namespace configuration from `terraform.tfvars`

3. Apply terraform changes:
   ```bash
   terraform plan
   terraform apply
   ```

The namespace and associated resources will be automatically cleaned up.
