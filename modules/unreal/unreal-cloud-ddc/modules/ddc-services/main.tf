################################################################################
# DDC Services Module - Kubernetes Resources and Helm Charts
################################################################################

################################################################################
# Kubernetes Resources
################################################################################

resource "kubernetes_namespace" "unreal_cloud_ddc" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_service_account" "unreal_cloud_ddc_service_account" {
  depends_on = [kubernetes_namespace.unreal_cloud_ddc]
  
  metadata {
    name        = var.service_account
    namespace   = var.namespace
    labels      = { aws-usage : "application" }
    annotations = { "eks.amazonaws.com/role-arn" : var.service_account_arn }
  }
  
  automount_service_account_token = true
}

################################################################################
# EKS Addons (Moved from ddc-infra to avoid circular dependency)
################################################################################

module "eks_blueprints_addons" {
  #checkov:skip=CKV_TF_1:Using forked version with AWS Provider v6 region parameter support
  source = "git::https://github.com/novekm/terraform-aws-eks-blueprints-addons.git?ref=main"

  # EKS Addons configuration
  eks_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = var.ebs_csi_role_arn
    }
  }

  # Cluster configuration (from ddc-infra outputs)
  cluster_name      = var.cluster_name
  cluster_endpoint  = var.cluster_endpoint
  cluster_version   = data.aws_eks_cluster.cluster.version
  oidc_provider_arn = var.oidc_provider_arn
  
  # AWS Provider v6 region parameter support
  region = var.region
  
  # AWS Load Balancer Controller configuration
  aws_load_balancer_controller = {}
  
  # Note: Load balancer creation is controlled by Kubernetes Service type.
  # ClusterIP services (used below) prevent automatic load balancer creation.
  # TargetGroupBinding connects ClusterIP services to existing target groups.

  # Enable load balancer controller for TargetGroupBinding CRD support
  enable_aws_load_balancer_controller = true
  
  # Keep existing addons
  enable_aws_cloudwatch_metrics = true
  enable_cert_manager           = var.enable_certificate_manager
  cert_manager_route53_hosted_zone_arns = var.certificate_manager_hosted_zone_arn
  
  # Enable Fluent Bit for DDC application log shipping
  enable_aws_for_fluentbit = local.ddc_logging_enabled
  aws_for_fluentbit = local.ddc_logging_enabled ? {
    configuration_values = jsonencode({
      cloudWatchLogs = {
        enabled = true
        logGroupName = "${local.log_base_prefix}/application/ddc"
        logStreamName = "ddc-${var.cluster_name}"
      }
    })
    role_policies       = {}
    policy_statements   = []
  } : {
    configuration_values = null
    role_policies       = {}
    policy_statements   = []
  }

  tags = {
    Environment = var.cluster_name
  }

  depends_on = [
    kubernetes_namespace.unreal_cloud_ddc,
    kubernetes_service_account.unreal_cloud_ddc_service_account
  ]
}

# Data source to get cluster info
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# GHCR credentials from Secrets Manager
data "aws_secretsmanager_secret_version" "ghcr_credentials" {
  secret_id = var.ghcr_credentials_secret_manager_arn
}





# Direct GHCR access - much simpler than ECR pull-through cache



################################################################################
# Helm Cleanup
################################################################################

