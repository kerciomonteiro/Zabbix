# Post-Deployment Zabbix Verification and Fix Script (PowerShell)
# This script ensures all Zabbix components are properly deployed and configured

param(
    [string]$Namespace = "zabbix",
    [string]$ResourceGroup = "rg-devops-pops-eastus",
    [string]$AppGatewayName = "appgw-devops-eastus",
    [string]$SubscriptionId = "d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"
)

Write-Host "🔍 Post-Deployment Zabbix Verification and Fix" -ForegroundColor Cyan
Write-Host "=============================================="
Write-Host ""
Write-Host "This script will:"
Write-Host "  ✓ Verify all Zabbix components are deployed"
Write-Host "  ✓ Fix version compatibility issues"
Write-Host "  ✓ Check database connectivity and schema"
Write-Host "  ✓ Fix Application Gateway backend configuration"
Write-Host "  ✓ Ensure complete Zabbix stack is operational"
Write-Host ""

# Function to wait for pods to be ready
function Wait-ForPods {
    param($DeploymentName, $Namespace, $TimeoutSeconds = 300)
    
    Write-Host "⏳ Waiting for $DeploymentName pods to be ready..." -ForegroundColor Yellow
    
    $result = kubectl wait --for=condition=ready pod -l app=$DeploymentName -n $Namespace --timeout="$($TimeoutSeconds)s" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ $DeploymentName pods are ready" -ForegroundColor Green
        return $true
    } else {
        Write-Host "❌ $DeploymentName pods failed to become ready within $TimeoutSeconds seconds" -ForegroundColor Red
        return $false
    }
}

# Function to check version compatibility
function Test-VersionCompatibility {
    Write-Host "🔍 Checking Zabbix component version compatibility..." -ForegroundColor Cyan
    
    # Check if zabbix-server deployment exists and get its image
    $serverExists = kubectl get deployment zabbix-server -n $Namespace 2>$null
    if ($LASTEXITCODE -eq 0) {
        $serverImage = kubectl get deployment zabbix-server -n $Namespace -o jsonpath='{.spec.template.spec.containers[0].image}' 2>$null
        Write-Host "📋 Zabbix Server image: $serverImage" -ForegroundColor White
        
        # Check for version 5.4 vs 6.0 mismatch
        if ($serverImage -match "5\.4") {
            Write-Host "⚠️  CRITICAL: Found Zabbix 5.4 server with 6.0 database!" -ForegroundColor Red
            Write-Host "   This causes: 'database version does not match current requirements'" -ForegroundColor Red
            Write-Host "   Updating to Zabbix 6.0 server..." -ForegroundColor Yellow
            
            # Update the image to 6.0
            $patchResult = kubectl patch deployment zabbix-server -n $Namespace -p '{"spec":{"template":{"spec":{"containers":[{"name":"zabbix-server","image":"zabbix/zabbix-server-mysql:6.0-alpine-latest"}]}}}}' 2>$null
            if ($LASTEXITCODE -eq 0) {
                # Wait for rollout
                Write-Host "⏳ Waiting for deployment rollout..." -ForegroundColor Yellow
                kubectl rollout status deployment/zabbix-server -n $Namespace --timeout=300s 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✅ Updated Zabbix server to version 6.0" -ForegroundColor Green
                } else {
                    Write-Host "❌ Failed to rollout updated Zabbix server" -ForegroundColor Red
                }
            } else {
                Write-Host "❌ Failed to patch Zabbix server deployment" -ForegroundColor Red
            }
        } else {
            Write-Host "✅ Zabbix server version looks compatible" -ForegroundColor Green
        }
    }
    
    # Check web frontend version
    $webExists = kubectl get deployment zabbix-web -n $Namespace 2>$null
    if ($LASTEXITCODE -eq 0) {
        $webImage = kubectl get deployment zabbix-web -n $Namespace -o jsonpath='{.spec.template.spec.containers[0].image}' 2>$null
        Write-Host "📋 Zabbix Web image: $webImage" -ForegroundColor White
    }
    
    Write-Host ""
}

