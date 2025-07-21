#!/bin/bash
set -e

# Zabbix Server Failure Diagnostic Script
# This script helps diagnose why the Zabbix server is failing to start

echo "🔍 Zabbix Server Failure Diagnosis"
echo "================================="
echo ""

# Check if kubectl is configured
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ kubectl not configured or cluster not accessible"
    echo "   Please ensure you're connected to the AKS cluster"
    exit 1
fi

echo "✅ Connected to Kubernetes cluster"
echo ""

# Check namespace
echo "📦 Checking zabbix namespace..."
if ! kubectl get namespace zabbix >/dev/null 2>&1; then
    echo "❌ Zabbix namespace does not exist"
    exit 1
fi
echo "✅ Zabbix namespace exists"
echo ""

# Check all pods status
echo "🔍 Pod Status Overview:"
kubectl get pods -n zabbix -o wide
echo ""

# Check Zabbix server pod logs
echo "📋 Checking Zabbix server pod logs..."
ZABBIX_SERVER_POD=$(kubectl get pods -n zabbix -l app=zabbix-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$ZABBIX_SERVER_POD" ]; then
    echo "❌ No Zabbix server pod found"
    exit 1
fi

echo "Pod name: $ZABBIX_SERVER_POD"
echo ""

echo "🚨 Recent logs from Zabbix server:"
kubectl logs -n zabbix "$ZABBIX_SERVER_POD" --tail=50 || echo "Failed to get logs"
echo ""

# Check events
echo "⚠️  Recent events for Zabbix server pod:"
kubectl describe pod -n zabbix "$ZABBIX_SERVER_POD" | grep -A 10 "Events:"
echo ""

# Check MySQL connectivity
echo "🔍 Testing MySQL connectivity..."
MYSQL_POD=$(kubectl get pods -n zabbix -l app=zabbix-mysql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$MYSQL_POD" ]; then
    echo "MySQL pod: $MYSQL_POD"
    
    # Check MySQL pod status
    echo "MySQL pod status:"
    kubectl get pod -n zabbix "$MYSQL_POD"
    
    # Test MySQL connection with the credentials
    echo ""
    echo "🔐 Testing MySQL connection with zabbix user..."
    if kubectl exec -n zabbix "$MYSQL_POD" -- mysql -u zabbix -pzabbix123! -e "SELECT 1;" 2>/dev/null; then
        echo "✅ MySQL connection with zabbix user successful"
        
        # Check if zabbix database exists and has tables
        echo ""
        echo "📊 Checking Zabbix database schema..."
        TABLE_COUNT=$(kubectl exec -n zabbix "$MYSQL_POD" -- mysql -u zabbix -pzabbix123! -D zabbix -e "SHOW TABLES;" 2>/dev/null | wc -l || echo "0")
        echo "Number of tables in zabbix database: $TABLE_COUNT"
        
        if [ "$TABLE_COUNT" -lt 10 ]; then
            echo "⚠️  Database appears to be empty - schema may not be initialized"
            echo "   Zabbix requires database schema to be imported"
        else
            echo "✅ Database schema appears to be initialized"
        fi
    else
        echo "❌ MySQL connection with zabbix user failed"
        echo "   This is likely causing the Zabbix server to fail"
    fi
else
    echo "❌ MySQL pod not found"
fi

echo ""
echo "🎯 Diagnosis Summary:"
echo "1. Check the logs above for specific error messages"
echo "2. Common issues:"
echo "   - Database not initialized with Zabbix schema"
echo "   - Database connection credentials mismatch"
echo "   - MySQL service not ready"
echo "   - Resource constraints"
echo ""
echo "💡 Suggested fixes:"
echo "1. Initialize Zabbix database schema"
echo "2. Verify database credentials"
echo "3. Check resource limits"
echo "4. Restart the deployment if needed"
