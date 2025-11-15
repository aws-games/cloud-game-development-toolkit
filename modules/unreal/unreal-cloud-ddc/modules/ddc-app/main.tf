
################################################################################
# EKS Cluster Readiness
################################################################################

resource "null_resource" "wait_for_eks_ready" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "[EKS-READY] Waiting for EKS cluster ${var.cluster_name} to be active (max 15 minutes)..."

      # Use timeout wrapper for faster failure detection
      if timeout 15m aws eks wait cluster-active --name ${var.cluster_name} --region ${var.region}${var.debug ? " --debug" : null}; then
        echo "[EKS-READY] SUCCESS: EKS cluster is now active"
      else
        EXIT_CODE=$?
        echo "[EKS-READY] ERROR: EKS cluster failed to become active within 15 minutes"
        echo "[EKS-READY] TROUBLESHOOTING: Run these commands to diagnose:"
        echo "[EKS-READY]   1. Check cluster status: aws eks describe-cluster --name ${var.cluster_name} --region ${var.region}"
        echo "[EKS-READY]   2. Check CloudFormation events: aws cloudformation describe-stack-events --stack-name eksctl-${var.cluster_name}-cluster"
        echo "[EKS-READY]   3. Check IAM permissions for EKS service role"
        echo "[EKS-READY]   4. Verify VPC/subnet configuration and availability zones"
        echo "[EKS-READY] Exit code: $EXIT_CODE"
        exit $EXIT_CODE
      fi
    EOT
  }
}

################################################################################
# DDC Application Deployment
################################################################################

