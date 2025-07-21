# Terraform Helper Scripts

This directory contains helper scripts for managing Terraform deployments in the Zabbix AKS infrastructure project.

## Scripts Overview

### Core Orchestration
- **`terraform-master.sh`** - Main orchestration script that coordinates the entire Terraform deployment process
  - Handles initialization, provider management, import, planning, and application
  - Called directly by the GitHub Actions workflow

### Individual Helper Scripts
- **`terraform-provider-helper.sh`** - Manages Kubernetes provider enable/disable during import phase
  - `disable` - Temporarily disable Kubernetes provider during import
  - `enable` - Re-enable Kubernetes provider after AKS is imported
  - `check` - Check current provider status
  - `cleanup` - Ensure provider is properly restored

- **`terraform-import-helper.sh`** - Handles importing existing Azure resources into Terraform state
  - Imports resources in dependency order
  - Provides detailed diagnostics and error reporting
  - Tracks import success/failure rates

- **`terraform-plan-helper.sh`** - Creates and validates Terraform plans
  - Validates Terraform configuration
  - Creates execution plans with error handling
  - Saves plan artifacts for review

- **`terraform-apply-helper.sh`** - Applies Terraform plans based on deployment mode
  - Supports `plan-only`, `plan-and-apply`, and `apply-existing-plan` modes
  - Extracts and sets deployment outputs
  - Handles cleanup and final state management

### Testing
- **`test-scripts.sh`** - Validation script to test helper script availability and basic functionality

## Usage

### From GitHub Actions Workflow
```yaml
- name: Deploy Infrastructure with Terraform
  run: |
    cd infra/terraform
    ../../scripts/terraform/terraform-master.sh "${{ env.TERRAFORM_MODE }}" "${{ github.event.inputs.debug_mode }}"
```

### Manual Testing (Linux/WSL)
```bash
# Test script availability
./scripts/terraform/test-scripts.sh

# Individual script usage
./scripts/terraform/terraform-provider-helper.sh help
```

## Environment Requirements

These scripts are designed to run in the GitHub Actions `ubuntu-latest` environment with:
- Terraform installed
- Azure CLI configured and authenticated
- Required environment variables set (`AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`)

## Error Handling

All scripts include comprehensive error handling and diagnostics:
- Exit codes indicate success/failure
- Detailed logging for troubleshooting
- GitHub Actions output variables for workflow coordination
- Graceful handling of missing resources

## Benefits

1. **Reduced Workflow Complexity** - Moves complex logic out of YAML into maintainable shell scripts
2. **GitHub Actions Compatibility** - Avoids expression length limits in workflow files  
3. **Modularity** - Each script has a single responsibility
4. **Reusability** - Scripts can be called individually for testing or debugging
5. **Better Error Handling** - More sophisticated error handling than inline YAML scripts
