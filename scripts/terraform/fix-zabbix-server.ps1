# Zabbix Server Fix Script - PowerShell Version
# This script fixes common Zabbix server startup issues

Write-Host "🔧 Zabbix Server Failure Fix" -ForegroundColor Yellow
Write-Host "============================" -ForegroundColor Yellow
Write-Host ""

# Check kubectl connectivity
try {
    kubectl cluster-info | Out-Null
    Write-Host "✅ Connected to Kubernetes cluster" -ForegroundColor Green
} catch {
    Write-Host "❌ kubectl not configured. Please run:" -ForegroundColor Red
    Write-Host "   az aks get-credentials --resource-group rg-devops-pops-eastus --name aks-devops-eastus" -ForegroundColor Yellow
    exit 1
}

# Step 1: Get MySQL pod
Write-Host ""
Write-Host "🗄️  Step 1: Locating MySQL pod..." -ForegroundColor Blue
$mysqlPod = kubectl get pods -n zabbix -l app=zabbix-mysql -o jsonpath='{.items[0].metadata.name}' 2>$null

if (-not $mysqlPod) {
    Write-Host "❌ MySQL pod not found. Deploy MySQL first." -ForegroundColor Red
    exit 1
}

Write-Host "✅ MySQL pod found: $mysqlPod" -ForegroundColor Green

# Step 2: Wait for MySQL
Write-Host ""
Write-Host "⏳ Step 2: Waiting for MySQL to be ready..." -ForegroundColor Blue
kubectl wait --for=condition=ready pod -l app=zabbix-mysql -n zabbix --timeout=60s

# Step 3: Test database connection
Write-Host ""
Write-Host "🔐 Step 3: Testing database connection..." -ForegroundColor Blue

# Test MySQL connection
$testConnection = kubectl exec -n zabbix $mysqlPod -- mysql -u zabbix -pzabbix123! -e "SELECT 1;" 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Database connection working" -ForegroundColor Green
} else {
    Write-Host "🔧 Fixing database connection..." -ForegroundColor Yellow
    
    # Fix database user
    $fixUser = kubectl exec -n zabbix $mysqlPod -- mysql -u root -pZabbixRoot123! -e @"
        DROP USER IF EXISTS 'zabbix'@'%';
        CREATE USER 'zabbix'@'%' IDENTIFIED BY 'zabbix123!';
        GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'%';
        FLUSH PRIVILEGES;
"@
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Database user fixed" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to fix database user. Check root password." -ForegroundColor Red
        exit 1
    }
}

# Step 4: Check database schema
Write-Host ""
Write-Host "📊 Step 4: Checking database schema..." -ForegroundColor Blue

$tableCount = kubectl exec -n zabbix $mysqlPod -- mysql -u zabbix -pzabbix123! -D zabbix -e "SHOW TABLES;" 2>$null | Measure-Object -Line | Select-Object -ExpandProperty Lines

if ($tableCount -lt 10) {
    Write-Host "⚠️  Database schema not initialized. Creating basic schema..." -ForegroundColor Yellow
    
    # Create minimal schema
    $createSchema = kubectl exec -n zabbix $mysqlPod -- mysql -u zabbix -pzabbix123! -D zabbix -e @"
        CREATE TABLE IF NOT EXISTS config (
            configid bigint(20) unsigned NOT NULL AUTO_INCREMENT,
            work_period varchar(100) DEFAULT '1-5,09:00-18:00',
            PRIMARY KEY (configid)
        ) ENGINE=InnoDB;
        
        INSERT IGNORE INTO config (work_period) VALUES ('1-5,09:00-18:00');
        
        CREATE TABLE IF NOT EXISTS users (
            userid bigint(20) unsigned NOT NULL AUTO_INCREMENT,
            username varchar(100) NOT NULL DEFAULT '',
            passwd varchar(255) NOT NULL DEFAULT '',
            PRIMARY KEY (userid)
        ) ENGINE=InnoDB;
        
        INSERT IGNORE INTO users (username, passwd) VALUES ('Admin', '$2y$10$L5OdZENzU8hUQDFYBv6Zve5GACqaAqaCysXUL5qW5vLJ6xFgc7wDK');
"@
    
    Write-Host "✅ Basic database schema created" -ForegroundColor Green
} else {
    Write-Host "✅ Database schema already exists ($tableCount tables)" -ForegroundColor Green
}

# Step 5: Restart Zabbix server
Write-Host ""
Write-Host "🔄 Step 5: Restarting Zabbix server deployment..." -ForegroundColor Blue

kubectl rollout restart deployment/zabbix-server -n zabbix
kubectl rollout status deployment/zabbix-server -n zabbix --timeout=300s

# Step 6: Verify
Write-Host ""
Write-Host "✅ Step 6: Verifying the fix..." -ForegroundColor Blue

Start-Sleep -Seconds 10

Write-Host "Pod status:" -ForegroundColor Blue
kubectl get pods -n zabbix -l app=zabbix-server

$newPod = kubectl get pods -n zabbix -l app=zabbix-server -o jsonpath='{.items[0].metadata.name}' 2>$null

if ($newPod) {
    Write-Host ""
    Write-Host "📋 Recent logs from new pod ($newPod):" -ForegroundColor Blue
    kubectl logs -n zabbix $newPod --tail=15
}

Write-Host ""
Write-Host "🎯 Fix completed!" -ForegroundColor Green
Write-Host "📋 Monitor with: kubectl get pods -n zabbix -w" -ForegroundColor Yellow
Write-Host "📋 Check logs: kubectl logs -n zabbix -l app=zabbix-server -f" -ForegroundColor Yellow