resource "null_resource" "helm_ddc_app" {
  triggers = {
    cluster_name = var.cluster_name
    region = var.region
    namespace = var.namespace
    name_prefix = local.name_prefix
    values_hash = md5(local.helm_values_yaml)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      echo "[DDC-APP] Starting DDC application installation..."

      # Step 1: Configure kubectl access
      echo "[DDC-APP] Configuring kubectl access to cluster ${var.cluster_name}..."
      aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.region}

      # Step 2: Wait for cluster API readiness (EKS Auto Mode creates nodes on-demand)
      echo "[DDC-APP] Waiting for cluster API to be ready..."
      kubectl cluster-info --request-timeout=30s

      # Step 3: Detect chart type and handle accordingly
      CHART_REF="${var.ddc_application_config.helm_chart}"
      echo "[DDC-APP] Chart reference: $CHART_REF"
      
      # Step 4: Check for existing Helm releases and clean up if needed
      echo "[DDC-APP] Checking for existing Helm releases..."
      if helm list -n ${var.namespace} | grep -q ${local.name_prefix}-app; then
        echo "[DDC-APP] Found existing Helm release, cleaning up first..."
        helm uninstall ${local.name_prefix}-app -n ${var.namespace} || true
        sleep 10
      fi

      # Step 5: Deploy chart (handle Epic's +helm version tags)
      if [[ "$CHART_REF" == *"+helm" ]]; then
        echo "[DDC-APP] Deploying Epic's chart with GHCR authentication (pull-then-deploy)"
        
        # Authenticate to GHCR
        GHCR_USERNAME=$(aws secretsmanager get-secret-value --secret-id ${var.ghcr_credentials_secret_arn} --region ${var.region} --query SecretString --output text | jq -r .username)
        GHCR_TOKEN=$(aws secretsmanager get-secret-value --secret-id ${var.ghcr_credentials_secret_arn} --region ${var.region} --query SecretString --output text | jq -r .accessToken)
        echo "$GHCR_TOKEN" | helm registry login ghcr.io --username "$GHCR_USERNAME" --password-stdin
        
        # Pull chart to local cache (Helm handles +helm -> _helm conversion)
        echo "[DDC-APP] Pulling chart..."
        helm pull oci://ghcr.io/epicgames/unreal-cloud-ddc --version 1.2.0+helm
        
        # Deploy from local tarball (Helm creates filename with +helm)
        CHART_FILE="unreal-cloud-ddc-1.2.0+helm.tgz"
        echo "[DDC-APP] Deploying from local chart: $CHART_FILE"
        helm upgrade --install ${local.name_prefix}-app "$CHART_FILE" \
          --namespace ${var.namespace} \
          --create-namespace \
          --values "${local_file.ddc_helm_values.filename}" \
          ${var.debug ? "--debug" : ""} \
          --wait --timeout=300s
        
        # Clean up local chart file
        rm -f "$CHART_FILE"
      else
        # Deploy other charts directly
        echo "[DDC-APP] Deploying chart directly: $CHART_REF"
        helm upgrade --install ${local.name_prefix}-app "$CHART_REF" \
          --namespace ${var.namespace} \
          --create-namespace \
          --values "${local_file.ddc_helm_values.filename}" \
          ${var.debug ? "--debug" : ""} \
          --wait --timeout=300s
      fi

      echo "[DDC-APP] SUCCESS: DDC application installation completed successfully"
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      echo "[DDC-APP CLEANUP] Starting comprehensive EKS Auto Mode cleanup..."

      # Configure kubectl (ignore failures if cluster deleted)
      if ! aws eks update-kubeconfig --name ${self.triggers.cluster_name} --region ${self.triggers.region}; then
        echo "[DDC-APP CLEANUP] Cluster already deleted, checking for orphaned AWS resources..."
        
        # Clean up orphaned load balancers
        echo "[DDC-APP CLEANUP] Scanning for orphaned load balancers..."
        aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, '${self.triggers.cluster_name}')].LoadBalancerArn" --output text | while read -r LB_ARN; do
          if [ -n "$LB_ARN" ]; then
            echo "[DDC-APP CLEANUP] Deleting orphaned load balancer: $LB_ARN"
            aws elbv2 delete-load-balancer --load-balancer-arn "$LB_ARN" || true
          fi
        done
        
        # Clean up orphaned security groups
        echo "[DDC-APP CLEANUP] Scanning for orphaned security groups..."
        aws ec2 describe-security-groups --filters "Name=group-name,Values=*${self.triggers.cluster_name}*" --query "SecurityGroups[].GroupId" --output text | tr '\t' '\n' | while read -r SG_ID; do
          if [ -n "$SG_ID" ]; then
            echo "[DDC-APP CLEANUP] Deleting orphaned security group: $SG_ID"
            aws ec2 delete-security-group --group-id "$SG_ID" || true
          fi
        done
        
        echo "[DDC-APP CLEANUP] Orphaned resource cleanup completed"
        exit 0
      }

      # Cluster is still active - perform graceful cleanup
      echo "[DDC-APP CLEANUP] Cluster active - performing graceful cleanup..."
      
      # Step 1: Delete all Services with LoadBalancer type FIRST (triggers LBC cleanup)
      echo "[DDC-APP CLEANUP] Deleting LoadBalancer services to trigger AWS Load Balancer Controller cleanup..."
      kubectl get services --all-namespaces -o json | jq -r '.items[] | select(.spec.type=="LoadBalancer") | "\(.metadata.namespace) \(.metadata.name)"' | while read -r NAMESPACE SERVICE; do
        if [ -n "$SERVICE" ]; then
          echo "[DDC-APP CLEANUP] Deleting LoadBalancer service: $NAMESPACE/$SERVICE"
          kubectl delete service "$SERVICE" -n "$NAMESPACE" --timeout=60s || true
        fi
      done
      
      # Step 2: Delete all Ingress resources (triggers ALB cleanup if any)
      echo "[DDC-APP CLEANUP] Deleting Ingress resources..."
      kubectl delete ingress --all --all-namespaces --timeout=60s || true
      
      # Step 3: Clean up DDC Helm release
      echo "[DDC-APP CLEANUP] Cleaning up DDC Helm release..."
      helm uninstall ${self.triggers.name_prefix}-app -n ${self.triggers.namespace} --timeout=120s || true
      
      # Step 4: Wait for controllers to complete cleanup (check finalizers)
      echo "[DDC-APP CLEANUP] Waiting for controllers to remove finalizers..."
      for i in {1..24}; do  # 12 minutes max (24 * 30s)
        REMAINING_FINALIZERS=$(kubectl get svc,ingress --all-namespaces -o json 2>/dev/null | jq '[.items[] | select(.metadata.finalizers != null)] | length' || echo "0")
        if [ "$REMAINING_FINALIZERS" -eq 0 ]; then
          echo "[DDC-APP CLEANUP] SUCCESS: All finalizers removed by controllers"
          break
        fi
        echo "[DDC-APP CLEANUP] Waiting for $REMAINING_FINALIZERS resources with finalizers... (attempt $i/24)"
        sleep 30
        if [ $i -eq 24 ]; then
          echo "[DDC-APP CLEANUP] WARNING: Timeout waiting for finalizers - checking controller health..."
          
          # Check controller health
          LBC_PODS=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --no-headers 2>/dev/null | wc -l)
          EDNS_PODS=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=external-dns --no-headers 2>/dev/null | wc -l)
          
          echo "[DDC-APP CLEANUP] AWS Load Balancer Controller pods: $LBC_PODS"
          echo "[DDC-APP CLEANUP] External-DNS pods: $EDNS_PODS"
          
          # Show stuck resources
          echo "[DDC-APP CLEANUP] Resources still with finalizers:"
          kubectl get svc,ingress --all-namespaces -o json | jq '.items[] | select(.metadata.finalizers != null) | {name: .metadata.name, namespace: .metadata.namespace, finalizers: .metadata.finalizers}'
          
          # CRITICAL: Halt terraform destroy to prevent orphaned resources
          echo "[DDC-APP CLEANUP] ERROR: Cleanup timeout - manual intervention required"
          echo "[DDC-APP CLEANUP] ERROR: Controllers failed to remove finalizers within 12 minutes"
          echo "[DDC-APP CLEANUP] ERROR: Halting terraform destroy to prevent orphaned AWS resources"
          exit 1
        fi
      done
      
      # Step 5: Final verification - check for remaining AWS resources
      echo "[DDC-APP CLEANUP] Verifying AWS Load Balancer Controller cleanup..."
      REMAINING_LBS=$(aws elbv2 describe-load-balancers --region ${self.triggers.region} --output json 2>/dev/null | jq -r ".LoadBalancers[] | select(.LoadBalancerName | startswith(\"k8s-\")) | .LoadBalancerArn" || echo "")
      if [ -n "$REMAINING_LBS" ]; then
        echo "[DDC-APP CLEANUP] WARNING: Load balancers still exist after cleanup: $REMAINING_LBS"
      else
        echo "[DDC-APP CLEANUP] SUCCESS: No load balancers remain"
      fi
      
      echo "[DDC-APP CLEANUP] Verifying External-DNS cleanup..."
      # Note: Cannot verify Route53 records without hosted zone ID
      # External-DNS cleanup is verified by finalizer removal above
      echo "[DDC-APP CLEANUP] External-DNS cleanup verified via finalizer removal"

      echo "[DDC-APP CLEANUP] SUCCESS: Comprehensive cleanup completed"
    EOT
  }

  depends_on = [
    null_resource.wait_for_eks_ready
  ]
}

