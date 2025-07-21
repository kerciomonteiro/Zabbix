#!/bin/bash
set -e

# Terraform Provider Management Helper Script
# This script manages the Kubernetes provider disable/enable logic

ACTION="${1:-help}"

case "$ACTION" in
    "disable")
        echo "🔧 Disabling Kubernetes provider during import phase..."
        if [ -f "kubernetes-providers.tf" ]; then
            mv kubernetes-providers.tf kubernetes-providers.tf.disabled
            echo "   ✅ Kubernetes provider temporarily disabled"
        else
            echo "   ⚠️  kubernetes-providers.tf not found - continuing anyway"
        fi
        ;;
    
    "enable")
        echo "🔧 Re-enabling Kubernetes provider after import..."
        if [ -f "kubernetes-providers.tf.disabled" ]; then
            mv kubernetes-providers.tf.disabled kubernetes-providers.tf
            echo "   ✅ Kubernetes provider re-enabled"
            
            # Re-initialize Terraform with the Kubernetes provider
            echo "   🔄 Re-initializing Terraform with Kubernetes provider..."
            terraform init
        else
            echo "   ⚠️  kubernetes-providers.tf.disabled not found"
        fi
        ;;
    
    "check")
        echo "🔍 Checking Kubernetes provider status..."
        if [ -f "kubernetes-providers.tf" ]; then
            echo "   ✅ Kubernetes provider is ENABLED"
        elif [ -f "kubernetes-providers.tf.disabled" ]; then
            echo "   ⚠️  Kubernetes provider is DISABLED"
        else
            echo "   ❌ No Kubernetes provider file found!"
        fi
        ;;
    
    "cleanup")
        echo "🔧 Cleanup: Ensuring Kubernetes provider is restored..."
        if [ -f "kubernetes-providers.tf.disabled" ]; then
            echo "   🔄 Restoring kubernetes-providers.tf from disabled state"
            mv kubernetes-providers.tf.disabled kubernetes-providers.tf
            echo "   ✅ Kubernetes provider file restored"
        else
            echo "   ✅ No cleanup needed - Kubernetes provider was not disabled or already restored"
        fi
        ;;
    
    "help"|*)
        echo "Terraform Provider Management Helper"
        echo ""
        echo "Usage: $0 [ACTION]"
        echo ""
        echo "Actions:"
        echo "  disable  - Disable Kubernetes provider for import phase"
        echo "  enable   - Re-enable Kubernetes provider after import"
        echo "  check    - Check current provider status"
        echo "  cleanup  - Ensure provider is properly restored (for cleanup)"
        echo "  help     - Show this help message"
        ;;
esac
