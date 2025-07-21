# Kubernetes Resource State Management Script
# This script handles the import of existing Kubernetes resources to prevent "already exists" errors

# PowerShell script to handle Kubernetes resource imports in CI/CD
$ErrorActionPreference = "Continue"

Write-Host "🔍 Checking for existing Kubernetes resources..." -ForegroundColor Yellow

# Function to import resource if it exists in cluster but not in state
function Import-KubernetesResource {
    param(
        [string]$ResourceAddress,
        [string]$ResourceId,
        [string]$ResourceType,
        [string]$ResourceName
    )
    
    Write-Host "Checking $ResourceType : $ResourceName" -ForegroundColor Blue
    
    # Check if resource exists in Terraform state
    $stateExists = terraform state show $ResourceAddress 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ $ResourceName already managed by Terraform" -ForegroundColor Green
        return $true
    }
    
    # Check if resource exists in cluster
    $clusterExists = $false
    switch ($ResourceType) {
        "namespace" {
            kubectl get namespace $ResourceName 2>$null
            $clusterExists = ($LASTEXITCODE -eq 0)
        }
        "storageclass" {
            kubectl get storageclass $ResourceName 2>$null
            $clusterExists = ($LASTEXITCODE -eq 0)
        }
    }
    
    if ($clusterExists) {
        Write-Host "  🔄 Importing existing $ResourceType : $ResourceName" -ForegroundColor Yellow
        terraform import $ResourceAddress $ResourceId
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ Successfully imported $ResourceName" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  ⚠️  Failed to import $ResourceName - will attempt creation" -ForegroundColor Yellow
            return $false
        }
    } else {
        Write-Host "  ✨ $ResourceName will be created" -ForegroundColor Cyan
        return $false
    }
}

# Import Kubernetes resources if they exist
Write-Host "🚀 Starting Kubernetes resource import process..." -ForegroundColor Green

# Import namespace
Import-KubernetesResource -ResourceAddress 'kubernetes_namespace.applications["zabbix"]' -ResourceId "zabbix" -ResourceType "namespace" -ResourceName "zabbix"

# Import storage classes
Import-KubernetesResource -ResourceAddress 'kubernetes_storage_class.workload_storage["standard"]' -ResourceId "standard-ssd" -ResourceType "storageclass" -ResourceName "standard-ssd"

Import-KubernetesResource -ResourceAddress 'kubernetes_storage_class.workload_storage["fast"]' -ResourceId "fast-ssd" -ResourceType "storageclass" -ResourceName "fast-ssd"

# Import other resources (these may fail gracefully)
Write-Host "🔄 Attempting to import additional resources..." -ForegroundColor Blue

terraform import 'kubernetes_labels.pod_security_standards["zabbix"]' "apiVersion=v1,kind=Namespace,name=zabbix" 2>$null
terraform import 'kubernetes_resource_quota.application_quotas["zabbix"]' "zabbix/zabbix-quota" 2>$null  
terraform import 'kubernetes_network_policy.namespace_isolation["zabbix"]' "zabbix/zabbix-isolation" 2>$null

Write-Host "✅ Kubernetes resource import process completed!" -ForegroundColor Green
Write-Host "📝 Running terraform plan to verify state..." -ForegroundColor Blue

# Run terraform plan to show the current state
terraform plan
