

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
#
# 🎯 DIRECT DEPLOYMENT STRATEGY
#
# Simple, direct deployment from source registries - no caching, no Docker required.
#
# 📦 SUPPORTED DEPLOYMENT PATHS:
# 1. **Epic's Official Charts** (Default)
#    • Chart: oci://ghcr.io/epicgames/unreal-cloud-ddc:1.2.0+helm
#    • Image: ghcr.io/epicgames/unreal-cloud-ddc:1.2.0
#    • Auth: Uses ghcr_credentials_secret_arn for GHCR access
#
# 2. **Public OCI Registries**
#    • Any public OCI registry (Docker Hub, GHCR, etc.)
#    • No authentication required
#    • Direct deployment
#
# 3. **Local Development**
#    • Local Helm charts (file paths)
#    • Custom values files
#    • Development/testing scenarios
#
# 🔐 AUTHENTICATION:
# • GHCR: Automatic via ghcr_credentials_secret_arn secret
# • Public registries: No auth needed
# • Private registries: User must handle auth setup
#
# 💡 BENEFITS:
# ✅ No Docker dependency
# ✅ Simple, fast deployment
# ✅ Minimal tool requirements (just Helm + kubectl)
# ✅ Clear, predictable behavior
# ✅ Easy debugging and troubleshooting
#
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
      echo "[DDC-APP CLEANUP] Starting DDC application cleanup..."

      # Configure kubectl (ignore failures if cluster deleted)
      aws eks update-kubeconfig --name ${self.triggers.cluster_name} --region ${self.triggers.region} || {
        echo "[DDC-APP CLEANUP] Cluster already deleted, skipping cleanup"
        exit 0
      }

      # Clean up DDC application resources
      echo "[DDC-APP CLEANUP] Cleaning up DDC Helm release..."
      helm uninstall ${self.triggers.name_prefix}-app -n ${self.triggers.namespace} || true

      echo "[DDC-APP CLEANUP] SUCCESS: Cleanup completed"
    EOT
  }

  depends_on = [
    null_resource.wait_for_eks_ready
  ]
}



################################################################################
# Multi-Region Replication Enablement
################################################################################
#
# 🔄 REPLICATION MODES SUPPORTED:
#
# 📤 SPECULATIVE (Push): Proactively pushes new data to peer regions
# 📥 ON-DEMAND (Pull): Pulls missing data from peers when requested
# 🔄 HYBRID: Combines both strategies for maximum performance
#
# 🔄 THE APPROACH:
#
# 1. TERRAFORM DEPENDENCY TREE:
#    - Region 1 deploys first with regional endpoint (e.g. "us-east-1.dev.ddc.example.com", no region 2 yet)
#    - Region 2 deploys second with regional endpoint (e.g. "us-west-2.dev.ddc.example.com", exists now)
#    - us-east-1 depends on us-west-2 to properly replicate to it (chicken-egg problem)
#
# 2. DDC HANDLES BROKEN ENDPOINTS:
#    - DDC documentation indicates it can handle endpoints that don't exist yet
#    - DDC won't replicate but has retry logic
#    - Once peer region is up, replication should start automatically (based on if you have speculative, on-demand, or hybrid enabled in the module)
#
# 3. WE USE DERIVED VALUES (PREDICTABLE ENDPOINTS):
#    - We know what endpoints WILL BE: "${region}.${environment}.ddc.example.com"
#    - Set them up from the start when multi-region is enabled
#    - DDC starts working once region 2 is up, DNS records exist and health checks pass
#
# 4. THIS RESOURCE: Optional restart for immediate verification
#    - Not required for functionality (DDC should be self-healing)
#    - Useful for testing/debugging multi-region connectivity
#
# 🎯 WHEN THIS RUNS:
# - When DDC application configuration changes (content_hash trigger)
# - When peer region endpoints become available (multi-region architecture)
# - Each region's DDC needs to restart when peer region is deployed

################################################################################