# Function to check and deploy missing components
function Test-AndDeployComponent {
    param($ComponentName, $ManifestFile)
    
    Write-Host "🔍 Checking $ComponentName deployment..." -ForegroundColor Cyan
    
    $deploymentExists = kubectl get deployment $ComponentName -n $Namespace 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ $ComponentName deployment exists" -ForegroundColor Green
        
        # Check if pods are running
        $readyPods = kubectl get deployment $ComponentName -n $Namespace -o jsonpath='{.status.readyReplicas}' 2>$null
        if (-not $readyPods) { $readyPods = "0" }
        $desiredPods = kubectl get deployment $ComponentName -n $Namespace -o jsonpath='{.spec.replicas}' 2>$null
        if (-not $desiredPods) { $desiredPods = "1" }
        
        if ([int]$readyPods -eq [int]$desiredPods -and [int]$readyPods -gt 0) {
            Write-Host "✅ $ComponentName is running ($readyPods/$desiredPods pods ready)" -ForegroundColor Green
        } else {
            Write-Host "⚠️  $ComponentName pods not ready ($readyPods/$desiredPods), restarting..." -ForegroundColor Yellow
            kubectl rollout restart deployment/$ComponentName -n $Namespace 2>$null
            Wait-ForPods -DeploymentName $ComponentName -Namespace $Namespace -TimeoutSeconds 180
        }
    } else {
        Write-Host "❌ $ComponentName deployment missing, deploying..." -ForegroundColor Red
        if (Test-Path $ManifestFile) {
            kubectl apply -f $ManifestFile 2>$null
            if ($LASTEXITCODE -eq 0) {
                Wait-ForPods -DeploymentName $ComponentName -Namespace $Namespace -TimeoutSeconds 300
            } else {
                Write-Host "❌ Failed to apply manifest $ManifestFile" -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "❌ Manifest file $ManifestFile not found!" -ForegroundColor Red
            return $false
        }
    }
    return $true
}

# Function to initialize database if needed
function Initialize-Database {
    Write-Host "🔍 Checking Zabbix database schema..." -ForegroundColor Cyan
    
    # Check if database has proper schema
    $tableCount = kubectl exec -n $Namespace deployment/zabbix-mysql -- mysql -u zabbix -pzabbix123! -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'zabbix';" 2>$null | Select-Object -Last 1
    if (-not $tableCount) { $tableCount = "0" }
    
    $userCount = kubectl exec -n $Namespace deployment/zabbix-mysql -- mysql -u zabbix -pzabbix123! -e "SELECT COUNT(*) FROM zabbix.users;" 2>$null | Select-Object -Last 1
    if (-not $userCount) { $userCount = "0" }
    
    Write-Host "📊 Database status: $tableCount tables, $userCount users" -ForegroundColor White
    
    if ([int]$tableCount -lt 100 -or [int]$userCount -eq 0) {
        Write-Host "❌ Database schema incomplete, initializing..." -ForegroundColor Red
        
        # Create database initialization job
        $initJob = @"
apiVersion: batch/v1
kind: Job
metadata:
  name: zabbix-db-init-auto-ps
  namespace: $Namespace
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: zabbix-init
        image: zabbix/zabbix-server-mysql:6.0-alpine-latest
        env:
        - name: DB_SERVER_HOST
          value: "zabbix-mysql"
        - name: MYSQL_DATABASE
          value: "zabbix"  
        - name: MYSQL_USER
          value: "root"
        - name: MYSQL_PASSWORD
          value: "ZabbixRoot123!"
        - name: MYSQL_ROOT_PASSWORD
          value: "ZabbixRoot123!"
        command: ["/bin/bash"]
        args:
        - -c
        - |
          echo "Initializing Zabbix database schema..."
          mysql -h zabbix-mysql -u root -pZabbixRoot123! -e "DROP DATABASE IF EXISTS zabbix; CREATE DATABASE zabbix CHARACTER SET utf8 COLLATE utf8_bin;"
          mysql -h zabbix-mysql -u root -pZabbixRoot123! -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'%';"
          mysql -h zabbix-mysql -u root -pZabbixRoot123! zabbix < /usr/share/doc/zabbix-server-mysql*/create.sql.gz
          echo "Database initialization completed!"
"@
        
        # Apply the job
        $initJob | kubectl apply -f - 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Database initialization job created" -ForegroundColor Green
            
            # Wait for job completion
            Write-Host "⏳ Waiting for database initialization to complete..." -ForegroundColor Yellow
            kubectl wait --for=condition=complete job/zabbix-db-init-auto-ps -n $Namespace --timeout=300s 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Database initialized successfully" -ForegroundColor Green
                # Clean up the job
                kubectl delete job zabbix-db-init-auto-ps -n $Namespace 2>$null
            } else {
                Write-Host "❌ Database initialization timed out" -ForegroundColor Red
                kubectl logs job/zabbix-db-init-auto-ps -n $Namespace
            }
        } else {
            Write-Host "❌ Failed to create database initialization job" -ForegroundColor Red
        }
    } else {
        Write-Host "✅ Database schema looks good ($tableCount tables, $userCount users)" -ForegroundColor Green
    }
}

