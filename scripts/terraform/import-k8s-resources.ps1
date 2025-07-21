# Kubernetes Resource Import Handler for CI/CD
# This PowerShell script handles "already exists" errors by importing existing resources

$ErrorActionPreference = "Continue"

Write-Host "🔧 Handling Kubernetes Resource Conflicts..." -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Yellow
Write-Host ""

# Function to safely import a Terraform resource
function Import-TerraformResource {
    param(
        [string]$ResourceAddress,
        [string]$ResourceId,
        [string]$ResourceName
    )
    
    Write-Host "Checking $ResourceName..." -ForegroundColor Blue
    
    # Check if resource exists in Terraform state
    $stateCheck = terraform state show $ResourceAddress 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ $ResourceName already managed by Terraform" -ForegroundColor Green
        return $true
    }
    
    # Attempt to import the resource
    Write-Host "  🔄 Importing $ResourceName..." -ForegroundColor Yellow
    terraform import $ResourceAddress $ResourceId 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Successfully imported $ResourceName" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  ⚠️  Import failed for $ResourceName (will handle during apply)" -ForegroundColor Yellow
        return $false
    }
}

Write-Host "🚀 Starting resource import process..." -ForegroundColor Green
Write-Host ""

# Import the critical resources that cause "already exists" errors
Import-TerraformResource -ResourceAddress 'kubernetes_namespace.applications["zabbix"]' -ResourceId "zabbix" -ResourceName "namespace zabbix"
Import-TerraformResource -ResourceAddress 'kubernetes_storage_class.workload_storage["standard"]' -ResourceId "standard-ssd" -ResourceName "storage class standard-ssd" 
Import-TerraformResource -ResourceAddress 'kubernetes_storage_class.workload_storage["fast"]' -ResourceId "fast-ssd" -ResourceName "storage class fast-ssd"

Write-Host ""
Write-Host "🔄 Importing additional resources (may fail silently)..." -ForegroundColor Blue

# These imports may fail but shouldn't block the process
terraform import 'kubernetes_labels.pod_security_standards["zabbix"]' "apiVersion=v1,kind=Namespace,name=zabbix" 2>$null
terraform import 'kubernetes_resource_quota.application_quotas["zabbix"]' "zabbix/zabbix-quota" 2>$null
terraform import 'kubernetes_network_policy.namespace_isolation["zabbix"]' "zabbix/zabbix-isolation" 2>$null

Write-Host ""
Write-Host "✅ Resource import process completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Current Kubernetes resources in Terraform state:" -ForegroundColor Blue
terraform state list | Select-String "kubernetes" | ForEach-Object { Write-Host "  $_" }

Write-Host ""
Write-Host "🎯 Ready to proceed with terraform apply!" -ForegroundColor Green
