################################################################################
# EKS Cluster with Auto Mode
################################################################################

resource "awscc_eks_cluster" "unreal_cloud_ddc_eks_cluster" {
  name                      = "${local.name_prefix}-cluster"
  role_arn                  = aws_iam_role.eks_cluster_role.arn
  version                   = var.kubernetes_version
  logging                   = {
    cluster_logging = {
      enabled_types = var.eks_cluster_logging_types
    }
  }

  access_config = {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  resources_vpc_config = {
    subnet_ids              = var.eks_node_group_subnets
    endpoint_config = {
      private_access = var.eks_cluster_private_access
      public_access  = var.eks_cluster_public_access
      public_access_cidrs = var.eks_cluster_public_endpoint_access_cidr
    }
    security_group_ids = [
      aws_security_group.system_security_group.id,
      aws_security_group.worker_security_group.id,
      aws_security_group.nvme_security_group.id,
      aws_security_group.cluster_security_group.id
    ]
  }

  # EKS Auto Mode Configuration
  compute_config = {
    enabled = true
  }
  
  kubernetes_network_config = {
    elastic_load_balancing = {
      enabled = false  # We use external-dns instead
    }
  }
  
  storage_config = {
    block_storage = {
      enabled = true  # EBS CSI driver
    }
  }
  
  bootstrap_self_managed_addons = true  # Required for external-dns

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "unreal_cluster_cloudwatch" {
  #checkov:skip=CKV_AWS_158:Ensure that CloudWatch Log Group is encrypted by KMS
  name_prefix       = var.eks_cluster_cloudwatch_log_group_prefix
  retention_in_days = 365
}

################################################################################
# EKS Auto Mode Node Configuration
# Note: EKS Auto Mode automatically manages nodes - no manual node groups needed
################################################################################

# EKS Auto Mode will automatically:
# - Create and manage nodes based on pod requirements
# - Handle scaling, patching, and lifecycle management
# - Support both NVMe (i4i instances) and EBS storage
# - Apply appropriate taints and labels based on workload requirements

################################################################################
# Subnet Tagging for EKS Auto Mode Load Balancing
################################################################################

# Tag public subnets for internet-facing load balancers
resource "aws_ec2_tag" "public_subnet_elb_tags" {
  for_each    = toset(var.public_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

# Tag private subnets for internal load balancers
resource "aws_ec2_tag" "private_subnet_elb_tags" {
  for_each    = toset(var.private_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}
################################################################################
# EKS Cluster Open ID Connect Provider
################################################################################
data "tls_certificate" "eks_tls_certificate" {
  url = awscc_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "unreal_cloud_ddc_oidc_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_tls_certificate.certificates[0].sha1_fingerprint]
  url             = data.tls_certificate.eks_tls_certificate.url
}
