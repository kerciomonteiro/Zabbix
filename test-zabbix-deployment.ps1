# Test Zabbix Deployment Script
# This script tests the Zabbix deployment locally before running via GitHub Actions

param(
    [switch]$ResetDatabase = $false,
    [switch]$DebugMode = $false
)

Write-Host "🚀 Testing Zabbix Deployment Locally..." -ForegroundColor Cyan

# Configuration
$AZURE_RESOURCE_GROUP = "rg-devops-pops-eastus"
$AKS_CLUSTER_NAME = "aks-devops-eastus"
$NAMESPACE = "zabbix"

try {
    # Get AKS credentials
    Write-Host "🔑 Getting AKS credentials..." -ForegroundColor Yellow
    az aks get-credentials --resource-group $AZURE_RESOURCE_GROUP --name $AKS_CLUSTER_NAME --overwrite-existing

    # Verify connection
    Write-Host "🔍 Verifying AKS connection..." -ForegroundColor Yellow
    kubectl cluster-info
    kubectl get nodes

    # Create namespace
    Write-Host "📦 Creating Zabbix namespace..." -ForegroundColor Yellow
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

    # Deploy Zabbix configuration
    Write-Host "⚙️ Deploying Zabbix configuration..." -ForegroundColor Yellow
    kubectl apply -f k8s/zabbix-config.yaml

    # Conditional cleanup
    if ($ResetDatabase) {
        Write-Host "🧹 Resetting all Zabbix resources and data..." -ForegroundColor Red
        kubectl delete all,pvc,configmap,secret -n $NAMESPACE --all --ignore-not-found=true
        Start-Sleep -Seconds 10
    } else {
        Write-Host "🔄 Performing smart cleanup (preserving data)..." -ForegroundColor Yellow
        kubectl delete deployment --all -n $NAMESPACE --ignore-not-found=true
        kubectl delete service --all -n $NAMESPACE --ignore-not-found=true  
        kubectl delete ingress --all -n $NAMESPACE --ignore-not-found=true
    }

    # Deploy MySQL
    Write-Host "🗄️ Deploying MySQL database..." -ForegroundColor Yellow
    kubectl apply -f k8s/zabbix-mysql.yaml
    
    Write-Host "⏳ Waiting for MySQL to be ready..." -ForegroundColor Yellow
    kubectl wait --for=condition=ready pod -l app=zabbix-mysql -n $NAMESPACE --timeout=600s

    # Initialize database
    Write-Host "🔧 Initializing Zabbix database..." -ForegroundColor Yellow
    $MYSQL_POD = kubectl get pods -n $NAMESPACE -l app=zabbix-mysql -o jsonpath='{.items[0].metadata.name}'
    Write-Host "MySQL Pod: $MYSQL_POD" -ForegroundColor Gray
    
    # Check if database exists
    $DB_EXISTS = kubectl exec -n $NAMESPACE $MYSQL_POD -- mysql -u root -pZabbixRoot123! -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='zabbix';" 2>$null | Select-Object -Last 1
    if (!$DB_EXISTS) { $DB_EXISTS = "0" }

    if ($ResetDatabase -or [int]$DB_EXISTS -lt 10) {
        Write-Host "🔧 Setting up fresh Zabbix database..." -ForegroundColor Yellow
        kubectl exec -n $NAMESPACE $MYSQL_POD -- mysql -u root -pZabbixRoot123! -e "DROP DATABASE IF EXISTS zabbix;"
        kubectl exec -n $NAMESPACE $MYSQL_POD -- mysql -u root -pZabbixRoot123! -e "CREATE DATABASE zabbix CHARACTER SET utf8 COLLATE utf8_bin;"
        kubectl exec -n $NAMESPACE $MYSQL_POD -- mysql -u root -pZabbixRoot123! -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'%' IDENTIFIED BY 'zabbix123!';"
        kubectl apply -f k8s/zabbix-db-init-direct.yaml
        kubectl wait --for=condition=complete job/zabbix-db-init -n $NAMESPACE --timeout=600s
    } else {
        Write-Host "✅ Database already exists with $DB_EXISTS tables" -ForegroundColor Green
    }

    # Deploy Zabbix components
    Write-Host "🚀 Deploying Zabbix components..." -ForegroundColor Yellow
    
    # Java Gateway
    kubectl apply -f k8s/zabbix-additional.yaml
    kubectl wait --for=condition=available deployment/zabbix-java-gateway -n $NAMESPACE --timeout=300s
    
    # Zabbix Server  
    kubectl apply -f k8s/zabbix-server.yaml
    kubectl wait --for=condition=available deployment/zabbix-server -n $NAMESPACE --timeout=300s
    
    # Zabbix Web
    kubectl apply -f k8s/zabbix-web.yaml
    kubectl wait --for=condition=available deployment/zabbix-web -n $NAMESPACE --timeout=300s
    
    # Ingress
    kubectl apply -f k8s/zabbix-ingress.yaml

    # Display results
    Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
    Write-Host "📊 Current status:" -ForegroundColor Cyan
    kubectl get all -n $NAMESPACE
    
    Write-Host "`n🌐 Access Information:" -ForegroundColor Cyan
    Write-Host "Zabbix Web Interface: http://dal2-devmon-mgt-devops.eastus.cloudapp.azure.com" -ForegroundColor White
    Write-Host "Default Username: Admin" -ForegroundColor White  
    Write-Host "Default Password: zabbix" -ForegroundColor White
    
    # Get LoadBalancer IP if available
    $LB_IP = kubectl get service -n $NAMESPACE zabbix-web-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    if ($LB_IP) {
        Write-Host "Direct LoadBalancer IP: http://$LB_IP" -ForegroundColor White
    }

} catch {
    Write-Host "❌ Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "🔍 Troubleshooting information:" -ForegroundColor Yellow
    kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | Select-Object -Last 10
    exit 1
}

Write-Host "`n🎉 Test deployment completed successfully!" -ForegroundColor Green
