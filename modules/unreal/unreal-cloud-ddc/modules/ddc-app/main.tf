
################################################################################
# EKS Cluster Readiness
################################################################################

# LEGACY: EKS Cluster Readiness (replaced by CodeBuild dependency)
# resource "null_resource" "wait_for_eks_ready" {
#   provisioner "local-exec" {
#     command = <<-EOT
#       set -e
#       echo "[EKS-READY] Waiting for EKS cluster ${var.cluster_name} to be active (max 15 minutes)..."
# 
#       # Use timeout wrapper for faster failure detection
#       if timeout 15m aws eks wait cluster-active --name ${var.cluster_name} --region ${var.region}${var.debug ? " --debug" : null}; then
#         echo "[EKS-READY] SUCCESS: EKS cluster is now active"
#       else
#         EXIT_CODE=$?
#         echo "[EKS-READY] ERROR: EKS cluster failed to become active within 15 minutes"
#         echo "[EKS-READY] TROUBLESHOOTING: Run these commands to diagnose:"
#         echo "[EKS-READY]   1. Check cluster status: aws eks describe-cluster --name ${var.cluster_name} --region ${var.region}"
#         echo "[EKS-READY]   2. Check CloudFormation events: aws cloudformation describe-stack-events --stack-name eksctl-${var.cluster_name}-cluster"
#         echo "[EKS-READY]   3. Check IAM permissions for EKS service role"
#         echo "[EKS-READY]   4. Verify VPC/subnet configuration and availability zones"
#         echo "[EKS-READY] Exit code: $EXIT_CODE"
#         exit $EXIT_CODE
#       fi
#     EOT
#   }
# }



################################################################################
# DDC Application Deployment - REPLACED WITH CODEBUILD SOLUTION
################################################################################

# OLD BROKEN APPROACH - COMMENTED OUT FOR ROLLBACK
# resource "null_resource" "helm_ddc_app" {
#   triggers = {
#     cluster_name = var.cluster_name
#     region = var.region
#     namespace = var.namespace
#     name_prefix = local.name_prefix
#     values_hash = md5(local.helm_values_yaml)
#   }
#
#   provisioner "local-exec" {
#     # 200+ lines of problematic local-exec logic
#   }
#
#   provisioner "local-exec" {
#     when = destroy
#     # 100+ lines of problematic cleanup logic
#   }
#
#   depends_on = [
#     null_resource.wait_for_eks_ready
#   ]
# }

# NEW CODEBUILD SOLUTION - TRIGGERS AFTER EKS CLUSTER EXISTS
# The terraform_data resource and action are defined in codebuild.tf
# This ensures DDC deployment happens AFTER EKS cluster is ready

################################################################################
# (Optional) Testing: Single-Region DDC Functional Validation
################################################################################

# LEGACY: Single-Region DDC Functional Validation (replaced by CodeBuild)
# resource "null_resource" "ddc_single_region_readiness_check" {
#   count = var.ddc_application_config.enable_single_region_validation ? 1 : 0
# 
#   triggers = {
#     cluster_name = var.cluster_name
#     region = var.region
#     deployment_hash = "codebuild-deployment"  # NEW: Reference CodeBuild deployment
#   }
# 
#   provisioner "local-exec" {
#     interpreter = ["/bin/bash", "-c"]
#     command = <<-EOT
#       set -e
#       echo "[DDC-READINESS] Waiting for DDC service to fully initialize..."
#       sleep 30
#       
#       # Use path relative to where terraform is executed
#       SCRIPT_PATH="../../../assets/scripts/ddc_functional_test.sh"
#       
#       if [ ! -f "$SCRIPT_PATH" ]; then
#         echo "[DDC-READINESS] ERROR: Single-region functional test script not found at $SCRIPT_PATH"
#         echo "[DDC-READINESS] Make sure you're running terraform from an example directory"
#         exit 1
#       fi
#       
#       chmod +x "$SCRIPT_PATH"
#       
#       # Retry logic for DDC readiness
#       echo "[DDC-READINESS] Running single-region DDC functional test with retry..."
#       for i in {1..10}; do
#         echo "[DDC-READINESS] Attempt $i/10..."
#         if "$SCRIPT_PATH"; then
#           echo "[DDC-READINESS] SUCCESS: Single-region functional test completed"
#           exit 0
#         else
#           echo "[DDC-READINESS] Attempt $i failed, waiting 60s before retry..."
#           sleep 60
#         fi
#       done
#       
#       echo "[DDC-READINESS] ERROR: All 10 attempts failed"
#       exit 1
#     EOT
#   }
# 
#   depends_on = [
#     terraform_data.deploy_trigger  # NEW: Depends on CodeBuild deployment
#   ]
# }

