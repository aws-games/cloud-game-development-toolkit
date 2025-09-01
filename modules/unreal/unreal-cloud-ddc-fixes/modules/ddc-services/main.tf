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
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "🧹 Cleaning up ECR repositories created by pull-through cache..."
      
      # Delete the auto-created repository (ignore errors if it doesn't exist)
      aws ecr delete-repository \
        --repository-name ${self.triggers.repository_name} \
        --region ${self.triggers.region} \
        --force 2>/dev/null || echo "ℹ️  Repository ${self.triggers.repository_name} not found or already deleted"
      
      echo "✅ ECR cleanup completed"
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
      if helm list -n ${self.triggers.namespace} | grep -q "${self.triggers.name_prefix}-initialize"; then
        echo "📦 Removing ${self.triggers.name_prefix}-initialize..."
        if ! helm uninstall ${self.triggers.name_prefix}-initialize -n ${self.triggers.namespace} --wait --timeout=${self.triggers.timeout}s; then
          echo "❌ Failed to uninstall ${self.triggers.name_prefix}-initialize"
          echo "📚 Troubleshooting: https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc#helm-cleanup-failures"
          exit 1
        fi
        echo "✅ ${self.triggers.name_prefix}-initialize removed"
      else
        echo "ℹ️  ${self.triggers.name_prefix}-initialize not found (already removed)"
      fi

      # Replication release (if exists)
      if helm list -n ${self.triggers.namespace} | grep -q "${self.triggers.name_prefix}-replicate"; then
        echo "📦 Removing ${self.triggers.name_prefix}-replicate..."
        if ! helm uninstall ${self.triggers.name_prefix}-replicate -n ${self.triggers.namespace} --wait --timeout=${self.triggers.timeout}s; then
          echo "❌ Failed to uninstall ${self.triggers.name_prefix}-replicate"
          echo "📚 Troubleshooting: https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc#helm-cleanup-failures"
          exit 1
        fi
        echo "✅ ${self.triggers.name_prefix}-replicate removed"
      else
        echo "ℹ️  ${self.triggers.name_prefix}-replicate not found (already removed)"
      fi

      echo ""
      echo "🎉 Helm cleanup completed successfully!"
      echo "✅ Safe to proceed with infrastructure destruction"
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
  
  # Use ClusterIP service type (internal only)
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

  depends_on = [
    time_sleep.ecr_rule_propagation,  # Wait for ECR rule to propagate
    module.eks_blueprints_addons      # Terraform handles dependency ordering
  ]
}

################################################################################
# TargetGroupBinding - Connect ClusterIP Service to Existing NLB Target Group
################################################################################

resource "kubectl_manifest" "target_group_binding" {
  count = var.nlb_target_group_arn != null ? 1 : 0
  
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
