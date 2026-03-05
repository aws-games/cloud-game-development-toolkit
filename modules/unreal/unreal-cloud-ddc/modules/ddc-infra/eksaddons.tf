################################################################################
# Addon Version Data Sources (Foundation)
################################################################################

# Dynamic addon version fetching - no count needed, always fetch versions
data "aws_eks_addon_version" "external_dns" {
  addon_name         = "external-dns"
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

data "aws_eks_addon_version" "fluent_bit" {
  addon_name         = "fluent-bit"
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

################################################################################
# External DNS EKS Addon (Critical for Service Discovery)
################################################################################

# External DNS EKS Addon
resource "aws_eks_addon" "external_dns" {
  cluster_name             = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  addon_name               = "external-dns"
  addon_version            = data.aws_eks_addon_version.external_dns.version
  service_account_role_arn = aws_iam_role.external_dns.arn
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
    aws_iam_role.external_dns,
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
  
  cluster_name             = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  addon_name               = "fluent-bit"
  addon_version            = data.aws_eks_addon_version.fluent_bit.version
  service_account_role_arn = aws_iam_role.fluent_bit_role[0].arn
  resolve_conflicts_on_update = "OVERWRITE"
  
  timeouts {
    create = "5m"
    update = "5m"
    delete = "5m"
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
    aws_iam_role.fluent_bit_role,
    terraform_data.cluster_setup_trigger
  ]
}

################################################################################
# DNS Cleanup (Operational Automation)
################################################################################

# LEGACY: DNS Cleanup (replaced by removing dependency)
# Clean up orphaned External-DNS records before deployment and on destroy
# resource "null_resource" "cleanup_orphaned_dns_records" {
#   triggers = {
#     cluster_id = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.id
#   }
# 
#   provisioner "local-exec" {
#     command = <<-EOT
#       # Determine which zone External-DNS uses (matches locals.tf service_domain logic)
#       if [ "${var.route53_hosted_zone_name}" != "null" ]; then
#         # User provided zone (public or private)
#         ZONE_NAME="${var.route53_hosted_zone_name}."
#         SERVICE_DOMAIN="${var.environment}.ddc.${var.route53_hosted_zone_name}"
#       else
#         # Our private zone
#         ZONE_NAME="${var.environment}.ddc.${var.project_prefix}.internal."
#         SERVICE_DOMAIN="${var.environment}.ddc.${var.project_prefix}.internal"
#       fi
#       
#       # Find the zone External-DNS is using
#       ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='$ZONE_NAME'].Id" --output text | sed 's|/hostedzone/||')
#       
#       if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "None" ]; then
#         echo "Zone $ZONE_NAME not found, skipping cleanup"
#         exit 0
#       fi
#       
#       # DDC pattern to clean up (includes TXT ownership records with prefixes)
#       DDC_PATTERN="${var.region}.$SERVICE_DOMAIN"
#       
#       # Clean up External-DNS records in the target zone (A, AAAA, TXT ownership records)
#       aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" \
#         --query "ResourceRecordSets[?contains(Name, '$DDC_PATTERN') || contains(Name, 'aaaa-${var.region}.$SERVICE_DOMAIN') || contains(Name, 'cname-${var.region}.$SERVICE_DOMAIN')]" --output json | jq -c '.[]' | while read record; do
#         RECORD_NAME=$(echo "$record" | jq -r '.Name')
#         RECORD_TYPE=$(echo "$record" | jq -r '.Type')
#         echo "Deleting External-DNS record: $RECORD_TYPE $RECORD_NAME in zone $ZONE_NAME"
#         echo '{"Changes":[{"Action":"DELETE","ResourceRecordSet":'$record'}]}' | \
#           aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch file:///dev/stdin
#       done
#     EOT
#   }
# 
# 
# }

