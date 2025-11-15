################################################################################
# External DNS EKS Addon
################################################################################
# 
# The External-DNS EKS addon watches Kubernetes LoadBalancer services and 
# creates Route53 DNS records dynamically based on service annotations.
# 
# IMPORTANT: For AWS LoadBalancers (NLB/ALB), External-DNS creates:
# 1. A record (ALIAS type) pointing to the LoadBalancer DNS name
# 2. TXT record for ownership tracking (registry = "txt")
# 
# Source: https://github.com/kubernetes-sigs/external-dns/issues/2903
# External-DNS detects AWS ELB hostnames and automatically creates ALIAS A records
# instead of CNAME records for better performance and zone apex support.
# 
# EXAMPLES:
# 
# Public Zone + ACM Certificate:
# - ddc_endpoint_pattern: "us-east-1.dev.ddc.example.com"
# - External-DNS creates: ALIAS A record in public zone "example.com"
# - LoadBalancer: HTTPS (port 443) + HTTP (port 80)
# - Access: Internet + VPC (split-horizon DNS)
# 
# Public Zone + No Certificate:
# - ddc_endpoint_pattern: "us-east-1.dev.ddc.example.com"
# - External-DNS creates: ALIAS A record in public zone "example.com"
# - LoadBalancer: HTTP only (port 80)
# - Access: Internet + VPC (split-horizon DNS)
# 
# Private Zone + Private CA Certificate:
# - ddc_endpoint_pattern: "us-east-1.dev.ddc.cgd.internal"
# - External-DNS creates: ALIAS A record in private zone "cgd.internal"
# - LoadBalancer: HTTPS (port 443) + HTTP (port 80)
# - Access: VPC only (internal DNS)
# 
# Private Zone + No Certificate:
# - ddc_endpoint_pattern: "us-east-1.dev.ddc.cgd.internal"
# - External-DNS creates: ALIAS A record in private zone "cgd.internal"
# - LoadBalancer: HTTP only (port 80)
# - Access: VPC only (internal DNS)
# 
# Only deployed when Route53 hosted zone is configured
################################################################################

# IAM Role for External DNS
resource "aws_iam_role" "external_dns" {
  count = var.route53_hosted_zone_name != null ? 1 : 0
  name  = "${local.name_prefix}-external-dns-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks_oidc[0].arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_url}:sub" = "system:serviceaccount:external-dns:external-dns"
          "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
  
  tags = var.tags
}

# IAM Policy for External DNS
resource "aws_iam_role_policy" "external_dns" {
  count = var.route53_hosted_zone_name != null ? 1 : 0
  name  = "external-dns-policy"
  role  = aws_iam_role.external_dns[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = [data.aws_route53_zone.public[0].arn]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ]
        Resource = "*"
      }
    ]
  })
}

# External DNS EKS Addon
resource "aws_eks_addon" "external_dns" {
  count = var.route53_hosted_zone_name != null ? 1 : 0
  
  cluster_name             = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  addon_name               = "external-dns"
  addon_version            = data.aws_eks_addon_version.external_dns.version
  service_account_role_arn = aws_iam_role.external_dns[0].arn
  resolve_conflicts_on_update = "OVERWRITE"
  
  timeouts {
    create = "10m"
    update = "10m"
    delete = "5m"
  }
  
  configuration_values = jsonencode({
    domainFilters = [var.route53_hosted_zone_name]
    registry      = "txt"
    txtOwnerId    = local.name_prefix
    sources       = ["service", "ingress"]
    policy        = "sync"
    extraArgs = [
      "--aws-zone-type=${contains(["internal"], split(".", var.route53_hosted_zone_name)) ? "private" : "public"}"
    ]
  })
  
  tags = var.tags
  
  depends_on = [
    aws_eks_cluster.unreal_cloud_ddc_eks_cluster,
    aws_iam_role.external_dns,
    null_resource.aws_load_balancer_controller
  ]
}

# Data source for Route53 hosted zone
data "aws_route53_zone" "public" {
  count = var.route53_hosted_zone_name != null ? 1 : 0
  name  = var.route53_hosted_zone_name
}

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
# FluentBit EKS Addon
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
    null_resource.aws_load_balancer_controller
  ]
}