################################################################################
# (Optional) Testing: Single-Region DDC Functional Validation
################################################################################

resource "null_resource" "ddc_single_region_readiness_check" {
  count = var.ddc_application_config.enable_single_region_validation ? 1 : 0

  triggers = {
    cluster_name = var.cluster_name
    region = var.region
    deployment_hash = null_resource.helm_ddc_app.triggers.values_hash
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      echo "[DDC-READINESS] Running single-region DDC functional test..."
      
      # Use path relative to where terraform is executed
      SCRIPT_PATH="../../../assets/scripts/ddc_functional_test.sh"
      
      if [ ! -f "$SCRIPT_PATH" ]; then
        echo "[DDC-READINESS] ERROR: Single-region functional test script not found at $SCRIPT_PATH"
        echo "[DDC-READINESS] Make sure you're running terraform from an example directory"
        exit 1
      fi
      
      chmod +x "$SCRIPT_PATH"
      "$SCRIPT_PATH"
      
      echo "[DDC-READINESS] SUCCESS: Single-region functional test completed"
    EOT
  }

  depends_on = [
    null_resource.helm_ddc_app
  ]
}

################################################################################
# (Optional) Testing: Multi-Region DDC Functional Validation
################################################################################

resource "null_resource" "ddc_multi_region_readiness_check" {
  count = var.ddc_application_config.enable_multi_region_validation ? 1 : 0

  triggers = {
    cluster_name = var.cluster_name
    region = var.region
    deployment_hash = null_resource.helm_ddc_app.triggers.values_hash
    peer_endpoint = var.ddc_application_config.peer_region_ddc_endpoint
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      echo "[DDC-MULTI-REGION] Running multi-region DDC functional test..."
      
      # Use path relative to where terraform is executed
      SCRIPT_PATH="../../../assets/scripts/ddc_functional_test_multi_region.sh"
      
      if [ ! -f "$SCRIPT_PATH" ]; then
        echo "[DDC-MULTI-REGION] ERROR: Multi-region functional test script not found at $SCRIPT_PATH"
        exit 1
      fi
      
      chmod +x "$SCRIPT_PATH"
      "$SCRIPT_PATH"
      
      echo "[DDC-MULTI-REGION] SUCCESS: Multi-region functional test completed"
    EOT
  }

  depends_on = [
    null_resource.helm_ddc_app
  ]
}

################################################################################
# ScyllaDB Multi-Region Keyspace Configuration
################################################################################

resource "null_resource" "trigger_ssm_keyspace_update" {
  count = var.database_connection.type == "scylla" && var.ssm_document_name != null ? 1 : 0

  triggers = {
    # Trigger only once per deployment (not on every Helm upgrade)
    deployment_complete = "${local.name_prefix}-initialize"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "[SCYLLA-KEYSPACE] Configuring ScyllaDB keyspaces for multi-region replication..."
      echo "[SCYLLA-KEYSPACE] This creates keyspaces with NetworkTopologyStrategy across all regions"

      # Wait for DDC to create initial keyspaces in local region
      echo "[SCYLLA-KEYSPACE] Waiting 60s for DDC to create local keyspaces..."
      sleep 60

      # Execute SSM document on ScyllaDB seed node
      # This runs CQL commands to alter keyspace replication settings
      echo "[SCYLLA-KEYSPACE] Executing SSM document on seed node ${var.scylla_seed_instance_id}..."
      aws ssm send-command \
        --region ${var.region} \
        --document-name "${var.ssm_document_name}" \
        --instance-ids "${var.scylla_seed_instance_id}" \
        --comment "Configure ScyllaDB keyspaces for multi-region DDC replication" \
        ${var.debug ? "--debug" : ""}

      echo "[SCYLLA-KEYSPACE] SSM command sent - keyspace configuration in progress"
      echo "[SCYLLA-KEYSPACE] Note: This is async - keyspaces will be configured in background"
    EOT
  }

  depends_on = [
    null_resource.helm_ddc_app
  ]
}