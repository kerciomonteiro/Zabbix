# Applications Directory

This directory contains application-specific configurations and resources for the multi-application AKS platform.

## Structure

```
applications/
├── zabbix/
│   ├── k8s/
│   │   ├── zabbix-additional.yaml
│   │   ├── zabbix-config.yaml
│   │   ├── zabbix-db-*.yaml
│   │   ├── zabbix-ingress.yaml
│   │   ├── zabbix-mysql.yaml
│   │   ├── zabbix-server.yaml
│   │   └── zabbix-web.yaml
│   └── README.md
└── [future-applications]/
```

## Adding New Applications

When adding a new application:

1. Create a new directory under `applications/`
2. Add a `k8s/` subdirectory for Kubernetes manifests
3. Create appropriate YAML files for your application
4. Update the `terraform.tfvars` file to include the new application namespace
5. Deploy using `terraform apply`

## Application Requirements

Each application should:
- Use its own namespace defined in the Terraform configuration
- Follow Kubernetes resource naming conventions
- Include appropriate labels and annotations
- Respect the resource quotas assigned to the namespace
- Use the shared Application Gateway for ingress

## Examples

### Zabbix (Monitoring)
- **Namespace**: `zabbix`
- **Components**: Zabbix Server, Web UI, MySQL Database
- **Resources**: 2 CPU cores, 4GB RAM, 5 PVCs
- **Purpose**: Infrastructure monitoring and alerting

### Future Applications
Add similar documentation for each new application you deploy.

## Best Practices

1. **Resource Limits**: Always set appropriate resource requests and limits
2. **Health Checks**: Include readiness and liveness probes
3. **Configuration**: Use ConfigMaps and Secrets for configuration
4. **Persistence**: Use appropriate storage classes for persistent data
5. **Monitoring**: Include appropriate labels for monitoring integration
6. **Security**: Follow Pod Security Standards requirements
