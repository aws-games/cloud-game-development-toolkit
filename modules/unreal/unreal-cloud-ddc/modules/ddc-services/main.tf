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

################################################################################
# ECR Pull-Through Cache
################################################################################

resource "aws_ecr_pull_through_cache_rule" "unreal_cloud_ddc_ecr_pull_through_cache_rule" {
  ecr_repository_prefix = "github"
  upstream_registry_url = "ghcr.io"
  credential_arn        = var.ghcr_credentials_secret_manager_arn
}

# Trigger ECR pull-through cache authentication by making API call
resource "null_resource" "trigger_ecr_auth" {
  triggers = {
    ecr_rule_id = aws_ecr_pull_through_cache_rule.unreal_cloud_ddc_ecr_pull_through_cache_rule.registry_id
    repository  = "github/epicgames/unreal-cloud-ddc"
    tag         = "${var.unreal_cloud_ddc_version}+helm"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "🔄 Triggering ECR pull-through cache authentication..."
      
      # Force ECR to authenticate by attempting to describe the repository
      # This triggers the pull-through cache to create the repo and authenticate
      echo "📡 Making ECR API call to trigger authentication..."
      
      # Try to describe the repository - this will trigger ECR to create it
      aws ecr describe-repository \
        --repository-name ${self.triggers.repository} \
        --region ${var.region} 2>/dev/null || echo "Repository will be created on first pull"
      
      echo "✅ ECR authentication trigger completed"
      echo "ℹ️  ECR will authenticate with GHCR when Helm requests the chart"
    EOT
  }

  depends_on = [aws_ecr_pull_through_cache_rule.unreal_cloud_ddc_ecr_pull_through_cache_rule]
}

# Simple wait to allow ECR rule to propagate
resource "time_sleep" "ecr_rule_propagation" {
  create_duration = "15s"
  depends_on      = [null_resource.trigger_ecr_auth]
}

