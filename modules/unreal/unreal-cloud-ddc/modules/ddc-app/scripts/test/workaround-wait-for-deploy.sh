#!/bin/bash

# WORKAROUND: Wait for deploy CodeBuild to complete
# 
# PROBLEM: Terraform Actions bug where depends_on is ignored between action-triggered 
# resources, causing parallel execution instead of sequential deployment.
# 
# GitHub Issue: https://github.com/hashicorp/terraform/issues/xxxxx
# 
# SOLUTION: This script monitors the deploy CodeBuild project status using AWS CLI
# and waits for completion before allowing tests to proceed. This ensures:
# - Deploy completes before tests run
# - Test resources are available when tests execute
# - Sequential execution despite Terraform Actions bug
# 
# FUTURE: Remove this script when Terraform fixes the Actions dependency bug.
# Alternative solutions: CodePipeline or Step Functions for orchestration.
# 
# TODO: Update GitHub issue URL once submitted to HashiCorp

set -e

echo "🔄 WORKAROUND: Waiting for deployment CodeBuild to complete..."
echo "   This is needed due to Terraform Actions dependency bug"

DEPLOY_PROJECT_NAME="${NAME_PREFIX}-ddc-deployer"
echo "   Checking for running builds of project: $DEPLOY_PROJECT_NAME"

# Track if we've ever found the deploy project
PROJECT_FOUND=false

for i in {1..60}; do
  # Get all builds for the deploy project
  RUNNING_BUILDS=$(aws codebuild list-builds-for-project \
    --project-name "$DEPLOY_PROJECT_NAME" \
    --region "$AWS_REGION" \
    --query 'ids' \
    --output text 2>/dev/null || echo "")
  
  if [ -z "$RUNNING_BUILDS" ] || [ "$RUNNING_BUILDS" = "None" ]; then
    if [ "$PROJECT_FOUND" = "true" ]; then
      echo "   Deploy project builds completed, proceeding with tests"
      break
    else
      echo "   No builds found for deploy project (attempt $i/60) - retrying..."
      sleep 10
      continue
    fi
  fi
  
  # We found builds, so the project exists
  PROJECT_FOUND=true
  
  # Check if any builds are IN_PROGRESS
  BUILDS_STATUS=$(aws codebuild batch-get-builds \
    --ids $RUNNING_BUILDS \
    --region "$AWS_REGION" \
    --query 'builds[?buildStatus==`IN_PROGRESS`].id' \
    --output text 2>/dev/null || echo "")
  
  if [ -z "$BUILDS_STATUS" ]; then
    echo "   No IN_PROGRESS deploy builds found, proceeding with tests"
    break
  fi
  
  echo "   Deploy builds still running: $BUILDS_STATUS (attempt $i/60)"
  sleep 10
  
  if [ $i -eq 60 ]; then
    if [ "$PROJECT_FOUND" = "false" ]; then
      echo "❌ ERROR: Deploy project '$DEPLOY_PROJECT_NAME' not found after 10 minutes"
      echo "   Check NAME_PREFIX environment variable: '$NAME_PREFIX'"
      exit 1
    else
      echo "❌ Timeout waiting for deploy build after 10 minutes"
      exit 1
    fi
  fi
done

echo "✅ Deploy build completed, proceeding with tests"