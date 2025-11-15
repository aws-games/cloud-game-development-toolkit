#!/bin/bash
set -e

echo "Starting comprehensive DDC cleanup..."

# Validate required environment variables
required_vars=("TARGET_GROUP_ARN" "CLUSTER_NAME" "NAMESPACE" "TGB_NAME" "TIMEOUT_MINUTES" "AWS_REGION")
for var in "${required_vars[@]}"; do
  if [[ -z "${!var}" ]]; then
    echo "ERROR: Required environment variable $var is not set"
    exit 1
  fi
done

echo "Configuration:"
echo "  Cluster: ${CLUSTER_NAME}"
echo "  Region: ${AWS_REGION}"
echo "  Namespace: ${NAMESPACE}"
echo "  TargetGroupBinding: ${TGB_NAME}"
echo "  Target Group ARN: ${TARGET_GROUP_ARN}"
echo "  Timeout: ${TIMEOUT_MINUTES} minutes"

# 1. Update kubeconfig for cluster access
echo "Updating kubeconfig for cluster access..."
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}" --no-cli-pager

# 2. Delete Kubernetes resource
echo "Deleting TargetGroupBinding..."
kubectl delete targetgroupbinding "${TGB_NAME}" -n "${NAMESPACE}" --ignore-not-found=true

# 3. Get VPC ID for ENI filtering
echo "Getting VPC ID from target group..."
VPC_ID=$(aws elbv2 describe-target-groups \
  --target-group-arns "${TARGET_GROUP_ARN}" \
  --query 'TargetGroups[0].VpcId' --output text --no-cli-pager)

if [[ "$VPC_ID" == "None" || -z "$VPC_ID" ]]; then
  echo "WARNING: Could not determine VPC ID from target group, skipping ENI cleanup"
  echo "Cleanup complete (target group may already be deleted)"
  exit 0
fi

echo "VPC ID: ${VPC_ID}"

# 4. Wait for ENIs to be cleaned up (authoritative check)
MAX_ATTEMPTS=$((TIMEOUT_MINUTES * 6))  # 10-second intervals
ATTEMPT=0

echo "Polling AWS for cleanup completion..."

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))
  
  # Check ENIs (primary concern)
  ENI_COUNT=$(aws ec2 describe-network-interfaces \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
              "Name=description,Values=*${CLUSTER_NAME}*" \
              "Name=status,Values=in-use" \
    --query 'length(NetworkInterfaces)' --output text --no-cli-pager)
  
  # Check target attachments
  ALL_TARGETS=$(aws elbv2 describe-target-health \
    --target-group-arn "${TARGET_GROUP_ARN}" \
    --query 'length(TargetHealthDescriptions)' --output text --no-cli-pager 2>/dev/null || echo "0")
  
  echo "Attempt ${ATTEMPT}/${MAX_ATTEMPTS}: ENIs=${ENI_COUNT}, Targets=${ALL_TARGETS}"
  
  # Success: No ENIs and no target attachments
  if [ "$ENI_COUNT" = "0" ] && [ "$ALL_TARGETS" = "0" ]; then
    echo "Cleanup complete after $((ATTEMPT * 10)) seconds"
    exit 0
  fi
  
  # Timeout with diagnostic info
  if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "TIMEOUT: Cleanup incomplete after $((MAX_ATTEMPTS * 10)) seconds"
    echo "Remaining resources:"
    echo "   ENIs: ${ENI_COUNT}"
    echo "   Target attachments: ${ALL_TARGETS}"
    echo ""
    echo "Manual cleanup may be required:"
    echo "   aws ec2 describe-network-interfaces --filters \"Name=vpc-id,Values=${VPC_ID}\" \"Name=description,Values=*${CLUSTER_NAME}*\""
    echo "   aws elbv2 describe-target-health --target-group-arn ${TARGET_GROUP_ARN}"
    exit 1
  fi
  
  sleep 10
done