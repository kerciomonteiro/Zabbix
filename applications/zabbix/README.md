# Zabbix Application

This directory contains the Kubernetes manifests for the Zabbix monitoring application.

## Overview

Zabbix is a comprehensive monitoring solution that provides:
- Infrastructure monitoring
- Application performance monitoring
- Alerting and notifications
- Historical data analysis
- Dashboard and visualization

## Architecture

The Zabbix deployment consists of:
- **Zabbix Server**: Core monitoring engine
- **Zabbix Web UI**: Web-based interface
- **MySQL Database**: Data storage backend

## Deployment

### Prerequisites
1. Ensure the `zabbix` namespace exists (created by Terraform)
2. Verify resource quotas are sufficient
3. Check that the Application Gateway is properly configured

### Deploy Zabbix

```bash
# Deploy all components
kubectl apply -f k8s/

# Or deploy individually
kubectl apply -f k8s/zabbix-mysql.yaml
kubectl apply -f k8s/zabbix-server.yaml
kubectl apply -f k8s/zabbix-web.yaml
kubectl apply -f k8s/zabbix-ingress.yaml
```

### Verify Deployment

```bash
# Check namespace
kubectl get all -n zabbix

# Check pods
kubectl get pods -n zabbix

# Check services
kubectl get svc -n zabbix

# Check ingress
kubectl get ingress -n zabbix
```

## Configuration Files

### Core Components
- `zabbix-mysql.yaml` - MySQL database deployment and service
- `zabbix-server.yaml` - Zabbix Server deployment and service
- `zabbix-web.yaml` - Zabbix Web UI deployment and service
- `zabbix-config.yaml` - Configuration maps and secrets
- `zabbix-ingress.yaml` - Ingress configuration for external access

### Database Initialization
- `zabbix-db-init.yaml` - Database initialization job
- `zabbix-db-init-complete.yaml` - Complete database setup
- `zabbix-db-init-data.yaml` - Sample data initialization
- `zabbix-db-init-direct.yaml` - Direct database initialization
- `zabbix-db-init-simple.yaml` - Simplified database setup

### Utilities
- `zabbix-additional.yaml` - Additional configurations
- `zabbix-db-recreate.yaml` - Database recreation job
- `zabbix-init-simple.yaml` - Simple initialization script

## Resource Requirements

### Namespace Quotas
- **CPU Requests**: 2000m
- **Memory Requests**: 4Gi
- **CPU Limits**: 4000m
- **Memory Limits**: 8Gi
- **Pods**: 20
- **Services**: 10
- **PVCs**: 5

### Individual Components
- **MySQL**: 1 CPU core, 2GB RAM, 20GB storage
- **Zabbix Server**: 0.5 CPU core, 1GB RAM
- **Zabbix Web**: 0.5 CPU core, 1GB RAM

## Access

### Internal Access
- **Zabbix Web UI**: `http://zabbix-web.zabbix.svc.cluster.local`
- **Zabbix Server**: `zabbix-server.zabbix.svc.cluster.local:10051`
- **MySQL**: `zabbix-mysql.zabbix.svc.cluster.local:3306`

### External Access
- **Web UI**: Configured through Application Gateway ingress
- **API**: Available through the Web UI endpoint

## Default Credentials

**Default Login**: Admin / zabbix
**Note**: Change default password after first login

## Monitoring

Zabbix automatically monitors:
- Host system resources
- Network interfaces
- System processes
- Application services
- Custom metrics via agents

## Maintenance

### Database Backup
```bash
# Create backup
kubectl exec -n zabbix deployment/zabbix-mysql -- mysqldump -u root -p zabbix > zabbix-backup.sql

# Restore from backup
kubectl exec -i -n zabbix deployment/zabbix-mysql -- mysql -u root -p zabbix < zabbix-backup.sql
```

### Scaling
```bash
# Scale web interface
kubectl scale deployment zabbix-web --replicas=2 -n zabbix

# Scale is limited by namespace quotas
```

### Logs
```bash
# View server logs
kubectl logs -n zabbix deployment/zabbix-server

# View web UI logs
kubectl logs -n zabbix deployment/zabbix-web

# View database logs
kubectl logs -n zabbix deployment/zabbix-mysql
```

## Troubleshooting

### Common Issues

1. **Database Connection Issues**
   - Check MySQL service status
   - Verify connection strings in ConfigMap
   - Check network policies

2. **Pod Startup Issues**
   - Check resource quotas
   - Verify image availability
   - Check persistent volume claims

3. **Ingress Issues**
   - Verify Application Gateway configuration
   - Check ingress controller logs
   - Validate DNS resolution

### Debugging Commands

```bash
# Check pod status
kubectl describe pod <pod-name> -n zabbix

# Check service endpoints
kubectl get endpoints -n zabbix

# Check resource usage
kubectl top pods -n zabbix

# Check events
kubectl get events -n zabbix --sort-by=.metadata.creationTimestamp
```

## Updates

To update Zabbix:
1. Update image versions in YAML files
2. Apply changes: `kubectl apply -f k8s/`
3. Monitor rollout: `kubectl rollout status deployment/zabbix-server -n zabbix`
4. Verify functionality after update
