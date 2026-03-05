#!/bin/bash
# ⚠️  INTERNAL CODEBUILD SCRIPT - DO NOT RUN MANUALLY ⚠️
# This script is designed for CodeBuild environments only.
# For manual deployment, use kubectl commands directly.
# This script expects kubectl access and specific environment variables.

set -e

echo "[DDC-DEPLOY] Starting DDC Helm deployment..."
echo "[DDC-DEPLOY] Chart reference: $DDC_CHART"

# Check for existing Helm releases and clean up if needed
echo "[DDC-DEPLOY] Checking for existing Helm releases..."
if helm list -n $NAMESPACE | grep -q $NAME_PREFIX-app; then
    echo "[DDC-DEPLOY] Found existing Helm release, checking service health..."
    
    # Check if service exists and is healthy after potential K8s upgrade
    if ! kubectl get service $NAME_PREFIX -n $NAMESPACE >/dev/null 2>&1; then
        echo "[DDC-DEPLOY] Service missing after K8s upgrade, cleaning Helm state..."
        helm uninstall $NAME_PREFIX-app -n $NAMESPACE || true
        sleep 10
    elif ! kubectl get pods -l app.kubernetes.io/name=unreal-cloud-ddc -n $NAMESPACE >/dev/null 2>&1; then
        echo "[DDC-DEPLOY] Pods missing, cleaning Helm state..."
        helm uninstall $NAME_PREFIX-app -n $NAMESPACE || true
        sleep 10
    else
        echo "[DDC-DEPLOY] Existing release appears healthy, proceeding with upgrade..."
    fi
fi

# Deploy DDC via Helm
if [[ "$DDC_CHART" == *"+helm" ]]; then
    echo "[DDC-DEPLOY] Deploying Epic chart with GHCR authentication"
    
    # Get GHCR credentials
    echo "[DDC-DEPLOY] Retrieving GHCR credentials from $GHCR_SECRET_ARN"
    SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id $GHCR_SECRET_ARN --region $AWS_REGION --query SecretString --output text)
    GHCR_USERNAME=$(echo "$SECRET_JSON" | jq -r .username)
    GHCR_TOKEN=$(echo "$SECRET_JSON" | jq -r .accessToken)
    
    # Validate credentials
    if [ "$GHCR_USERNAME" = "null" ] || [ "$GHCR_TOKEN" = "null" ]; then
        echo "[DDC-DEPLOY] ERROR: Invalid GHCR credentials in secret"
        exit 1
    fi
    
    # Login to GHCR
    echo "[DDC-DEPLOY] Logging into GHCR as $GHCR_USERNAME"
    echo "$GHCR_TOKEN" | helm registry login ghcr.io --username "$GHCR_USERNAME" --password-stdin
    
    # Pull and deploy chart
    echo "[DDC-DEPLOY] Pulling chart..."
    helm pull oci://ghcr.io/epicgames/unreal-cloud-ddc --version 1.2.0+helm
    CHART_FILE="unreal-cloud-ddc-1.2.0+helm.tgz"
    
    echo "[DDC-DEPLOY] Deploying from local chart: $CHART_FILE"
    helm upgrade --install $NAME_PREFIX-app "$CHART_FILE" \
        --namespace $NAMESPACE \
        --create-namespace \
        --values /tmp/ddc-helm-values.yaml \
        --wait --timeout=600s
    
    rm -f "$CHART_FILE"
else
    echo "[DDC-DEPLOY] Deploying chart directly: $DDC_CHART"
    helm upgrade --install $NAME_PREFIX-app "$DDC_CHART" \
        --namespace $NAMESPACE \
        --create-namespace \
        --values /tmp/ddc-helm-values.yaml \
        --wait --timeout=600s
fi

echo "[DDC-DEPLOY] Waiting for DDC pods to be ready..."
if ! kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=unreal-cloud-ddc -n $NAMESPACE --timeout=300s; then
    echo "[DDC-DEPLOY] ERROR: Pods failed to become ready, debugging..."
    echo "[DDC-DEPLOY] Pod status:"
    kubectl get pods -n $NAMESPACE -o wide
    echo "[DDC-DEPLOY] Pod events:"
    kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'
    echo "[DDC-DEPLOY] Describing failed pods:"
    kubectl get pods -n $NAMESPACE -o name | xargs -I {} kubectl describe {} -n $NAMESPACE
    echo "[DDC-DEPLOY] Node resources:"
    kubectl top nodes || echo "Metrics server not available"
    exit 1
fi

echo "[DDC-DEPLOY] Deployment status:"
kubectl get pods -n $NAMESPACE
kubectl get services -n $NAMESPACE

# Configure ScyllaDB keyspaces if enabled
if [ "$SCYLLA_KEYSPACE_ENABLED" = "true" ] && [ -n "$SSM_DOCUMENT_NAME" ] && [ -n "$SCYLLA_SEED_INSTANCE_ID" ]; then
    echo "[DDC-DEPLOY] Configuring ScyllaDB keyspaces"
    aws ssm send-command --region $AWS_REGION --document-name "$SSM_DOCUMENT_NAME" --instance-ids "$SCYLLA_SEED_INSTANCE_ID" --comment "Configure ScyllaDB keyspaces"
fi

echo "[DDC-DEPLOY] SUCCESS: DDC Helm deployment completed"