################################################################################
# EKS Cluster
################################################################################

resource "aws_eks_cluster" "unreal_cloud_ddc_eks_cluster" {
  #checkov:skip=CKV_AWS_39:EKS Public Endpoint needs to be open to configure the eks cluster.
  #checkov:skip=CKV_AWS_58:Secrets encryption will be enabled in a future update
  #checkov:skip=CKV_AWS_38:IP restriction set in module variables with a conditional
  #checkov:skip=CKV_AWS_339:Checkov not picking up supported version correctly. Added validation to check for correct version
  name                      = "${local.name_prefix}-cluster"
  role_arn                  = aws_iam_role.eks_cluster_role.arn
  version                   = var.kubernetes_version
  enabled_cluster_log_types = var.eks_cluster_logging_types



  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = var.eks_node_group_subnets
    endpoint_private_access = var.eks_cluster_private_access
    endpoint_public_access  = var.eks_cluster_public_access
    public_access_cidrs     = var.eks_cluster_public_endpoint_access_cidr
    security_group_ids = [
      aws_security_group.system_security_group.id,
      aws_security_group.worker_security_group.id,
      aws_security_group.nvme_security_group.id,
      aws_security_group.cluster_security_group.id
    ]
  }
}

resource "aws_cloudwatch_log_group" "unreal_cluster_cloudwatch" {
  #checkov:skip=CKV_AWS_158:Ensure that CloudWatch Log Group is encrypted by KMS
  name_prefix       = var.eks_cluster_cloudwatch_log_group_prefix
  retention_in_days = 365
}

################################################################################
# Worker Node Group
################################################################################
resource "aws_eks_node_group" "worker_node_group" {
  cluster_name    = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  node_group_name = "${local.name_prefix}-worker-ng"
  version         = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.version
  node_role_arn   = aws_iam_role.worker_node_group_role.arn
  subnet_ids      = var.eks_node_group_subnets

  labels = var.worker_node_group_label

  taint {
    key    = "role"
    value  = "unreal-cloud-ddc"
    effect = "NO_SCHEDULE"
  }

  scaling_config {
    desired_size = var.worker_managed_node_desired_size
    max_size     = var.worker_managed_node_max_size
    min_size     = var.worker_managed_node_min_size
  }
  launch_template {
    id      = aws_launch_template.worker_launch_template.id
    version = aws_launch_template.worker_launch_template.latest_version
  }
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-worker-instance"
    }
  )
}

#Launch Templates default to intel based amazon linux need to fix
resource "aws_launch_template" "worker_launch_template" {
  #checkov:skip=CKV_AWS_341:Hop limit of 2 is a best practice for container environments. See docs in comment.
  name_prefix   = "${local.name_prefix}-worker-launch-template"
  instance_type = var.worker_managed_node_instance_type
  vpc_security_group_ids = [
    aws_security_group.worker_security_group.id,
    aws_security_group.scylla_security_group.id,
    aws_security_group.cluster_security_group.id
  ]

  //In line with best practices for container environments
  // https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-options.html
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags,
      {
        Name = "${local.name_prefix}-worker-instance"
      }
    )
  }
}

################################################################################
# NVME Node Group
################################################################################
resource "aws_eks_node_group" "nvme_node_group" {
  cluster_name    = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  node_group_name = "${local.name_prefix}-nvme-ng"
  version         = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.version
  node_role_arn   = aws_iam_role.nvme_node_group_role.arn
  subnet_ids      = var.eks_node_group_subnets

  labels = var.nvme_node_group_label

  taint {
    key    = "role"
    value  = "unreal-cloud-ddc"
    effect = "NO_SCHEDULE"
  }

  scaling_config {
    desired_size = var.nvme_managed_node_desired_size
    max_size     = var.nvme_managed_node_max_size
    min_size     = var.nvme_managed_node_min_size
  }

  launch_template {
    id      = aws_launch_template.nvme_launch_template.id
    version = aws_launch_template.nvme_launch_template.latest_version
  }
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-nvme-instance"
    }
  )
}

#Launch Templates default to intel based amazon linux need to fix
resource "aws_launch_template" "nvme_launch_template" {
  #checkov:skip=CKV_AWS_341:Hop limit of 2 is a best practice for container environments. See docs in comment.
  name_prefix   = "${local.name_prefix}-nvme-launch-template"
  instance_type = var.nvme_managed_node_instance_type
  user_data     = base64encode(local.nvme-pre-bootstrap-userdata)
  vpc_security_group_ids = [
    aws_security_group.nvme_security_group.id,
    aws_security_group.scylla_security_group.id,
    aws_security_group.cluster_security_group.id
  ]

  //In line with our recommendation for container environments
  // https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-options.html
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags,
      {
        Name = "${local.name_prefix}-nvme-instance"
      }
    )
  }
}

################################################################################
# System Node Group
################################################################################
resource "aws_eks_node_group" "system_node_group" {
  cluster_name    = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  node_group_name = "${local.name_prefix}-system-ng"
  version         = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.version
  node_role_arn   = aws_iam_role.system_node_group_role.arn
  subnet_ids      = var.eks_node_group_subnets
  labels          = var.system_node_group_label

  launch_template {
    id      = aws_launch_template.system_launch_template.id
    version = aws_launch_template.system_launch_template.latest_version
  }

  scaling_config {
    desired_size = var.system_managed_node_desired_size
    max_size     = var.system_managed_node_max_size
    min_size     = var.system_managed_node_min_size
  }

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-system-instance"
    }
  )
}

#Launch Templates default to intel based amazon linux need to fix
resource "aws_launch_template" "system_launch_template" {
  #checkov:skip=CKV_AWS_341:Hop limit 2 required for the load balancer controller. Hop limit of 2 is a best practice for container environments. See docs in comment.
  name_prefix   = "${local.name_prefix}-system-launch-template"
  instance_type = var.system_managed_node_instance_type

  //In line with best practices for container environments
  //https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-options.html
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  vpc_security_group_ids = [
    aws_security_group.system_security_group.id,
    aws_security_group.cluster_security_group.id
  ]

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags,
      {
        Name = "${local.name_prefix}-system-instance"
      }
    )
  }
}
################################################################################
# EKS Cluster Open ID Connect Provider
################################################################################
data "tls_certificate" "eks_tls_certificate" {
  url = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "unreal_cloud_ddc_oidc_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_tls_certificate.certificates[0].sha1_fingerprint]
  url             = data.tls_certificate.eks_tls_certificate.url
}
