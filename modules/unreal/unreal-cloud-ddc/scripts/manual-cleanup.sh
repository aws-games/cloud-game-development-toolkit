#!/bin/bash
set -e

echo "Starting comprehensive EKS Auto Mode cleanup..."

# Validate required environment variables
required_vars=("CLUSTER_NAME" "NAMESPACE" "TIMEOUT_MINUTES" "AWS_REGION")
for var in "${required_vars[@]}"; do
  if [[ -z "${!var}" ]]; then
    echo "ERROR: Required environment variable $var is not set"
    exit 1
  fi
done

# Optional variables
TARGET_GROUP_ARN=${TARGET_GROUP_ARN:-""}
TGB_NAME=${TGB_NAME:-""}
PROJECT_PREFIX=${PROJECT_PREFIX:-"cgd"}

echo "Configuration:"
echo "  Cluster: ${CLUSTER_NAME}"
echo "  Region: ${AWS_REGION}"
echo "  Namespace: ${NAMESPACE}"
echo "  Project Prefix: ${PROJECT_PREFIX}"
echo "  TargetGroupBinding: ${TGB_NAME}"
echo "  Target Group ARN: ${TARGET_GROUP_ARN}"
echo "  Timeout: ${TIMEOUT_MINUTES} minutes"

# 1. Check if cluster exists
echo "Checking if EKS cluster exists..."
if ! aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" --no-cli-pager >/dev/null 2>&1; then
  echo "Cluster ${CLUSTER_NAME} does not exist - performing orphaned resource cleanup..."
  
  # Clean up orphaned load balancers
  echo "Scanning for orphaned load balancers..."
  aws elbv2 describe-load-balancers --region "${AWS_REGION}" --query "LoadBalancers[?contains(LoadBalancerName, '${CLUSTER_NAME}') || contains(LoadBalancerName, '${PROJECT_PREFIX}')].LoadBalancerArn" --output text | tr '\t' '\n' | while read -r LB_ARN; do
    if [ -n "$LB_ARN" ]; then
      echo "Deleting orphaned load balancer: $LB_ARN"
      aws elbv2 delete-load-balancer --load-balancer-arn "$LB_ARN" --region "${AWS_REGION}" || true
    fi
  done
  
  # Clean up orphaned target groups
  echo "Scanning for orphaned target groups..."
  aws elbv2 describe-target-groups --region "${AWS_REGION}" --query "TargetGroups[?contains(TargetGroupName, '${CLUSTER_NAME}') || contains(TargetGroupName, '${PROJECT_PREFIX}')].TargetGroupArn" --output text | tr '\t' '\n' | while read -r TG_ARN; do
    if [ -n "$TG_ARN" ]; then
      echo "Deleting orphaned target group: $TG_ARN"
      aws elbv2 delete-target-group --target-group-arn "$TG_ARN" --region "${AWS_REGION}" || true
    fi
  done
  
  # Clean up orphaned security groups
  echo "Scanning for orphaned security groups..."
  aws ec2 describe-security-groups --region "${AWS_REGION}" --filters "Name=group-name,Values=*${CLUSTER_NAME}*,*${PROJECT_PREFIX}*" --query "SecurityGroups[].GroupId" --output text | tr '\t' '\n' | while read -r SG_ID; do
    if [ -n "$SG_ID" ]; then
      echo "Deleting orphaned security group: $SG_ID"
      aws ec2 delete-security-group --group-id "$SG_ID" --region "${AWS_REGION}" || true
    fi
  done
  
  echo "Orphaned resource cleanup completed"
  exit 0
fi

# 2. Cluster exists - perform graceful cleanup
echo "Cluster exists - performing graceful cleanup..."
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}" --no-cli-pager

# 3. Delete all LoadBalancer services FIRST
echo "Deleting all LoadBalancer services to trigger AWS Load Balancer Controller cleanup..."
kubectl get services --all-namespaces -o json | jq -r '.items[] | select(.spec.type=="LoadBalancer") | "\(.metadata.namespace) \(.metadata.name)"' | while read -r NS SVC; do
  if [ -n "$SVC" ]; then
    echo "Deleting LoadBalancer service: $NS/$SVC"
    kubectl delete service "$SVC" -n "$NS" --timeout=60s || true
  fi
done

# 4. Delete specific TargetGroupBinding if provided
if [ -n "${TGB_NAME}" ]; then
  echo "Deleting TargetGroupBinding: ${TGB_NAME}..."
  kubectl delete targetgroupbinding "${TGB_NAME}" -n "${NAMESPACE}" --ignore-not-found=true --timeout=60s || true
fi

# 5. Delete all Ingress resources
echo "Deleting all Ingress resources..."
kubectl delete ingress --all --all-namespaces --timeout=60s || true

# 6. Wait for AWS Load Balancer Controller to complete cleanup
echo "Waiting 30s for AWS Load Balancer Controller to complete cleanup..."
sleep 30