resource "null_resource" "helm_cleanup" {
  count = var.auto_helm_cleanup ? 1 : 0

  # Store values for destroy-time access
  triggers = {
    cluster_name = var.cluster_name
    namespace    = var.namespace
    region       = var.region
    timeout      = var.helm_cleanup_timeout
    name_prefix  = "${var.project_prefix}-${var.name}"
    namespace    = var.namespace
    show_messages = var.auto_cleanup_status_messages
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: Starting Helm cleanup for DDC applications'" : ""}
      ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: Region: ${self.triggers.region}'" : ""}
      ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: Cluster: ${self.triggers.cluster_name}'" : ""}
      ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: Namespace: ${self.triggers.namespace}'" : ""}

      # Aggressive retry for EKS API access (critical for proper cleanup order)
      ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: Testing EKS API access with retries'" : ""}
      
      EKS_ACCESS_SUCCESS=false
      for attempt in {1..10}; do
        if aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name} 2>/dev/null; then
          EKS_ACCESS_SUCCESS=true
          ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: EKS API access successful on attempt $attempt'" : ""}
          break
        fi
        ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: EKS API access failed, attempt $attempt/10. Retrying in 10s...'" : ""}
        sleep 10
      done
      
      if [ "$EKS_ACCESS_SUCCESS" = "false" ]; then
        echo "[DDC CLEANUP - HELM]: CRITICAL ERROR - EKS API ACCESS FAILED AFTER 10 ATTEMPTS!"
        echo "[DDC CLEANUP - HELM]: Cannot proceed - Load Balancer Controller cleanup requires API access"
        echo "[DDC CLEANUP - HELM]: TROUBLESHOOTING:"
        echo "[DDC CLEANUP - HELM]:   1. Check current IP: curl https://checkip.amazonaws.com/"
        echo "[DDC CLEANUP - HELM]:   2. Update eks_api_access_cidrs with current IP"
        echo "[DDC CLEANUP - HELM]:   3. Run: terraform apply (to update EKS access)"
        echo "[DDC CLEANUP - HELM]:   4. Then retry: terraform destroy"
        echo "[DDC CLEANUP - HELM]: DESTROY BLOCKED to prevent ENI orphaning!"
        exit 1
      fi

      ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: EKS API access confirmed'" : ""}

      # Cleanup Helm releases with wait
      ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: Uninstalling Helm releases (timeout: ${self.triggers.timeout}s)'" : ""}

      # Primary release
      if helm list -n ${self.triggers.namespace} | grep -q "${self.triggers.name_prefix}-initialize"; then
        ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: Removing ${self.triggers.name_prefix}-initialize'" : ""}
        if ! timeout ${self.triggers.timeout} helm uninstall ${self.triggers.name_prefix}-initialize -n ${self.triggers.namespace} --wait --timeout=${self.triggers.timeout}s; then
          echo "[DDC CLEANUP - HELM]: WARNING - Failed to uninstall ${self.triggers.name_prefix}-initialize"
          echo "[DDC CLEANUP - HELM]: Attempting force cleanup..."
          helm uninstall ${self.triggers.name_prefix}-initialize -n ${self.triggers.namespace} --no-hooks --timeout=30s || true
          echo "[DDC CLEANUP - HELM]: Force cleanup completed - continuing destroy"
        fi
        ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: ${self.triggers.name_prefix}-initialize removed'" : ""}
      else
        ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: ${self.triggers.name_prefix}-initialize not found (already removed)'" : ""}
      fi

      # Replication release (if exists)
      if helm list -n ${self.triggers.namespace} | grep -q "${self.triggers.name_prefix}-replicate"; then
        ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: Removing ${self.triggers.name_prefix}-replicate'" : ""}
        if ! timeout ${self.triggers.timeout} helm uninstall ${self.triggers.name_prefix}-replicate -n ${self.triggers.namespace} --wait --timeout=${self.triggers.timeout}s; then
          echo "[DDC CLEANUP - HELM]: WARNING - Failed to uninstall ${self.triggers.name_prefix}-replicate"
          echo "[DDC CLEANUP - HELM]: Attempting force cleanup..."
          helm uninstall ${self.triggers.name_prefix}-replicate -n ${self.triggers.namespace} --no-hooks --timeout=30s || true
          echo "[DDC CLEANUP - HELM]: Force cleanup completed - continuing destroy"
        fi
        ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: ${self.triggers.name_prefix}-replicate removed'" : ""}
      else
        ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: ${self.triggers.name_prefix}-replicate not found (already removed)'" : ""}
      fi

      # Force cleanup TargetGroupBinding to ensure ENI cleanup
      ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: Cleaning up TargetGroupBinding to prevent ENI orphaning'" : ""}
      kubectl delete targetgroupbinding ${self.triggers.name_prefix}-tgb -n ${self.triggers.namespace} --timeout=60s --ignore-not-found=true || {
        ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: TGB cleanup failed, forcing deletion'" : ""}
        kubectl patch targetgroupbinding ${self.triggers.name_prefix}-tgb -n ${self.triggers.namespace} --type='merge' -p='{"metadata":{"finalizers":[]}}' 2>/dev/null || true
        kubectl delete targetgroupbinding ${self.triggers.name_prefix}-tgb -n ${self.triggers.namespace} --force --grace-period=0 2>/dev/null || true
      }
      
      ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: Helm cleanup completed successfully'" : ""}
      ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: Safe to proceed with infrastructure destruction'" : ""}
    EOT
  }

  # Only run when Helm releases are actually being destroyed
  depends_on = [
    helm_release.unreal_cloud_ddc_initialization
  ]
}

################################################################################
# Helm Releases
################################################################################

