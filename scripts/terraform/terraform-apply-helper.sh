#!/bin/bash
set -e

# Terraform Apply Helper Script
# This script handles the apply logic based on the deployment mode

TERRAFORM_MODE="${1:-plan-and-apply}"
PLAN_FILE="${2}"

echo "🚀 Terraform Apply Helper - Mode: $TERRAFORM_MODE"

case "$TERRAFORM_MODE" in
    "plan-only")
        echo "📋 Plan-only mode: Terraform plan created and saved"
        echo "🔍 Review the plan and then run the workflow with 'apply-existing-plan' mode to apply"
        echo "DEPLOYMENT_SUCCESS=plan-created" >> "$GITHUB_OUTPUT"
        echo "PLAN_FILE=$PLAN_FILE" >> "$GITHUB_OUTPUT"
        ;;
    
    "apply-existing-plan")
        # Look for existing plan file
        EXISTING_PLAN=$(ls -t tfplan-* 2>/dev/null | head -n 1 || echo "")
        if [ -z "$EXISTING_PLAN" ]; then
            echo "❌ No existing plan found. Please run in 'plan-only' mode first."
            echo "DEPLOYMENT_SUCCESS=false" >> "$GITHUB_OUTPUT"
            exit 1
        else
            echo "🚀 Applying existing plan: $EXISTING_PLAN"
            if terraform apply -auto-approve "$EXISTING_PLAN"; then
                echo "✅ Terraform apply completed successfully"
                echo "DEPLOYMENT_SUCCESS=true" >> "$GITHUB_OUTPUT"
            else
                echo "❌ Terraform apply failed"
                echo "DEPLOYMENT_SUCCESS=false" >> "$GITHUB_OUTPUT"
                exit 1
            fi
        fi
        ;;
    
    "plan-and-apply")
        # plan-and-apply mode
        if [ -z "$PLAN_FILE" ]; then
            echo "❌ No plan file specified for apply"
            echo "🔍 Trying to find most recent plan file..."
            PLAN_FILE=$(ls -t tfplan-* 2>/dev/null | head -n 1 || echo "")
            if [ -z "$PLAN_FILE" ]; then
                echo "❌ No plan files found in current directory"
                echo "📁 Current directory contents:"
                ls -la
                echo "DEPLOYMENT_SUCCESS=false" >> "$GITHUB_OUTPUT"
                exit 1
            else
                echo "✅ Found plan file: $PLAN_FILE"
            fi
        fi
        
        # Check if plan file actually exists
        if [ ! -f "$PLAN_FILE" ]; then
            echo "❌ Plan file does not exist: $PLAN_FILE"
            echo "📁 Available plan files:"
            ls -la tfplan-* 2>/dev/null || echo "No plan files found"
            echo "DEPLOYMENT_SUCCESS=false" >> "$GITHUB_OUTPUT"
            exit 1
        fi
        
        echo "🚀 Applying Terraform plan: $PLAN_FILE"
        if terraform apply -auto-approve "$PLAN_FILE"; then
            echo "✅ Terraform deployment successful"
            echo "DEPLOYMENT_SUCCESS=true" >> "$GITHUB_OUTPUT"
        else
            echo "❌ Terraform deployment failed"
            echo "DEPLOYMENT_SUCCESS=false" >> "$GITHUB_OUTPUT"
            exit 1
        fi
        ;;
    
    *)
        echo "❌ Unknown Terraform mode: $TERRAFORM_MODE"
        echo "Valid modes: plan-only, apply-existing-plan, plan-and-apply"
        exit 1
        ;;
esac

# Capture outputs if deployment was successful and not plan-only
if [[ "$TERRAFORM_MODE" != "plan-only" && "$DEPLOYMENT_SUCCESS" == "true" ]]; then
    echo "📋 Extracting Terraform outputs..."
    set +e  # Don't exit if output extraction fails
    
    AKS_CLUSTER_NAME=$(terraform output -raw AKS_CLUSTER_NAME 2>/dev/null || echo "")
    AZURE_RESOURCE_GROUP_OUTPUT=$(terraform output -raw AZURE_RESOURCE_GROUP 2>/dev/null || echo "${AZURE_RESOURCE_GROUP}")
    CONTAINER_REGISTRY_ENDPOINT=$(terraform output -raw CONTAINER_REGISTRY_ENDPOINT 2>/dev/null || echo "")
    
    set -e
    
    echo "AKS_CLUSTER_NAME=$AKS_CLUSTER_NAME" >> "$GITHUB_OUTPUT"
    echo "AZURE_RESOURCE_GROUP=$AZURE_RESOURCE_GROUP_OUTPUT" >> "$GITHUB_OUTPUT"
    echo "CONTAINER_REGISTRY_ENDPOINT=$CONTAINER_REGISTRY_ENDPOINT" >> "$GITHUB_OUTPUT"
    echo "DEPLOYMENT_METHOD=terraform" >> "$GITHUB_OUTPUT"
    
    echo "✅ Infrastructure deployed successfully with Terraform!"
    echo "   AKS Cluster: $AKS_CLUSTER_NAME"
    echo "   Resource Group: $AZURE_RESOURCE_GROUP_OUTPUT"
    echo "   Container Registry: $CONTAINER_REGISTRY_ENDPOINT"
fi