# Function to fix Application Gateway backends
function Fix-ApplicationGatewayBackends {
    Write-Host "🔍 Configuring Application Gateway backend pool..." -ForegroundColor Cyan
    
    # Get Zabbix web pod IPs
    $podIPs = kubectl get pods -n $Namespace -l app=zabbix-web -o jsonpath='{.items[*].status.podIP}' 2>$null
    if (-not $podIPs) {
        Write-Host "❌ No Zabbix web pods found. Cannot configure Application Gateway." -ForegroundColor Red
        return $false
    }
    
    $ipArray = $podIPs -split ' '
    Write-Host "📋 Found Zabbix web pod IPs: $($ipArray -join ', ')" -ForegroundColor White
    
    # Update Application Gateway backend pool
    Write-Host "⏳ Updating Application Gateway backend pool..." -ForegroundColor Yellow
    foreach ($ip in $ipArray) {
        if ($ip.Trim()) {
            az network application-gateway address-pool update `
                --gateway-name $AppGatewayName `
                --resource-group $ResourceGroup `
                --name defaultaddresspool `
                --servers $ip 2>$null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Added backend IP: $ip" -ForegroundColor Green
            } else {
                Write-Host "⚠️  Failed to add backend IP: $ip" -ForegroundColor Yellow
            }
        }
    }
    
    # Verify backend health
    Write-Host "🔍 Checking Application Gateway backend health..." -ForegroundColor Cyan
    $backendHealth = az network application-gateway show-backend-health --name $AppGatewayName --resource-group $ResourceGroup --output json 2>$null | ConvertFrom-Json
    
    if ($backendHealth) {
        $healthyCount = 0
        $totalCount = 0
        foreach ($pool in $backendHealth.backendAddressPools) {
            foreach ($server in $pool.backendHttpSettingsCollection) {
                foreach ($backend in $server.servers) {
                    $totalCount++
                    if ($backend.health -eq "Healthy") {
                        $healthyCount++
                    }
                }
            }
        }
        
        if ($healthyCount -gt 0) {
            Write-Host "✅ Application Gateway updated successfully ($healthyCount/$totalCount backends healthy)" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Application Gateway updated but backends not healthy yet" -ForegroundColor Yellow
        }
    }
    
    return $true
}

# Main execution
Write-Host "🚀 Starting Zabbix deployment verification and fix..." -ForegroundColor Green
Write-Host ""

