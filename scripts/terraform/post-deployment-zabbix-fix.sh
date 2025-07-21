#!/bin/bash
set -e

# Post-Deployment Zabbix Verification and Fix Script
# This script ensures all Zabbix components are properly deployed and configured

echo "🔍 Post-Deployment Zabbix Verification and Fix"
echo "=============================================="
echo ""
echo "This script will:"
echo "  ✓ Verify all Zabbix components are deployed"
echo "  ✓ Check database connectivity and schema"
echo "  ✓ Fix Application Gateway backend configuration"
echo "  ✓ Ensure complete Zabbix stack is operational"
echo ""

# Configuration
NAMESPACE="zabbix"
RESOURCE_GROUP="rg-devops-pops-eastus"
APP_GATEWAY_NAME="appgw-devops-eastus"
SUBSCRIPTION_ID="d9b2a1cf-f99b-4f9e-a6cf-c79a078406bf"

# Function to check and fix version compatibility
check_version_compatibility() {
    echo "🔍 Checking Zabbix component version compatibility..."
    
    # Check if zabbix-server deployment exists and get its image
    if kubectl get deployment zabbix-server -n $NAMESPACE >/dev/null 2>&1; then
        local server_image=$(kubectl get deployment zabbix-server -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].image}')
        echo "📋 Zabbix Server image: $server_image"
        
        # Check for version 5.4 vs 6.0 mismatch
        if echo "$server_image" | grep -q "5\.4"; then
            echo "⚠️  CRITICAL: Found Zabbix 5.4 server with 6.0 database!"
            echo "   This causes: 'database version does not match current requirements'"
            echo "   Updating to Zabbix 6.0 server..."
            
            # Update the image to 6.0
            kubectl patch deployment zabbix-server -n $NAMESPACE -p '{"spec":{"template":{"spec":{"containers":[{"name":"zabbix-server","image":"zabbix/zabbix-server-mysql:6.0-alpine-latest"}]}}}}'
            
            # Wait for rollout
            kubectl rollout status deployment/zabbix-server -n $NAMESPACE --timeout=300s
            echo "✅ Updated Zabbix server to version 6.0"
        else
            echo "✅ Zabbix server version looks compatible"
        fi
    fi
    
    # Check web frontend version
    if kubectl get deployment zabbix-web -n $NAMESPACE >/dev/null 2>&1; then
        local web_image=$(kubectl get deployment zabbix-web -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].image}')
        echo "📋 Zabbix Web image: $web_image"
    fi
    
    echo ""
}

# Function to wait for pods to be ready
wait_for_pods() {
    local deployment_name=$1
    local namespace=$2
    local timeout=${3:-300}
    
    echo "⏳ Waiting for $deployment_name pods to be ready..."
    if kubectl wait --for=condition=ready pod -l app=$deployment_name -n $namespace --timeout=${timeout}s; then
        echo "✅ $deployment_name pods are ready"
        return 0
    else
        echo "❌ $deployment_name pods failed to become ready within $timeout seconds"
        return 1
    fi
}