################################################################################
# (Optional) Testing: Multi-Region DDC Functional Validation
################################################################################

# LEGACY: Multi-Region DDC Functional Validation (replaced by CodeBuild)
# resource "null_resource" "ddc_multi_region_readiness_check" {
#   count = var.ddc_application_config.enable_multi_region_validation ? 1 : 0
# 
#   triggers = {
#     cluster_name = var.cluster_name
#     region = var.region
#     deployment_hash = "codebuild-deployment"  # NEW: Reference CodeBuild deployment
#     peer_endpoint = var.ddc_application_config.peer_region_ddc_endpoint
#   }
# 
#   provisioner "local-exec" {
#     interpreter = ["/bin/bash", "-c"]
#     command = <<-EOT
#       set -e
#       echo "[DDC-MULTI-REGION] Running multi-region DDC functional test..."
#       
#       # Use path relative to where terraform is executed
#       SCRIPT_PATH="../../../assets/scripts/ddc_functional_test_multi_region.sh"
#       
#       if [ ! -f "$SCRIPT_PATH" ]; then
#         echo "[DDC-MULTI-REGION] ERROR: Multi-region functional test script not found at $SCRIPT_PATH"
#         exit 1
#       fi
#       
#       chmod +x "$SCRIPT_PATH"
#       "$SCRIPT_PATH"
#       
#       echo "[DDC-MULTI-REGION] SUCCESS: Multi-region functional test completed"
#     EOT
#   }
# 
#   depends_on = [
#     terraform_data.deploy_trigger  # NEW: Depends on CodeBuild deployment
#   ]
# }

################################################################################
# ScyllaDB Multi-Region Keyspace Configuration
################################################################################

# LEGACY: ScyllaDB Multi-Region Keyspace Configuration (replaced by CodeBuild)
# resource "null_resource" "trigger_ssm_keyspace_update" {
#   count = var.database_connection.type == "scylla" && var.ssm_document_name != null ? 1 : 0
# 
#   triggers = {
#     # Trigger only once per deployment (not on every Helm upgrade)
#     deployment_complete = "${local.name_prefix}-initialize"
#   }
# 
#   provisioner "local-exec" {
#     command = <<-EOT
#       echo "[SCYLLA-KEYSPACE] Configuring ScyllaDB keyspaces for multi-region replication..."
#       echo "[SCYLLA-KEYSPACE] This creates keyspaces with NetworkTopologyStrategy across all regions"
# 
#       # Wait for DDC to create initial keyspaces in local region
#       echo "[SCYLLA-KEYSPACE] Waiting 60s for DDC to create local keyspaces..."
#       sleep 60
# 
#       # Execute SSM document on ScyllaDB seed node
#       # This runs CQL commands to alter keyspace replication settings
#       echo "[SCYLLA-KEYSPACE] Executing SSM document on seed node ${var.scylla_seed_instance_id}..."
#       aws ssm send-command \
#         --region ${var.region} \
#         --document-name "${var.ssm_document_name}" \
#         --instance-ids "${var.scylla_seed_instance_id}" \
#         --comment "Configure ScyllaDB keyspaces for multi-region DDC replication" \
#         ${var.debug ? "--debug" : ""}
# 
#       echo "[SCYLLA-KEYSPACE] SSM command sent - keyspace configuration in progress"
#       echo "[SCYLLA-KEYSPACE] Note: This is async - keyspaces will be configured in background"
#     EOT
#   }
# 
#   depends_on = [
#     terraform_data.deploy_trigger  # NEW: Depends on CodeBuild deployment
#   ]
# }