resource "helm_release" "unreal_cloud_ddc_initialization" {
  name         = "${local.name_prefix}-initialize"
  chart        = "unreal-cloud-ddc"
  repository   = "oci://ghcr.io/epicgames"
  namespace    = var.namespace
  version      = "${var.unreal_cloud_ddc_version}+helm"
  reset_values = true
  timeout      = 120  # 2 minutes - faster feedback now that DDC starts successfully

  disable_webhooks = true
  cleanup_on_fail  = true

  # GHCR authentication for Helm using existing secret
  repository_username = jsondecode(data.aws_secretsmanager_secret_version.ghcr_credentials.secret_string)["username"]
  repository_password = jsondecode(data.aws_secretsmanager_secret_version.ghcr_credentials.secret_string)["accessToken"]

  values = local.base_values
  
  # Service configuration - ensure ClusterIP and correct ports
  set {
    name  = "service.type"
    value = "ClusterIP"
  }
  
  set {
    name  = "service.port"
    value = "80"
    type  = "string"
  }
  
  set {
    name  = "service.targetPort"
    value = "http"
  }
  
  set {
    name  = "image.repository"
    value = split(":", var.ddc_image)[0]
  }
  
  set {
    name  = "image.tag"
    value = split(":", var.ddc_image)[1]
  }
  
  # Disable NGINX sidecar completely for bring-your-own NLB
  set {
    name  = "nginx.enabled"
    value = "false"
  }
  
  set {
    name  = "nginx.useDomainSockets"
    value = "false"
  }
  
  # Configure Kestrel to use standard HTTP port (array format)
  set {
    name  = "env[0].name"
    value = "ASPNETCORE_URLS"
    type  = "string"
  }
  
  set {
    name  = "env[0].value"
    value = "http://0.0.0.0:80"
    type  = "string"
  }
  
  # Additional Kestrel configuration override
  set {
    name  = "env[1].name"
    value = "Kestrel__Endpoints__Http__Url"
    type  = "string"
  }
  
  set {
    name  = "env[1].value"
    value = "http://0.0.0.0:80"
    type  = "string"
  }
  
  # Database configuration overrides (critical for Keyspaces)
  set {
    name  = "env[2].name"
    value = "Database__Type"
    type  = "string"
  }
  
  set {
    name  = "env[2].value"
    value = var.database_connection.type
    type  = "string"
  }
  
  set {
    name  = "env[3].name"
    value = "Database__Host"
    type  = "string"
  }
  
  set {
    name  = "env[3].value"
    value = var.database_connection.host
    type  = "string"
  }
  
  set {
    name  = "env[4].name"
    value = "Database__Port"
    type  = "string"
  }
  
  set {
    name  = "env[4].value"
    value = var.database_connection.port
    type  = "string"
  }
  
  set {
    name  = "env[5].name"
    value = "Database__AuthType"
    type  = "string"
  }
  
  set {
    name  = "env[5].value"
    value = var.database_connection.auth_type
    type  = "string"
  }
  
  # Override UnrealCloudDDC implementation settings dynamically
  set {
    name  = "worker.config.UnrealCloudDDC.BlobIndexImplementation"
    value = var.database_connection.type == "scylla" ? "Scylla" : "Keyspaces"
  }
  
  set {
    name  = "worker.config.UnrealCloudDDC.ContentIdStoreImplementation"
    value = var.database_connection.type == "scylla" ? "Scylla" : "Keyspaces"
  }
  
  set {
    name  = "worker.config.UnrealCloudDDC.ReferencesDbImplementation"
    value = var.database_connection.type == "scylla" ? "Scylla" : "Keyspaces"
  }
  
  set {
    name  = "worker.config.UnrealCloudDDC.ReplicationLogWriterImplementation"
    value = var.database_connection.type == "scylla" ? "Scylla" : "Keyspaces"
  }
  
  # Override main service UnrealCloudDDC implementation settings
  set {
    name  = "config.UnrealCloudDDC.BlobIndexImplementation"
    value = var.database_connection.type == "scylla" ? "Scylla" : "Keyspaces"
  }
  
  set {
    name  = "config.UnrealCloudDDC.ContentIdStoreImplementation"
    value = var.database_connection.type == "scylla" ? "Scylla" : "Keyspaces"
  }
  
  set {
    name  = "config.UnrealCloudDDC.ReferencesDbImplementation"
    value = var.database_connection.type == "scylla" ? "Scylla" : "Keyspaces"
  }
  
  set {
    name  = "config.UnrealCloudDDC.ReplicationLogWriterImplementation"
    value = var.database_connection.type == "scylla" ? "Scylla" : "Keyspaces"
  }
  
  # Remove conflicting hardcoded configurations - let Helm values template handle database config

  depends_on = [
    module.eks_blueprints_addons      # Terraform handles dependency ordering
  ]
}