# Function to check and deploy missing components
check_and_deploy_component() {
    local component_name=$1
    local manifest_file=$2
    
    echo "🔍 Checking $component_name deployment..."
    
    if kubectl get deployment $component_name -n $NAMESPACE >/dev/null 2>&1; then
        echo "✅ $component_name deployment exists"
        
        # Check if pods are running
        local ready_pods=$(kubectl get deployment $component_name -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired_pods=$(kubectl get deployment $component_name -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
        
        if [ "$ready_pods" -eq "$desired_pods" ] && [ "$ready_pods" -gt 0 ]; then
            echo "✅ $component_name is running ($ready_pods/$desired_pods pods ready)"
        else
            echo "⚠️  $component_name pods not ready ($ready_pods/$desired_pods), restarting..."
            kubectl rollout restart deployment/$component_name -n $NAMESPACE
            wait_for_pods $component_name $NAMESPACE 180
        fi
    else
        echo "❌ $component_name deployment missing, deploying..."
        if [ -f "$manifest_file" ]; then
            kubectl apply -f "$manifest_file"
            wait_for_pods $component_name $NAMESPACE 300
        else
            echo "❌ Manifest file $manifest_file not found!"
            return 1
        fi
    fi
}

# Function to initialize database if needed
initialize_database() {
    echo "🔍 Checking Zabbix database schema..."
    
    # Check if database has proper schema
    local table_count=$(kubectl exec -n $NAMESPACE deployment/zabbix-mysql -- mysql -u zabbix -pzabbix123! -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'zabbix';" 2>/dev/null | tail -n 1 || echo "0")
    local user_count=$(kubectl exec -n $NAMESPACE deployment/zabbix-mysql -- mysql -u zabbix -pzabbix123! -e "SELECT COUNT(*) FROM zabbix.users;" 2>/dev/null | tail -n 1 || echo "0")
    
    echo "📊 Database status: $table_count tables, $user_count users"
    
    if [ "$table_count" -lt 100 ] || [ "$user_count" -eq 0 ]; then
        echo "❌ Database schema incomplete, initializing..."
        
        # Create database initialization job
        cat > /tmp/zabbix-db-init.yaml << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: zabbix-db-init-auto
  namespace: $NAMESPACE
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
          value: "zabbix"
        - name: MYSQL_PASSWORD
          value: "zabbix123!"
        - name: MYSQL_ROOT_PASSWORD
          value: "ZabbixRoot123!"
        command: ["/bin/bash", "-c"]
        args:
        - |
          echo "Dropping and recreating database..."
          mysql -h "\$DB_SERVER_HOST" -u root -p"\$MYSQL_ROOT_PASSWORD" -e "
          DROP DATABASE IF EXISTS \$MYSQL_DATABASE;
          CREATE DATABASE \$MYSQL_DATABASE CHARACTER SET utf8 COLLATE utf8_bin;
          GRANT ALL PRIVILEGES ON \$MYSQL_DATABASE.* TO '\$MYSQL_USER'@'%';
          FLUSH PRIVILEGES;
          "
          echo "Importing Zabbix schema..."
          zcat /usr/share/doc/zabbix-server-mysql/create.sql.gz | mysql -h "\$DB_SERVER_HOST" -u "\$MYSQL_USER" -p"\$MYSQL_PASSWORD" "\$MYSQL_DATABASE"
          echo "Verifying schema..."
          mysql -h "\$DB_SERVER_HOST" -u "\$MYSQL_USER" -p"\$MYSQL_PASSWORD" -e "
          SELECT COUNT(*) AS table_count FROM information_schema.tables WHERE table_schema = '\$MYSQL_DATABASE';
          SELECT COUNT(*) AS user_count FROM \$MYSQL_DATABASE.users;
          "
          echo "Database initialization complete!"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
EOF
        
        # Apply and wait for job
        kubectl apply -f /tmp/zabbix-db-init.yaml
        kubectl wait --for=condition=complete job/zabbix-db-init-auto -n $NAMESPACE --timeout=300s
        
        # Check results
        kubectl logs job/zabbix-db-init-auto -n $NAMESPACE
        
        # Clean up
        kubectl delete job zabbix-db-init-auto -n $NAMESPACE
        rm -f /tmp/zabbix-db-init.yaml
        
        echo "✅ Database schema initialization completed"
    else
        echo "✅ Database schema is properly initialized"
    fi
}

# Function to update Application Gateway backend
update_application_gateway() {
    echo "🔍 Updating Application Gateway backend configuration..."
    
    # Get Zabbix web pod IPs
    local pod_ips=$(kubectl get pods -n $NAMESPACE -l app=zabbix-web -o jsonpath='{.items[*].status.podIP}')
    
    if [ -z "$pod_ips" ]; then
        echo "❌ No Zabbix web pod IPs found"
        return 1
    fi
    
    echo "📋 Found Zabbix web pod IPs: $pod_ips"
    
    # Update HTTP settings to use port 8080
    echo "⚙️  Updating HTTP settings for port 8080..."
    az network application-gateway http-settings update \
        --gateway-name $APP_GATEWAY_NAME \
        --resource-group $RESOURCE_GROUP \
        --name appGatewayBackendHttpSettings \
        --port 8080 \
        --protocol Http \
        --timeout 60 \
        --path "/" \
        --host-name-from-backend-pool false
    
    # Clear existing backend addresses
    echo "⚙️  Clearing existing backend addresses..."
    az network application-gateway address-pool update \
        --gateway-name $APP_GATEWAY_NAME \
        --resource-group $RESOURCE_GROUP \
        --name appGatewayBackendPool \
        --servers ""
    
    # Add pod IPs to backend pool
    echo "⚙️  Adding pod IPs to backend pool..."
    for ip in $pod_ips; do
        echo "   Adding IP: $ip"
        az network application-gateway address-pool update \
            --gateway-name $APP_GATEWAY_NAME \
            --resource-group $RESOURCE_GROUP \
            --name appGatewayBackendPool \
            --servers $ip --add
    done
    
    # Wait for health probe to update
    echo "⏳ Waiting for health probes to update..."
    sleep 30
    
    # Check backend health
    local backend_health=$(az network application-gateway show-backend-health \
        --name $APP_GATEWAY_NAME \
        --resource-group $RESOURCE_GROUP \
        --query 'backendAddressPools[0].backendHttpSettingsCollection[0].servers[].health' \
        --output tsv 2>/dev/null || echo "Unknown")
    
    echo "📊 Backend health status: $backend_health"
    
    local healthy_count=$(echo "$backend_health" | grep -c "Healthy" || echo "0")
    local total_count=$(echo "$backend_health" | wc -l)
    
    if [ "$healthy_count" -gt 0 ]; then
        echo "✅ Application Gateway backend updated successfully ($healthy_count/$total_count backends healthy)"
    else
        echo "⚠️  Application Gateway backends may need more time to become healthy"
        echo "   Check status in a few minutes with: az network application-gateway show-backend-health"
    fi
}

# Main execution
echo "🚀 Starting Zabbix verification and fix process..."
echo ""

# Step 1: Check if kubectl is configured
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ kubectl is not configured or cluster is not accessible"
    echo "   Please ensure you're connected to the AKS cluster"
    exit 1
fi

# Step 2: Check namespace
echo "🔍 Checking namespace..."
if ! kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
    echo "❌ Namespace $NAMESPACE does not exist"
    exit 1
fi

# Step 3: Check and fix version compatibility
check_version_compatibility

# Step 4: Check and deploy MySQL
check_and_deploy_component "zabbix-mysql" "applications/zabbix/k8s/zabbix-mysql.yaml"

# Step 5: Initialize database
initialize_database

# Step 5: Check and deploy Zabbix server
check_and_deploy_component "zabbix-server" "applications/zabbix/k8s/zabbix-server.yaml"

# Step 6: Check and deploy Zabbix web (the critical missing component)
check_and_deploy_component "zabbix-web" "applications/zabbix/k8s/zabbix-web.yaml"

# Step 7: Verify all services
echo "🔍 Verifying all services..."
kubectl get services -n $NAMESPACE

# Step 8: Update Application Gateway
if command -v az >/dev/null 2>&1; then
    update_application_gateway
else
    echo "⚠️  Azure CLI not found, skipping Application Gateway update"
    echo "   Please manually update Application Gateway backend configuration"
fi

# Step 9: Final status check
echo ""
echo "📋 Final Status Check:"
echo "====================="
kubectl get pods -n $NAMESPACE
echo ""
kubectl get services -n $NAMESPACE
echo ""

# Check if all deployments are ready
local all_ready=true
for deployment in zabbix-mysql zabbix-server zabbix-web; do
    local ready_pods=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    local desired_pods=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
    
    if [ "$ready_pods" -eq "$desired_pods" ] && [ "$ready_pods" -gt 0 ]; then
        echo "✅ $deployment: Ready ($ready_pods/$desired_pods)"
    else
        echo "❌ $deployment: Not Ready ($ready_pods/$desired_pods)"
        all_ready=false
    fi
done

if $all_ready; then
    echo ""
    echo "🎉 SUCCESS: Complete Zabbix stack is operational!"
    echo ""
    echo "🌐 Your Zabbix installation should now be accessible at:"
    echo "   http://dal2-devmon-mgt-devops.eastus.cloudapp.azure.com/"
    echo ""
    echo "📝 Default login credentials:"
    echo "   Username: Admin"
    echo "   Password: zabbix"
    echo ""
    echo "🔧 Next steps:"
    echo "   1. Change the default admin password"
    echo "   2. Configure monitoring hosts and templates"
    echo "   3. Set up email notifications"
else
    echo ""
    echo "⚠️  Some components are not ready. Please check the logs:"
    echo ""
    for deployment in zabbix-mysql zabbix-server zabbix-web; do
        echo "   kubectl logs -n $NAMESPACE deployment/$deployment"
    done
    echo ""
    echo "   You can re-run this script after addressing any issues."
fi