# 7. Get VPC ID for ENI filtering (if target group provided)
VPC_ID=""
if [ -n "${TARGET_GROUP_ARN}" ]; then
  echo "Getting VPC ID from target group..."
  VPC_ID=$(aws elbv2 describe-target-groups \
    --target-group-arns "${TARGET_GROUP_ARN}" \
    --query 'TargetGroups[0].VpcId' --output text --no-cli-pager --region "${AWS_REGION}" 2>/dev/null || echo "")
fi

if [[ "$VPC_ID" == "None" || -z "$VPC_ID" ]]; then
  echo "No specific VPC ID available - checking all cluster-related resources..."
else
  echo "VPC ID: ${VPC_ID}"
fi

# 8. Wait for all AWS resources to be cleaned up (comprehensive check)
MAX_ATTEMPTS=$((TIMEOUT_MINUTES * 6))  # 10-second intervals
ATTEMPT=0

echo "Polling AWS for comprehensive cleanup completion..."

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))
  
  # Check load balancers
  LB_COUNT=$(aws elbv2 describe-load-balancers --region "${AWS_REGION}" \
    --query "length(LoadBalancers[?contains(LoadBalancerName, '${CLUSTER_NAME}') || contains(LoadBalancerName, '${PROJECT_PREFIX}')])" \
    --output text --no-cli-pager 2>/dev/null || echo "0")
  
  # Check target groups
  TG_COUNT=$(aws elbv2 describe-target-groups --region "${AWS_REGION}" \
    --query "length(TargetGroups[?contains(TargetGroupName, '${CLUSTER_NAME}') || contains(TargetGroupName, '${PROJECT_PREFIX}')])" \
    --output text --no-cli-pager 2>/dev/null || echo "0")
  
  # Check security groups
  SG_COUNT=$(aws ec2 describe-security-groups --region "${AWS_REGION}" \
    --filters "Name=group-name,Values=*${CLUSTER_NAME}*,*${PROJECT_PREFIX}*" \
    --query 'length(SecurityGroups)' --output text --no-cli-pager 2>/dev/null || echo "0")
  
  # Check ENIs (if VPC ID available)
  ENI_COUNT="0"
  if [ -n "${VPC_ID}" ]; then
    ENI_COUNT=$(aws ec2 describe-network-interfaces --region "${AWS_REGION}" \
      --filters "Name=vpc-id,Values=${VPC_ID}" \
                "Name=description,Values=*${CLUSTER_NAME}*" \
                "Name=status,Values=in-use" \
      --query 'length(NetworkInterfaces)' --output text --no-cli-pager 2>/dev/null || echo "0")
  fi
  
  # Check target attachments (if target group ARN available)
  TARGET_COUNT="0"
  if [ -n "${TARGET_GROUP_ARN}" ]; then
    TARGET_COUNT=$(aws elbv2 describe-target-health --region "${AWS_REGION}" \
      --target-group-arn "${TARGET_GROUP_ARN}" \
      --query 'length(TargetHealthDescriptions)' --output text --no-cli-pager 2>/dev/null || echo "0")
  fi
  
  echo "Attempt ${ATTEMPT}/${MAX_ATTEMPTS}: LBs=${LB_COUNT}, TGs=${TG_COUNT}, SGs=${SG_COUNT}, ENIs=${ENI_COUNT}, Targets=${TARGET_COUNT}"
  
  # Success: No remaining AWS resources
  if [ "$LB_COUNT" = "0" ] && [ "$TG_COUNT" = "0" ] && [ "$SG_COUNT" = "0" ] && [ "$ENI_COUNT" = "0" ] && [ "$TARGET_COUNT" = "0" ]; then
    echo "SUCCESS: All EKS Auto Mode resources cleaned up after $((ATTEMPT * 10)) seconds"
    exit 0
  fi
  
  # Timeout with comprehensive diagnostic info
  if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "TIMEOUT: Cleanup incomplete after $((MAX_ATTEMPTS * 10)) seconds"
    echo "Remaining resources:"
    echo "   Load Balancers: ${LB_COUNT}"
    echo "   Target Groups: ${TG_COUNT}"
    echo "   Security Groups: ${SG_COUNT}"
    echo "   ENIs: ${ENI_COUNT}"
    echo "   Target attachments: ${TARGET_COUNT}"
    echo ""
    echo "Manual cleanup commands:"
    echo "   # List remaining load balancers:"
    echo "   aws elbv2 describe-load-balancers --region ${AWS_REGION} --query \"LoadBalancers[?contains(LoadBalancerName, '${CLUSTER_NAME}') || contains(LoadBalancerName, '${PROJECT_PREFIX}')]\""
    echo "   # List remaining security groups:"
    echo "   aws ec2 describe-security-groups --region ${AWS_REGION} --filters \"Name=group-name,Values=*${CLUSTER_NAME}*,*${PROJECT_PREFIX}*\""
    if [ -n "${VPC_ID}" ]; then
      echo "   # List remaining ENIs:"
      echo "   aws ec2 describe-network-interfaces --region ${AWS_REGION} --filters \"Name=vpc-id,Values=${VPC_ID}\" \"Name=description,Values=*${CLUSTER_NAME}*\""
    fi
    exit 1
  fi
  
  sleep 10
done