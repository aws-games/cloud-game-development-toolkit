################################################################################
# External DNS EKS Addon (Critical for Service Discovery)
################################################################################

# External DNS EKS Addon
resource "aws_eks_addon" "external_dns" {
  region                   = var.region
  cluster_name             = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  addon_name               = "external-dns"
  addon_version            = var.external_dns_addon_version
  service_account_role_arn = local.external_dns_role_arn
  resolve_conflicts_on_update = "OVERWRITE"

  timeouts {
    create = "15m"
    update = "15m"
    delete = "10m"
  }

  configuration_values = jsonencode({
    # Remove domainFilters to allow discovery of all zones for split-horizon DNS
    registry      = "txt"
    txtOwnerId    = local.name_prefix
    sources       = ["service", "ingress"]
    policy        = "sync"
    # Remove aws-zone-type restriction to allow both public and private zone discovery
    # Service annotations will handle zone targeting
  })

  tags = var.tags

  depends_on = [
    aws_eks_cluster.unreal_cloud_ddc_eks_cluster,
    terraform_data.cluster_setup_trigger
  ]
}

################################################################################
# FluentBit EKS Addon (Logging Infrastructure)
################################################################################
#
# Cluster-wide log collection and forwarding to CloudWatch
# Only deployed when centralized logging is enabled
################################################################################

# FluentBit EKS Addon
resource "aws_eks_addon" "fluent_bit" {
  count = var.enable_centralized_logging ? 1 : 0

  region                   = var.region
  cluster_name             = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  addon_name               = "fluent-bit"
  addon_version            = var.fluent_bit_addon_version
  service_account_role_arn = aws_iam_role.fluent_bit_role[0].arn
  resolve_conflicts_on_update = "OVERWRITE"

  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }

  configuration_values = jsonencode({
    config = {
      outputs = <<-EOT
        [OUTPUT]
            Name cloudwatch_logs
            Match *
            region ${var.region}
            log_group_name ${local.name_prefix}
            log_stream_prefix fluent-bit-
            auto_create_group On
      EOT
    }
    tolerations = [
      {
        key = "node-role.kubernetes.io/master"
        operator = "Exists"
        effect = "NoSchedule"
      },
      {
        key = "node-role.kubernetes.io/control-plane"
        operator = "Exists"
        effect = "NoSchedule"
      }
    ]
    nodeSelector = {
      "kubernetes.io/os" = "linux"
    }
    resources = {
      limits = {
        memory = "250Mi"
      }
      requests = {
        cpu = "50m"
        memory = "50Mi"
      }
    }
  })

  tags = var.tags

  depends_on = [
    aws_eks_cluster.unreal_cloud_ddc_eks_cluster,
    terraform_data.cluster_setup_trigger
  ]
}
