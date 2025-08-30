################################################################################
# DDC Services Module - Helm Charts Only (No AWS Infrastructure)
################################################################################

################################################################################
# ECR Pull-Through Cache
################################################################################

resource "aws_ecr_pull_through_cache_rule" "unreal_cloud_ddc_ecr_pull_through_cache_rule" {
  ecr_repository_prefix = "github"
  upstream_registry_url = "ghcr.io"
  credential_arn        = var.ghcr_credentials_secret_manager_arn
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
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "🧹 Starting Helm cleanup for DDC applications..."
      echo "📍 Region: ${self.triggers.region}"
      echo "🎯 Cluster: ${self.triggers.cluster_name}"
      echo "📦 Namespace: ${self.triggers.namespace}"
      echo ""

      # Test EKS API access first
      echo "🔍 Testing EKS API access..."
      if ! aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name} 2>/dev/null; then
        echo "❌ EKS API ACCESS FAILED!"
        echo ""
        echo "🚨 COMMON CAUSES:"
        echo "   • Your IP changed since deployment"
        echo "   • Not in eks_api_access_cidrs allowlist"
        echo "   • AWS credentials expired/invalid"
        echo "   • EKS cluster already deleted"
        echo ""
        echo "💡 TROUBLESHOOTING:"
        echo "   1. Check current IP: curl https://checkip.amazonaws.com/"
        echo "   2. Update eks_api_access_cidrs with current IP"
        echo "   3. Run: terraform apply (to update EKS access)"
        echo "   4. Then retry: terraform destroy"
        echo ""
        echo "📚 Full troubleshooting guide:"
        echo "   https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc#destroy-troubleshooting"
        echo ""
        echo "⚠️  DESTROY STOPPED to prevent orphaned AWS resources!"
        exit 1
      fi

      echo "✅ EKS API access confirmed"
      echo ""

      # Cleanup Helm releases with wait
      echo "🗑️  Uninstalling Helm releases (timeout: ${self.triggers.timeout}s)..."

      # Primary release
      if helm list -n ${self.triggers.namespace} | grep -q "${local.name_prefix}-initialize"; then
        echo "📦 Removing ${local.name_prefix}-initialize..."
        if ! helm uninstall ${local.name_prefix}-initialize -n ${self.triggers.namespace} --wait --timeout=${self.triggers.timeout}s; then
          echo "❌ Failed to uninstall ${local.name_prefix}-initialize"
          echo "📚 Troubleshooting: https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc#helm-cleanup-failures"
          exit 1
        fi
        echo "✅ ${local.name_prefix}-initialize removed"
      else
        echo "ℹ️  ${local.name_prefix}-initialize not found (already removed)"
      fi

      # Replication release (if exists)
      if helm list -n ${self.triggers.namespace} | grep -q "${local.name_prefix}-replicate"; then
        echo "📦 Removing ${local.name_prefix}-replicate..."
        if ! helm uninstall ${local.name_prefix}-replicate -n ${self.triggers.namespace} --wait --timeout=${self.triggers.timeout}s; then
          echo "❌ Failed to uninstall ${local.name_prefix}-replicate"
          echo "📚 Troubleshooting: https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc#helm-cleanup-failures"
          exit 1
        fi
        echo "✅ ${local.name_prefix}-replicate removed"
      else
        echo "ℹ️  ${local.name_prefix}-replicate not found (already removed)"
      fi

      echo ""
      echo "🎉 Helm cleanup completed successfully!"
      echo "✅ Safe to proceed with infrastructure destruction"
    EOT
  }

  # Only run when Helm releases are actually being destroyed
  depends_on = [
    helm_release.unreal_cloud_ddc_initialization,
    helm_release.unreal_cloud_ddc_with_replication
  ]
}

################################################################################
# Local Variables
################################################################################

locals {
  # Naming consistency with other modules
  name_prefix = "${var.project_prefix}-${var.name}"

  helm_config = {
    bucket_name      = var.s3_bucket_id
    scylla_ips       = join(",", var.scylla_ips)
    region           = var.region
    aws_region       = var.region
    token            = var.ddc_bearer_token
    nlb_arn          = var.nlb_arn
    target_group_arn = var.nlb_target_group_arn
  }

  base_values = var.unreal_cloud_ddc_helm_base_infra_chart != null ? [templatefile(var.unreal_cloud_ddc_helm_base_infra_chart, local.helm_config)] : []

  replication_values = var.unreal_cloud_ddc_helm_replication_chart != null ? [
    templatefile(var.unreal_cloud_ddc_helm_replication_chart, merge(local.helm_config, {
      ddc_replication_region_url = var.ddc_replication_region_url
    }))
  ] : null
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
  timeout      = 2700

  disable_webhooks = true
  cleanup_on_fail  = true

  values = local.base_values

  depends_on = [
    aws_ecr_pull_through_cache_rule.unreal_cloud_ddc_ecr_pull_through_cache_rule
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
  repository   = "oci://${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/github/epicgames"
  namespace    = var.namespace
  version      = "${var.unreal_cloud_ddc_version}+helm"
  reset_values = true
  timeout      = 600

  values = local.replication_values

  depends_on = [
    time_sleep.wait_for_init,
    null_resource.helm_cleanup
  ]
}

################################################################################
# SSM Execution for Multi-Region Keyspace Configuration
################################################################################

# Execute SSM document to configure keyspaces (only in secondary region)
resource "null_resource" "trigger_ssm_keyspace_update" {
  count = var.ssm_document_name != null && var.ddc_replication_region_url != null ? 1 : 0

  triggers = {
    # Trigger after both regions have deployed their services
    deployment_complete = helm_release.unreal_cloud_ddc_initialization.version
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