# Step 1: Check if kubectl is configured
Write-Host "🔍 Step 1: Checking kubectl connectivity..." -ForegroundColor Cyan
$clusterInfo = kubectl cluster-info 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ kubectl is not configured or cluster is not accessible" -ForegroundColor Red
    Write-Host "   Please ensure you're connected to the AKS cluster" -ForegroundColor Red
    exit 1
}

# Step 2: Check namespace
Write-Host "🔍 Step 2: Checking namespace..." -ForegroundColor Cyan
$namespaceExists = kubectl get namespace $Namespace 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Namespace $Namespace does not exist" -ForegroundColor Red
    exit 1
}

# Step 3: Check and fix version compatibility
Write-Host "🔍 Step 3: Checking version compatibility..." -ForegroundColor Cyan
Test-VersionCompatibility

# Step 4: Check and deploy MySQL
Write-Host "🔍 Step 4: Checking MySQL..." -ForegroundColor Cyan
if (-not (Test-AndDeployComponent -ComponentName "zabbix-mysql" -ManifestFile "applications/zabbix/k8s/zabbix-mysql.yaml")) {
    Write-Host "❌ Failed to deploy MySQL component" -ForegroundColor Red
    exit 1
}

# Step 5: Initialize database
Write-Host "🔍 Step 5: Initializing database..." -ForegroundColor Cyan
Initialize-Database

# Step 6: Check and deploy Zabbix server
Write-Host "🔍 Step 6: Checking Zabbix server..." -ForegroundColor Cyan
if (-not (Test-AndDeployComponent -ComponentName "zabbix-server" -ManifestFile "applications/zabbix/k8s/zabbix-server.yaml")) {
    Write-Host "❌ Failed to deploy Zabbix server component" -ForegroundColor Red
    exit 1
}

# Step 7: Check and deploy Zabbix web
Write-Host "🔍 Step 7: Checking Zabbix web frontend..." -ForegroundColor Cyan
if (-not (Test-AndDeployComponent -ComponentName "zabbix-web" -ManifestFile "applications/zabbix/k8s/zabbix-web.yaml")) {
    Write-Host "❌ Failed to deploy Zabbix web component" -ForegroundColor Red
    exit 1
}

# Step 8: Fix Application Gateway
Write-Host "🔍 Step 8: Fixing Application Gateway..." -ForegroundColor Cyan
Fix-ApplicationGatewayBackends

# Step 9: Final verification
Write-Host "🔍 Step 9: Final verification..." -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Final Deployment Status:" -ForegroundColor Cyan
kubectl get pods -n $Namespace
Write-Host ""
kubectl get services -n $Namespace
Write-Host ""

# Test the URL
Write-Host "🌐 Testing Zabbix URL..." -ForegroundColor Cyan
$zabbixUrl = "http://dal2-devmon-mgt-devops.eastus.cloudapp.azure.com/"

try {
    $response = Invoke-WebRequest -Uri $zabbixUrl -TimeoutSec 10 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ SUCCESS: Zabbix is accessible!" -ForegroundColor Green
        Write-Host ""
        Write-Host "🎉 SUCCESS: Complete Zabbix stack is operational!" -ForegroundColor Green
        Write-Host ""
        Write-Host "🌐 Your Zabbix installation is now accessible at:" -ForegroundColor Cyan
        Write-Host "   $zabbixUrl" -ForegroundColor White
        Write-Host ""
        Write-Host "📝 Default login credentials:" -ForegroundColor Cyan
        Write-Host "   Username: Admin" -ForegroundColor White
        Write-Host "   Password: zabbix" -ForegroundColor White
        Write-Host ""
        Write-Host "🔒 IMPORTANT: Change the default password immediately!" -ForegroundColor Red
    } else {
        Write-Host "⚠️  Zabbix responded with status code: $($response.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Failed to connect to Zabbix URL: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Check Application Gateway configuration and DNS settings" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✅ Zabbix deployment verification and fix completed!" -ForegroundColor Green
