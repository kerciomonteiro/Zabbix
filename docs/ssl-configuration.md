# SSL Certificate Configuration for Zabbix

This document explains how to configure SSL certificates for the Zabbix server running on `dal2-devmon-mgt.forescout.com`.

## Option 1: Using Azure Key Vault Certificate (Recommended)

### Step 1: Upload Certificate to Azure Key Vault

```bash
# Create Key Vault (if not exists)
az keyvault create \
  --name "kv-zabbix-certs-${RANDOM}" \
  --resource-group "Devops-Test" \
  --location "eastus"

# Upload your PFX certificate
az keyvault certificate import \
  --vault-name "your-keyvault-name" \
  --name "zabbix-ssl-cert" \
  --file "/path/to/your/certificate.pfx" \
  --password "your-certificate-password"
```

### Step 2: Configure Application Gateway SSL

```bash
# Configure Application Gateway with SSL certificate
az network application-gateway ssl-cert create \
  --resource-group "Devops-Test" \
  --gateway-name "appgw-your-resource-token" \
  --name "zabbix-ssl-cert" \
  --key-vault-secret-id "https://your-keyvault.vault.azure.net/secrets/zabbix-ssl-cert"
```

### Step 3: Update Ingress Configuration

Update the `k8s/zabbix-ingress.yaml` file:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: zabbix-ingress
  namespace: zabbix
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
    appgw.ingress.kubernetes.io/ssl-redirect: "true"
    appgw.ingress.kubernetes.io/appgw-ssl-certificate: "zabbix-ssl-cert"
spec:
  tls:
  - hosts:
    - dal2-devmon-mgt.forescout.com
    secretName: zabbix-tls-secret
  rules:
  - host: dal2-devmon-mgt.forescout.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: zabbix-web
            port:
              number: 80
```

## Option 2: Using Kubernetes Secret

### Step 1: Create TLS Secret

```bash
# If you have separate certificate and key files
kubectl create secret tls zabbix-tls-secret \
  --cert=/path/to/your/certificate.crt \
  --key=/path/to/your/private.key \
  --namespace=zabbix

# Or create from existing files
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: zabbix-tls-secret
  namespace: zabbix
type: kubernetes.io/tls
data:
  tls.crt: $(cat /path/to/your/certificate.crt | base64 -w 0)
  tls.key: $(cat /path/to/your/private.key | base64 -w 0)
EOF
```

### Step 2: Update Application Gateway

The Application Gateway can be configured to use the certificate from the Kubernetes secret through the Application Gateway Ingress Controller.

## Option 3: Let's Encrypt with cert-manager (Alternative)

### Step 1: Install cert-manager

```bash
# Add cert-manager Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.0 \
  --set installCRDs=true
```

### Step 2: Create ClusterIssuer

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@forescout.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: azure/application-gateway
```

### Step 3: Update Ingress for Automatic Certificate

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: zabbix-ingress
  namespace: zabbix
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    appgw.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - dal2-devmon-mgt.forescout.com
    secretName: zabbix-tls-secret
  rules:
  - host: dal2-devmon-mgt.forescout.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: zabbix-web
            port:
              number: 80
```

## DNS Configuration

### Configure DNS Record

You need to create a DNS A record pointing to your Application Gateway's public IP:

```bash
# Get the public IP address
az network public-ip show \
  --resource-group "Devops-Test" \
  --name "pip-appgw-your-resource-token" \
  --query ipAddress \
  --output tsv
```

Create DNS A record:
- **Name**: dal2-devmon-mgt
- **Type**: A
- **Value**: [Public IP from above command]
- **TTL**: 300 (5 minutes)

## Verification

### Test SSL Configuration

```bash
# Test HTTP to HTTPS redirect
curl -I http://dal2-devmon-mgt.forescout.com

# Test HTTPS connection
curl -I https://dal2-devmon-mgt.forescout.com

# Check certificate details
openssl s_client -connect dal2-devmon-mgt.forescout.com:443 -servername dal2-devmon-mgt.forescout.com
```

### Monitor Certificate Expiration

```bash
# Check certificate expiration
echo | openssl s_client -servername dal2-devmon-mgt.forescout.com -connect dal2-devmon-mgt.forescout.com:443 2>/dev/null | openssl x509 -noout -dates
```

## Security Best Practices

1. **Use strong TLS configuration**: Ensure TLS 1.2+ is used
2. **Regular certificate renewal**: Set up automated renewal
3. **Certificate monitoring**: Monitor certificate expiration
4. **Backup certificates**: Keep secure backups of certificates
5. **Access control**: Limit access to certificate private keys

## Troubleshooting

### Common Issues

1. **Certificate not loading**: Check if the certificate is properly uploaded to Key Vault
2. **DNS not resolving**: Verify DNS A record configuration
3. **SSL handshake errors**: Check certificate chain and intermediate certificates
4. **Application Gateway not updating**: Restart the Application Gateway Ingress Controller

### Debug Commands

```bash
# Check Application Gateway configuration
az network application-gateway show \
  --resource-group "Devops-Test" \
  --name "appgw-your-resource-token"

# Check ingress controller logs
kubectl logs -n kube-system -l app=ingress-appgw

# Check certificate in Key Vault
az keyvault certificate show \
  --vault-name "your-keyvault-name" \
  --name "zabbix-ssl-cert"
```