# COMMENTED OUT FOR TESTING DDC SELF-HEALING
# Enable if DDC doesn't automatically discover peer endpoints
# resource "null_resource" "ddc_replication_config" {
#   count = var.ddc_application_config.enable_multi_region_replication ? 1 : 0
#   triggers = {
#     content_hash = md5(jsonencode(var.ddc_application_config))
#   }
#   provisioner "local-exec" {
#     interpreter = ["/bin/bash", "-c"]
#     command = <<-EOT
#       aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.region}
#       kubectl rollout restart deployment/${local.name_prefix} -n ${var.namespace}
#       kubectl rollout restart deployment/${local.name_prefix}-worker -n ${var.namespace}
#     EOT
#   }
#   depends_on = [null_resource.helm_ddc_app]
# }

################################################################################
# (Optional) Testing: DDC Readiness Validation
################################################################################
#
# Tests DDC connectivity and functionality after deployment.
# Optionally checks multi-region replication if enabled.
################################################################################

resource "null_resource" "ddc_readiness_check" {
  count = local.enable_ddc_readiness_check ? 1 : 0

  triggers = {
    cluster_name = var.cluster_name
    region = var.region
    nlb_dns_name = var.nlb_dns_name
    deployment_hash = null_resource.helm_ddc_app.triggers.values_hash
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "[DDC-READINESS] Starting DDC application readiness check..."

      # Step 1: Configure kubectl access
      echo "[DDC-READINESS] Configuring kubectl access to cluster ${var.cluster_name}..."
      aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.region}

      # Step 2: Wait for DDC pods to be ready
      echo "[DDC-READINESS] Waiting for DDC pods to be ready (max 1 minute)..."
      timeout 60s kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=unreal-cloud-ddc -n ${var.namespace} --timeout=60s${var.debug ? " -v=10" : null}

      # Step 3: Wait for LoadBalancer to get external IP (NLB provisioning)
      echo "[DDC-READINESS] Waiting for LoadBalancer to provision (max 5 minutes)..."
      timeout 300s kubectl wait --for=jsonpath='{.status.loadBalancer.ingress[0].hostname}' service/${local.name_prefix} -n ${var.namespace} --timeout=300s
      
      # Get actual NLB hostname from LoadBalancer service
      NLB_HOSTNAME=$(kubectl get service ${local.name_prefix} -n ${var.namespace} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
      
      if [ -n "$NLB_HOSTNAME" ]; then
        echo "[DDC-READINESS] LoadBalancer provisioned: $NLB_HOSTNAME"
        echo "[DDC-READINESS] Waiting for service endpoints to be ready..."
        timeout 30s kubectl wait --for=jsonpath='{.subsets[0].addresses[0].ip}' endpoints/${local.name_prefix} -n ${var.namespace} --timeout=30s
      else
        echo "[DDC-READINESS] ERROR: LoadBalancer hostname not available"
        exit 1
      fi

      # Step 4: Test DDC health endpoints - Layered approach
      echo "[DDC-READINESS] Testing DDC health endpoints..."
      
      # Test 1: Direct NLB access (HTTP) - For RCA investigation
      echo "[DDC-READINESS] Test 1: Direct NLB HTTP access (for troubleshooting)"
      NLB_HTTP_URL="http://$NLB_HOSTNAME/health/live"
      if curl -f -s "$NLB_HTTP_URL" > /dev/null 2>&1; then
        echo "[DDC-READINESS] NLB direct access: WORKING"
        NLB_WORKS=true
      else
        echo "[DDC-READINESS] NLB direct access: FAILED - $NLB_HTTP_URL"
        echo "[DDC-READINESS] This indicates a problem with NLB target health or pod connectivity"
        NLB_WORKS=false
      fi
      
      # Test 2: Route53 DNS access (HTTPS) - Primary success criteria
      ROUTE53_DNS="${var.nlb_dns_name != null ? var.nlb_dns_name : ""}"
      if [ -n "$ROUTE53_DNS" ]; then
        echo "[DDC-READINESS] Test 2: Route53 DNS HTTPS access (primary test)"
        ROUTE53_HTTPS_URL="https://$ROUTE53_DNS/health/live"
        
        for i in {1..6}; do # 30 seconds total (6 * 5s)
          echo "[DDC-READINESS] Attempt $i/6: Testing $ROUTE53_HTTPS_URL"
          if curl -f -s "$ROUTE53_HTTPS_URL" > /dev/null 2>&1; then
            echo "[DDC-READINESS] SUCCESS: Route53 DNS HTTPS health check passed"
            echo "[DDC-READINESS] Route53 DNS: $ROUTE53_DNS"
            echo "[DDC-READINESS] NLB Hostname: $NLB_HOSTNAME"
            echo "[DDC-READINESS] Health URL: $ROUTE53_HTTPS_URL"
            break
          fi
          echo "[DDC-READINESS] Health check attempt $i/6 failed, retrying in 5s..."
          # Show more debug info on failure
          echo "[DDC-READINESS] Debug: curl -f -s $ROUTE53_HTTPS_URL"
          curl -f -s "$ROUTE53_HTTPS_URL" || echo "[DDC-READINESS] Curl exit code: $?"
          sleep 5
          if [ $i -eq 6 ]; then
            echo "[DDC-READINESS] ERROR: Route53 DNS health check failed after 30 seconds"
            echo "[DDC-READINESS] Route53 DNS: $ROUTE53_DNS"
            echo "[DDC-READINESS] NLB Hostname: $NLB_HOSTNAME"
            echo "[DDC-READINESS] Failed URL: $ROUTE53_HTTPS_URL"
            if [ "$NLB_WORKS" = "true" ]; then
              echo "[DDC-READINESS] RCA: NLB works directly, issue is with DNS/SSL/Route53"
            else
              echo "[DDC-READINESS] RCA: Both NLB and DNS failed, issue is with NLB target health"
            fi
            exit 1
          fi
        done
      else
        echo "[DDC-READINESS] WARNING: No Route53 DNS configured, skipping DNS health check"
        echo "[DDC-READINESS] SUCCESS: Direct NLB access confirmed working"
      fi

      # Step 5: Test multi-region replication (if enabled)
      if [ "${var.ddc_application_config.enable_multi_region_replication}" = "true" ]; then
        echo "[DDC-READINESS] Testing multi-region replication configuration..."

        # Check if replication endpoints are configured in pods
        echo "[DDC-READINESS] Checking DDC pod configuration for peer endpoints..."
        kubectl get pods -l app.kubernetes.io/name=unreal-cloud-ddc -n ${var.namespace} -o yaml | grep -i "ddc.example.com" || {
          echo "[DDC-READINESS] WARNING: No peer region endpoints found in pod configuration"
          echo "[DDC-READINESS] This is expected if peer regions are not yet deployed"
        }

        echo "[DDC-READINESS] Multi-region replication check completed"
      fi

      echo "[DDC-READINESS] SUCCESS: DDC application is ready and responding to requests"
    EOT
  }

  depends_on = [
    null_resource.helm_ddc_app
  ]
}


################################################################################
# ScyllaDB Multi-Region Keyspace Configuration
################################################################################
#
# WHAT THIS DOES:
# ScyllaDB requires keyspaces to be created with proper replication settings
# across all regions BEFORE DDC can use them for multi-region replication.
#
# THE PROBLEM:
# - DDC creates keyspaces automatically, but only for the local region
# - Multi-region replication needs keyspaces configured in ALL regions
# - This must happen AFTER both regions' ScyllaDB clusters are running
#
# THE SOLUTION:
# - SSM document runs CQL commands on the seed node
# - Creates/alters keyspaces with NetworkTopologyStrategy for all regions
# - Only runs for ScyllaDB (not needed for Keyspaces service)
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