################################################################################
# TargetGroupBinding - Connect ClusterIP Service to Existing NLB Target Group
################################################################################

# Initial wait for EKS DNS propagation
resource "time_sleep" "wait_for_eks_dns" {
  create_duration = "60s"  # Initial wait before checking
  
  depends_on = [
    helm_release.unreal_cloud_ddc_initialization,
    module.eks_blueprints_addons
  ]
}

# Verify EKS DNS with fallback to 5-minute total wait
resource "null_resource" "verify_eks_dns" {
  triggers = {
    cluster_endpoint = var.cluster_endpoint
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "[DNS TIMING]: Starting DNS verification at $(date)"
      echo "[DNS TIMING]: EKS endpoint: ${var.cluster_endpoint}"
      
      # Extract hostname from https://hostname/path
      EKS_HOSTNAME=$(echo "${var.cluster_endpoint}" | sed 's|https://||' | sed 's|/.*||')
      echo "[DNS TIMING]: Testing hostname: $EKS_HOSTNAME"
      
      # Try DNS resolution up to 8 times (4 minutes after initial 1-minute wait = 5 minutes total)
      for i in {1..8}; do
        echo "[DNS TIMING]: DNS check attempt $i/8 at $(date)"
        if nslookup "$EKS_HOSTNAME" >/dev/null 2>&1; then
          echo "[DNS TIMING]: SUCCESS - EKS DNS resolved on attempt $i after $((60 + (i-1)*30)) seconds total"
          exit 0
        fi
        if [ $i -lt 8 ]; then
          echo "[DNS TIMING]: DNS not ready, waiting 30s before retry $((i+1))/8"
          sleep 30
        fi
      done
      
      echo "[DNS TIMING]: ERROR - EKS DNS still not resolvable after 5 minutes total"
      echo "[DNS TIMING]: Final attempt failed at $(date)"
      exit 1
    EOT
  }
  
  depends_on = [time_sleep.wait_for_eks_dns]
}

resource "kubectl_manifest" "target_group_binding" {
  yaml_body = <<YAML
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: ${local.name_prefix}-tgb
  namespace: ${var.namespace}
spec:
  serviceRef:
    name: ${local.name_prefix}-initialize
    port: 80
  targetGroupARN: ${var.nlb_target_group_arn}
  targetType: ip
YAML
  
  depends_on = [
    null_resource.verify_eks_dns  # DNS verified OR 5-minute timeout
  ]
}

resource "time_sleep" "wait_for_init" {
  count           = var.ddc_replication_region_url != null ? 1 : 0
  create_duration = "30s"
  depends_on      = [helm_release.unreal_cloud_ddc_initialization]
}

resource "helm_release" "unreal_cloud_ddc_with_replication" {
  count        = var.unreal_cloud_ddc_helm_replication_chart != null && var.ddc_replication_region_url != null ? 1 : 0
  name         = "${local.name_prefix}-replicate"
  chart        = "unreal-cloud-ddc"
  repository   = "oci://ghcr.io/epicgames"
  namespace    = var.namespace
  version      = "${var.unreal_cloud_ddc_version}+helm"
  reset_values = true
  timeout      = 120

  # GHCR authentication for Helm using existing secret
  repository_username = jsondecode(data.aws_secretsmanager_secret_version.ghcr_credentials.secret_string)["username"]
  repository_password = jsondecode(data.aws_secretsmanager_secret_version.ghcr_credentials.secret_string)["accessToken"]

  values = local.replication_values

  depends_on = [
    time_sleep.wait_for_init
  ]
}

################################################################################
# SSM Execution for Multi-Region Keyspace Configuration
################################################################################

# Execute SSM document to configure keyspaces (only for Scylla in secondary region)
resource "null_resource" "trigger_ssm_keyspace_update" {
  count = var.database_connection.type == "scylla" && var.ssm_document_name != null && var.ddc_replication_region_url != null ? 1 : 0

  triggers = {
    # Trigger only once per deployment (not on every Helm upgrade)
    deployment_complete = helm_release.unreal_cloud_ddc_initialization.name
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for primary region keyspaces to be created
      sleep 60
      # Execute SSM document on primary region's seed node
      aws ssm send-command \
        --region ${var.region} \
        --document-name "${var.ssm_document_name}" \
        --instance-ids "${var.scylla_seed_instance_id}" \
        --comment "Configure ScyllaDB keyspaces for multi-region replication"
    EOT
  }

  depends_on = [
    helm_release.unreal_cloud_ddc_initialization
  ]
}
