# Terraform Configuration for Zabbix AKS Infrastructure

This directory contains Terraform configuration files for deploying a complete Zabbix monitoring solution on Azure Kubernetes Service (AKS). This replaces the previous Bicep templates with Terraform for better multi-cloud support and advanced infrastructure management.

## 🏗️ Architecture

The Terraform configuration deploys:

- **AKS Cluster** with system and user node pools
- **Virtual Network** with dedicated subnets for AKS and Application Gateway
- **Application Gateway** for external access and SSL termination
- **Container Registry** for storing Docker images
- **Log Analytics Workspace** for monitoring and logging
- **User-Assigned Managed Identity** with appropriate RBAC permissions
- **Network Security Groups** with security rules

## 📁 File Structure

```
terraform/
├── main.tf                     # Main Terraform configuration and providers
├── variables.tf                # Input variables definitions
├── outputs.tf                  # Output values
├── network.tf                  # Network resources (VNet, subnets, NSGs)
├── identity.tf                 # Managed identity and RBAC
├── monitoring.tf               # Log Analytics and Container Registry
├── appgateway.tf              # Application Gateway configuration
├── aks.tf                     # AKS cluster and node pools
├── terraform.tfvars.example   # Example variable values
└── README.md                  # This file
```

## 🚀 Quick Start

### Prerequisites

1. **Azure CLI** installed and authenticated
2. **Terraform** installed (version >= 1.0)
3. **kubectl** installed for Kubernetes management
4. **Helm** installed for package management

### Installation

#### Install Terraform (Windows)
```powershell
# Using winget (recommended)
winget install HashiCorp.Terraform

# Or using Chocolatey
choco install terraform

# Verify installation
terraform version
```

#### Install Terraform (Linux/macOS)
```bash
# Download and install
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify installation
terraform version
```

### Deployment Steps

1. **Clone the repository and navigate to Terraform directory**:
   ```bash
   cd infra/terraform
   ```

2. **Copy and customize variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Initialize Terraform**:
   ```bash
   terraform init
   ```

4. **Validate configuration** (always run this first):
   ```bash
   terraform validate
   ```

5. **Plan deployment** (see what will be created):
   ```bash
   terraform plan
   ```

6. **Apply configuration**:
   ```bash
   terraform apply -auto-approve
   ```

7. **Get AKS credentials**:
   ```bash
   az aks get-credentials --resource-group $(terraform output -raw AZURE_RESOURCE_GROUP) --name $(terraform output -raw AKS_CLUSTER_NAME)
   ```

## 🔧 Configuration

### Required Variables

Edit `terraform.tfvars` with these required values:

```hcl
resource_group_name = "Devops-Test"
location           = "eastus"
environment_name   = "zabbix-devops-eastus-001"
```

### Optional Variables

Customize these values based on your requirements:

```hcl
# AKS Configuration
kubernetes_version      = "1.29.9"
aks_system_node_count  = 2
aks_user_node_count    = 3
enable_auto_scaling    = true

# Network Configuration
vnet_address_space = ["10.224.0.0/12"]
```

## 📋 Resource Naming Convention

All resources follow the DevOps naming convention: `resourcename-devops-regionname`

### Examples for East US region:
- AKS Cluster: `aks-devops-eastus`
- Virtual Network: `vnet-devops-eastus`
- Application Gateway: `appgw-devops-eastus`
- Container Registry: `acr{envname}devopseastus`

## 🔍 Outputs

After successful deployment, Terraform provides these useful outputs:

```bash
# Get cluster name
terraform output AKS_CLUSTER_NAME

# Get Application Gateway public IP
terraform output PUBLIC_IP_ADDRESS

# Get container registry endpoint
terraform output CONTAINER_REGISTRY_ENDPOINT

# Get all resource names
terraform output RESOURCE_NAMES
```

## 🧹 Cleanup

To destroy all resources:

```bash
terraform destroy
```

⚠️ **Warning**: This will permanently delete all infrastructure resources.

## 🔧 Troubleshooting

### Common Issues

1. **Resource name conflicts**:
   - Change the `environment_name` variable to a unique value
   - Ensure container registry name is globally unique

2. **Permission issues**:
   - Ensure your Azure account has Contributor access to the resource group
   - Verify service principal permissions for CI/CD scenarios

3. **Terraform state issues**:
   - Use `terraform refresh` to sync state with actual resources
   - Consider using remote state storage for team environments

### Validation Commands

```bash
# Validate Terraform syntax
terraform validate

# Check for configuration drift
terraform plan

# Verify AKS cluster
kubectl cluster-info

# Check node status
kubectl get nodes
```

## 🔐 Security Considerations

- **Managed Identity**: Uses user-assigned managed identity for AKS
- **RBAC**: Implements least-privilege access principles
- **Network Security**: NSGs control traffic flow
- **Container Registry**: Admin access disabled, uses managed identity
- **Workload Identity**: Enabled for secure pod-to-Azure service communication

## 🔄 CI/CD Integration

This Terraform configuration integrates with the GitHub Actions workflow. See the main `deploy.yml` workflow for automated deployment.

### Environment Variables for CI/CD

```yaml
# Required in GitHub Secrets
AZURE_CREDENTIALS: # Service Principal JSON
```

## 📚 Additional Resources

- [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [AKS Best Practices](https://docs.microsoft.com/en-us/azure/aks/best-practices)
- [Terraform Best Practices](https://developer.hashicorp.com/terraform/language/style)

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section above
2. Review Terraform and Azure CLI logs
3. Consult the Azure portal for resource status
4. Contact the DevOps team
