#!/usr/bin/env bash
# scripts/get-task-ip.sh — Get the private IP of the running Lore ECS task.
# Requires: bash 4+, aws CLI
# Platforms: Linux, macOS, WSL2
# Usage: ./scripts/get-task-ip.sh [cluster] [service] [region]
set -euo pipefail

CLUSTER="${1:-lore-dev-cluster}"
SERVICE="${2:-lore-dev-loreserver}"
REGION="${3:-us-west-2}"

TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER" --service-name "$SERVICE" \
  --desired-status RUNNING --query 'taskArns[0]' --output text --region "$REGION")

if [[ "$TASK_ARN" == "None" || -z "$TASK_ARN" ]]; then
  echo "ERROR: No running tasks in $CLUSTER/$SERVICE" >&2
  exit 1
fi

IP=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ARN" --region "$REGION" \
  --query 'tasks[0].attachments[0].details[?name==`privateIPv4Address`].value|[0]' --output text)

echo "$CLUSTER/$SERVICE → $IP" >&2
echo "$IP"
