#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validate Zabbix deployment on AKS

.DESCRIPTION
    This script checks the status of your Zabbix deployment and provides 
    troubleshooting information if issues are found.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$Namespace = "zabbix"
)

Write-Host "🔍 Zabbix AKS Deployment Validation" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

# Configuration
$AKS_CLUSTER_NAME = "aks-devops-eastus"
$RESOURCE_GROUP = "rg-devops-pops-eastus"
$PUBLIC_IP = "20.185.208.193"
$DOMAIN = "dal2-devmon-mgt-devops.eastus.cloudapp.azure.com"

Write-Host "`n📋 Environment Configuration:" -ForegroundColor Yellow
Write-Host "   AKS Cluster: $AKS_CLUSTER_NAME" -ForegroundColor White
Write-Host "   Resource Group: $RESOURCE_GROUP" -ForegroundColor White
Write-Host "   Public IP: $PUBLIC_IP" -ForegroundColor White
Write-Host "   Domain: $DOMAIN" -ForegroundColor White
Write-Host "   Namespace: $Namespace" -ForegroundColor White

# Check kubectl connection
Write-Host "`n🔑 Checking kubectl connection..." -ForegroundColor Blue
try {
    $currentContext = kubectl config current-context 2>$null
    if ($currentContext -eq $AKS_CLUSTER_NAME) {
        Write-Host "✅ kubectl is connected to $AKS_CLUSTER_NAME" -ForegroundColor Green
    } else {
        Write-Host "⚠️  kubectl context is '$currentContext', expected '$AKS_CLUSTER_NAME'" -ForegroundColor Yellow
        Write-Host "🔧 Getting AKS credentials..." -ForegroundColor Blue
        az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --overwrite-existing
    }
}
catch {
    Write-Host "❌ Failed to check kubectl connection: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Check nodes
Write-Host "`n🖥️  Checking AKS nodes..." -ForegroundColor Blue
$nodes = kubectl get nodes --no-headers 2>$null | ForEach-Object { $_.Split()[1] }
$readyNodes = ($nodes | Where-Object { $_ -eq "Ready" }).Count
$totalNodes = $nodes.Count

if ($readyNodes -eq $totalNodes -and $totalNodes -gt 0) {
    Write-Host "✅ All $totalNodes nodes are Ready" -ForegroundColor Green
} else {
    Write-Host "⚠️  $readyNodes/$totalNodes nodes are Ready" -ForegroundColor Yellow
    kubectl get nodes
}

# Check namespace
Write-Host "`n📁 Checking namespace '$Namespace'..." -ForegroundColor Blue
$nsExists = kubectl get namespace $Namespace 2>$null
if ($nsExists) {
    Write-Host "✅ Namespace '$Namespace' exists" -ForegroundColor Green
} else {
    Write-Host "❌ Namespace '$Namespace' not found" -ForegroundColor Red
    Write-Host "Creating namespace..." -ForegroundColor Blue
    kubectl create namespace $Namespace
}

# Check pods
Write-Host "`n🐳 Checking Zabbix pods..." -ForegroundColor Blue
$pods = kubectl get pods -n $Namespace --no-headers 2>$null
if ($pods) {
    $podLines = $pods -split "`n"
    $runningPods = ($podLines | Where-Object { $_ -match "Running" }).Count
    $totalPods = $podLines.Count
    
    Write-Host "📊 Pod Status Summary:" -ForegroundColor Yellow
    kubectl get pods -n $Namespace
    
    if ($runningPods -eq $totalPods) {
        Write-Host "`n✅ All $totalPods pods are Running" -ForegroundColor Green
    } else {
        Write-Host "`n⚠️  $runningPods/$totalPods pods are Running" -ForegroundColor Yellow
        
        # Show problematic pods
        $problemPods = $podLines | Where-Object { $_ -notmatch "Running" -and $_ -notmatch "Completed" }
        if ($problemPods) {
            Write-Host "`n🔍 Problem pods:" -ForegroundColor Red
            foreach ($pod in $problemPods) {
                $podName = $pod.Split()[0]
                Write-Host "   $pod" -ForegroundColor Red
                Write-Host "   Logs for $podName" -ForegroundColor Gray
                kubectl logs $podName -n $Namespace --tail=5 2>$null | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
            }
        }
    }
} else {
    Write-Host "❌ No pods found in namespace '$Namespace'" -ForegroundColor Red
    Write-Host "🔧 Try running: kubectl apply -f k8s/" -ForegroundColor Blue
}

# Check services
Write-Host "`n🌐 Checking services..." -ForegroundColor Blue
$services = kubectl get services -n $Namespace --no-headers 2>$null
if ($services) {
    Write-Host "📊 Service Status:" -ForegroundColor Yellow
    kubectl get services -n $Namespace
    
    # Check for LoadBalancer services
    $lbServices = kubectl get services -n $Namespace -o jsonpath="{.items[?(@.spec.type=='LoadBalancer')].metadata.name}" 2>$null
    if ($lbServices) {
        Write-Host "`n🔍 LoadBalancer service IPs:" -ForegroundColor Blue
        foreach ($svc in $lbServices.Split()) {
            $ip = kubectl get service $svc -n $Namespace -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>$null
            if ($ip) {
                Write-Host "   ${svc}: $ip" -ForegroundColor Green
            } else {
                Write-Host "   ${svc}: <pending>" -ForegroundColor Yellow
            }
        }
    }
} else {
    Write-Host "❌ No services found" -ForegroundColor Red
}

# Check ingress
Write-Host "`n🚪 Checking ingress..." -ForegroundColor Blue
$ingresses = kubectl get ingress -n $Namespace --no-headers 2>$null
if ($ingresses) {
    Write-Host "📊 Ingress Status:" -ForegroundColor Yellow
    kubectl get ingress -n $Namespace
} else {
    Write-Host "❌ No ingresses found" -ForegroundColor Red
}

# Check ingress controllers
Write-Host "`n🎛️  Checking ingress controllers..." -ForegroundColor Blue

# Check AGIC
$agic = kubectl get deployment ingress-appgw -n kube-system 2>$null
if ($agic) {
    Write-Host "✅ Application Gateway Ingress Controller (AGIC) is installed" -ForegroundColor Green
} else {
    Write-Host "❌ AGIC not found" -ForegroundColor Red
}

# Check NGINX Ingress
$nginxNs = kubectl get namespace ingress-nginx 2>$null
if ($nginxNs) {
    $nginxPods = kubectl get pods -n ingress-nginx --no-headers 2>$null | Where-Object { $_ -match "Running" }
    if ($nginxPods) {
        Write-Host "✅ NGINX Ingress Controller is running" -ForegroundColor Green
    } else {
        Write-Host "⚠️  NGINX Ingress Controller namespace exists but no running pods" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ NGINX Ingress Controller not found" -ForegroundColor Red
}

# Test web connectivity
Write-Host "`n🌐 Testing web connectivity..." -ForegroundColor Blue
try {
    Write-Host "Testing connection to $DOMAIN..." -ForegroundColor Gray
    $response = Invoke-WebRequest -Uri "http://$DOMAIN" -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Zabbix web interface is accessible at http://$DOMAIN" -ForegroundColor Green
        if ($response.Content -match "Zabbix") {
            Write-Host "✅ Zabbix content detected" -ForegroundColor Green
        }
    }
}
catch {
    Write-Host "⚠️  Web interface test failed: $($_.Exception.Message)" -ForegroundColor Yellow
    
    # Test direct IP
    try {
        Write-Host "Testing direct IP connection to $PUBLIC_IP..." -ForegroundColor Gray
        $ipResponse = Invoke-WebRequest -Uri "http://$PUBLIC_IP" -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
        if ($ipResponse.StatusCode -eq 200) {
            Write-Host "✅ Direct IP access works - DNS might need configuration" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "❌ Direct IP access also failed" -ForegroundColor Red
    }
}

# Database connectivity check
Write-Host "`n🗄️  Checking database connectivity..." -ForegroundColor Blue
$mysqlPods = kubectl get pods -n $Namespace -l app=zabbix-mysql --no-headers 2>$null
if ($mysqlPods) {
    $mysqlPod = $mysqlPods.Split()[0]
    $tableCount = kubectl exec -n $Namespace $mysqlPod -- mysql -u root -pZabbixRoot123! -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='zabbix';" 2>$null | Select-Object -Last 1
    
    if ($tableCount -and [int]$tableCount -gt 10) {
        Write-Host "✅ Database is initialized with $tableCount tables" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Database might not be properly initialized (found $tableCount tables)" -ForegroundColor Yellow
        Write-Host "🔧 Consider running: kubectl apply -f applications/zabbix/k8s/zabbix-db-init-direct.yaml" -ForegroundColor Blue
    }
} else {
    Write-Host "❌ MySQL pod not found" -ForegroundColor Red
}

# Summary
Write-Host "`n📋 Validation Summary" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan

# Overall health score
$score = 0
$totalChecks = 8

if ($readyNodes -eq $totalNodes -and $totalNodes -gt 0) { $score++ }
if ($nsExists) { $score++ }
if ($pods -and ($runningPods -eq $totalPods)) { $score++ }
if ($services) { $score++ }
if ($ingresses) { $score++ }
if ($agic -or $nginxNs) { $score++ }
if ($mysqlPods) { $score++ }
try { 
    $webTest = Invoke-WebRequest -Uri "http://$DOMAIN" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
    if ($webTest.StatusCode -eq 200) { $score++ }
} catch { }

$healthPercentage = [math]::Round(($score / $totalChecks) * 100)

if ($healthPercentage -ge 80) {
    Write-Host "✅ Deployment Health: $healthPercentage% ($score/$totalChecks checks passed)" -ForegroundColor Green
    Write-Host "`n🎉 Zabbix appears to be working correctly!" -ForegroundColor Green
    Write-Host "🌐 Access URL: http://$DOMAIN" -ForegroundColor Blue
    Write-Host "🔐 Default login: Admin / zabbix" -ForegroundColor Blue
} elseif ($healthPercentage -ge 60) {
    Write-Host "⚠️  Deployment Health: $healthPercentage% ($score/$totalChecks checks passed)" -ForegroundColor Yellow
    Write-Host "Some issues detected - see details above" -ForegroundColor Yellow
} else {
    Write-Host "❌ Deployment Health: $healthPercentage% ($score/$totalChecks checks passed)" -ForegroundColor Red
    Write-Host "Multiple issues detected - deployment may not be working" -ForegroundColor Red
}

Write-Host "`n🔧 Common troubleshooting commands:" -ForegroundColor Cyan
Write-Host "   kubectl get all -n $Namespace" -ForegroundColor Gray
Write-Host "   kubectl describe pod <pod-name> -n $Namespace" -ForegroundColor Gray
Write-Host "   kubectl logs <pod-name> -n $Namespace" -ForegroundColor Gray
Write-Host "   kubectl get ingress -n $Namespace" -ForegroundColor Gray
Write-Host "`n🚀 Redeploy commands:" -ForegroundColor Cyan
Write-Host "   .\trigger-deployment.ps1 -DeploymentType application-only" -ForegroundColor Gray
Write-Host "   .\trigger-deployment.ps1 -DeploymentType redeploy-clean -ResetDatabase" -ForegroundColor Gray