# Clean up ECR repositories created by pull-through cache
# Evidence: cwwalb deployments left orphaned ECR repos that persist after destroy
resource "null_resource" "ecr_cleanup" {
  triggers = {
    repository_name = "github/epicgames/unreal-cloud-ddc"
    region         = var.region
    # Force recreation when ECR rule changes to ensure cleanup runs
    ecr_rule_id    = aws_ecr_pull_through_cache_rule.unreal_cloud_ddc_ecr_pull_through_cache_rule.registry_id
    show_messages  = tostring(var.auto_cleanup_status_messages)
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      ${try(self.triggers.show_messages, "true") == "true" ? "echo '[DDC CLEANUP - ECR]: Starting ECR repository cleanup'" : ""}
      
      # Delete the auto-created repository (ignore errors if it doesn't exist)
      aws ecr delete-repository \
        --repository-name ${self.triggers.repository_name} \
        --region ${self.triggers.region} \
        --force 2>/dev/null || ${try(self.triggers.show_messages, "true") == "true" ? "echo '[DDC CLEANUP - ECR]: Repository ${self.triggers.repository_name} not found or already deleted'" : "true"}
      
      ${try(self.triggers.show_messages, "true") == "true" ? "echo '[DDC CLEANUP - ECR]: ECR cleanup completed'" : ""}
    EOT
  }

  depends_on = [aws_ecr_pull_through_cache_rule.unreal_cloud_ddc_ecr_pull_through_cache_rule]
}



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
    show_messages = var.auto_cleanup_status_messages
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: Starting Helm cleanup for DDC applications'" : ""}
      ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: Region: ${self.triggers.region}'" : ""}
      ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: Cluster: ${self.triggers.cluster_name}'" : ""}
      ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: Namespace: ${self.triggers.namespace}'" : ""}

      # Test EKS API access first
      ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: Testing EKS API access'" : ""}
      if ! aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name} 2>/dev/null; then
        echo "[DDC CLEANUP - HELM]: ERROR - EKS API ACCESS FAILED!"
        echo "[DDC CLEANUP - HELM]: COMMON CAUSES:"
        echo "[DDC CLEANUP - HELM]:   - Your IP changed since deployment"
        echo "[DDC CLEANUP - HELM]:   - Not in eks_api_access_cidrs allowlist"
        echo "[DDC CLEANUP - HELM]:   - AWS credentials expired/invalid"
        echo "[DDC CLEANUP - HELM]:   - EKS cluster already deleted"
        echo "[DDC CLEANUP - HELM]: TROUBLESHOOTING:"
        echo "[DDC CLEANUP - HELM]:   1. Check current IP: curl https://checkip.amazonaws.com/"
        echo "[DDC CLEANUP - HELM]:   2. Update eks_api_access_cidrs with current IP"
        echo "[DDC CLEANUP - HELM]:   3. Run: terraform apply (to update EKS access)"
        echo "[DDC CLEANUP - HELM]:   4. Then retry: terraform destroy"
        echo "[DDC CLEANUP - HELM]: Full troubleshooting guide:"
        echo "[DDC CLEANUP - HELM]:   https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc#destroy-troubleshooting"
        echo "[DDC CLEANUP - HELM]: DESTROY STOPPED to prevent orphaned AWS resources!"
        exit 1
      fi

      ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: EKS API access confirmed'" : ""}

      # Cleanup Helm releases with wait
      ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: Uninstalling Helm releases (timeout: ${self.triggers.timeout}s)'" : ""}

      # Primary release
      if helm list -n ${self.triggers.namespace} | grep -q "${self.triggers.name_prefix}-initialize"; then
        ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: Removing ${self.triggers.name_prefix}-initialize'" : ""}
        if ! helm uninstall ${self.triggers.name_prefix}-initialize -n ${self.triggers.namespace} --wait --timeout=${self.triggers.timeout}s; then
          echo "[DDC CLEANUP - HELM]: ERROR - Failed to uninstall ${self.triggers.name_prefix}-initialize"
          echo "[DDC CLEANUP - HELM]: Troubleshooting: https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc#helm-cleanup-failures"
          exit 1
        fi
        ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: ${self.triggers.name_prefix}-initialize removed'" : ""}
      else
        ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: ${self.triggers.name_prefix}-initialize not found (already removed)'" : ""}
      fi

      # Replication release (if exists)
      if helm list -n ${self.triggers.namespace} | grep -q "${self.triggers.name_prefix}-replicate"; then
        ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: Removing ${self.triggers.name_prefix}-replicate'" : ""}
        if ! helm uninstall ${self.triggers.name_prefix}-replicate -n ${self.triggers.namespace} --wait --timeout=${self.triggers.timeout}s; then
          echo "[DDC CLEANUP - HELM]: ERROR - Failed to uninstall ${self.triggers.name_prefix}-replicate"
          echo "[DDC CLEANUP - HELM]: Troubleshooting: https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc#helm-cleanup-failures"
          exit 1
        fi
        ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: ${self.triggers.name_prefix}-replicate removed'" : ""}
      else
        ${self.triggers.show_messages ? "echo '[DDC CLEANUP - HELM]: ${self.triggers.name_prefix}-replicate not found (already removed)'" : ""}
      fi

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
  repository   = "oci://${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/github/epicgames"
  namespace    = var.namespace
  version      = "${var.unreal_cloud_ddc_version}+helm"
  reset_values = true
  timeout      = 600  # 10 minutes - appropriate for DDC complexity

  disable_webhooks = true
  cleanup_on_fail  = true

  values = local.base_values
  
  # Service configuration - ensure ClusterIP and correct ports
  set {
    name  = "service.type"
    value = "ClusterIP"
  }
  
  set {
    name  = "service.port"
    value = "80"
  }
  
  set {
    name  = "service.targetPort"
    value = "http"
  }
  
  set {
    name  = "image.tag"
    value = var.unreal_cloud_ddc_version
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
  }
  
  set {
    name  = "env[0].value"
    value = "http://0.0.0.0:80"
  }
  
  # Additional Kestrel configuration override
  set {
    name  = "env[1].name"
    value = "Kestrel__Endpoints__Http__Url"
  }
  
  set {
    name  = "env[1].value"
    value = "http://0.0.0.0:80"
  }
  
  # ScyllaDB configuration with dynamic keyspace naming
  set {
    name  = "env[2].name"
    value = "Scylla__LocalDatacenterName"
  }
  
  set {
    name  = "env[2].value"
    value = var.scylla_datacenter_name
  }
  
  set {
    name  = "env[3].name"
    value = "Scylla__LocalKeyspaceSuffix"
  }
  
  set {
    name  = "env[3].value"
    value = var.scylla_keyspace_suffix
  }

  depends_on = [
    time_sleep.ecr_rule_propagation,  # Wait for ECR rule to propagate
    module.eks_blueprints_addons      # Terraform handles dependency ordering
  ]
}

################################################################################
# TargetGroupBinding - Connect ClusterIP Service to Existing NLB Target Group
################################################################################

resource "kubectl_manifest" "target_group_binding" {
  # Always create TGB when services module is deployed
  
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
    helm_release.unreal_cloud_ddc_initialization,
    module.eks_blueprints_addons
  ]
}

