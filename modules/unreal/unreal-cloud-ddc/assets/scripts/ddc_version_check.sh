#!/bin/bash

# DDC Version Check - Verifies deployed versions
# Works with any DDC deployment (single or multi-region)

set -e

echo "🔍 DDC Version Check Starting..."
echo "==============================="

# Get cluster info from terraform outputs
REGION=$(terraform output -raw region 2>/dev/null || echo "us-west-2")
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null)

if [ -z "$CLUSTER_NAME" ]; then
    echo "❌ Could not get cluster name from terraform outputs"
    echo "💡 Run this from your terraform directory with deployed DDC"
    exit 1
fi

echo "📍 Region: $REGION"
echo "🎯 Cluster: $CLUSTER_NAME"
echo ""

# Configure kubectl
echo "🔧 Configuring kubectl..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

# Check Helm releases
echo ""
echo "📦 Helm Releases:"
helm list -n unreal-cloud-ddc

# Check pod versions
echo ""
echo "🏷️  Container Versions:"
kubectl get pods -n unreal-cloud-ddc -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}' | column -t

echo ""
echo "✅ Version check complete!"