# Comprehensive cleanup to ensure AWS resources are fully removed before infrastructure destruction
resource "null_resource" "comprehensive_cleanup" {
  triggers = {
    tgb_name = "${local.name_prefix}-tgb"
    namespace = var.namespace
    cluster_name = var.cluster_name
    region = var.region
    show_messages = var.auto_cleanup_status_messages
    target_group_arn = var.nlb_target_group_arn
  }

  # Creation-time: Remove finalizers to prevent deadlock
  provisioner "local-exec" {
    command = <<-EOT
      ${self.triggers.show_messages ? "echo '[DDC SETUP - TGB]: Removing TargetGroupBinding finalizer to prevent destroy deadlock'" : ""}
      
      # Configure kubectl
      aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name}
      
      # Wait for TGB to be fully created
      sleep 10
      
      # Remove any finalizers the controller might have added
      kubectl patch targetgroupbinding ${self.triggers.tgb_name} -n ${self.triggers.namespace} \
        --type='merge' -p='{"metadata":{"finalizers":[]}}' || true
      
      ${self.triggers.show_messages ? "echo '[DDC SETUP - TGB]: Finalizer removed - TGB can now be destroyed cleanly'" : ""}
    EOT
  }

  # Destruction-time: Ensure complete cleanup before proceeding
  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      ${self.triggers.show_messages ? "echo '[DDC CLEANUP - COMPREHENSIVE]: Starting comprehensive AWS resource cleanup'" : ""}
      
      # Configure kubectl
      ${self.triggers.show_messages ? "echo '[DDC CLEANUP - COMPREHENSIVE]: Configuring kubectl access'" : ""}
      if ! aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name} 2>/dev/null; then
        ${self.triggers.show_messages ? "echo '[DDC CLEANUP - COMPREHENSIVE]: EKS cluster already deleted or inaccessible - cleanup not needed'" : ""}
        exit 0
      fi
      
      # Force delete TGB if it still exists
      ${self.triggers.show_messages ? "echo '[DDC CLEANUP - COMPREHENSIVE]: Force deleting TargetGroupBinding to trigger controller cleanup'" : ""}
      kubectl delete targetgroupbinding ${self.triggers.tgb_name} -n ${self.triggers.namespace} --ignore-not-found=true --timeout=60s || {
        ${self.triggers.show_messages ? "echo '[DDC CLEANUP - COMPREHENSIVE]: TGB deletion failed or not found - continuing'" : ""}
      }
      
      # Wait for target group to be fully drained (max 2 minutes)
      ${self.triggers.show_messages ? "echo '[DDC CLEANUP - COMPREHENSIVE]: Waiting for target group to be drained (max 2 minutes)'" : ""}
      for i in {1..60}; do
        TARGETS=$(aws elbv2 describe-target-health --target-group-arn ${self.triggers.target_group_arn} --query 'TargetHealthDescriptions[].Target.Id' --output text 2>/dev/null || echo "")
        if [ -z "$TARGETS" ] || [ "$TARGETS" = "None" ]; then
          ${self.triggers.show_messages ? "echo '[DDC CLEANUP - COMPREHENSIVE]: Target group fully drained - safe to proceed'" : ""}
          break
        fi
        if [ $((i % 10)) -eq 0 ]; then
          ${self.triggers.show_messages ? "echo '[DDC CLEANUP - COMPREHENSIVE]: Still waiting for targets to drain... ($i/60) - Targets: $TARGETS'" : ""}
        fi
        sleep 2
      done
      
      # Final check and warning
      FINAL_TARGETS=$(aws elbv2 describe-target-health --target-group-arn ${self.triggers.target_group_arn} --query 'TargetHealthDescriptions[].Target.Id' --output text 2>/dev/null || echo "")
      if [ -n "$FINAL_TARGETS" ] && [ "$FINAL_TARGETS" != "None" ]; then
        echo "[DDC CLEANUP - COMPREHENSIVE]: WARNING - Targets still registered after 2 minutes: $FINAL_TARGETS"
        echo "[DDC CLEANUP - COMPREHENSIVE]: Proceeding anyway - EKS deletion may encounter issues"
      else
        ${self.triggers.show_messages ? "echo '[DDC CLEANUP - COMPREHENSIVE]: Comprehensive cleanup completed successfully'" : ""}
      fi
    EOT
  }

  depends_on = [kubectl_manifest.target_group_binding]
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
  repository   = "oci://${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/github/epicgames"
  namespace    = var.namespace
  version      = "${var.unreal_cloud_ddc_version}+helm"
  reset_values = true
  timeout      = 600

  values = local.replication_values

  depends_on = [
    time_sleep.wait_for_init
  ]
}

################################################################################
# SSM Execution for Multi-Region Keyspace Configuration
################################################################################

# Execute SSM document to configure keyspaces (only in secondary region)
resource "null_resource" "trigger_ssm_keyspace_update" {
  count = var.ssm_document_name != null && var.ddc_replication_region_url != null ? 1 : 0

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
