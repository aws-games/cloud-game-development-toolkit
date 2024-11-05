################################################################################
# EKS Node IAM Role
################################################################################

resource "aws_iam_role" "monitoring_node_group_role" {
  name_prefix = "unreal-cloud-ddc-eks-node-group-role-"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  inline_policy {
    name = "external-dns-policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = ["route53:ChangeResourceRecordSets"]
          Effect = "Allow"
          Resource = [
            "arn:aws:route53:::hostedzone/*"
          ]
        },
        {
          Action = [
            "route53:ListHostedZones",
            "route53:ListResourceRecordSets",
            "route53:ListTagsForResource"
          ],
          Effect   = "Allow"
          Resource = ["*"]
        }
      ]
    })
  }
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

resource "aws_iam_role" "nvme_node_group_role" {
  name_prefix = "unreal-cloud-ddc-eks-node-group-role-"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

resource "aws_iam_role" "worker_node_group_role" {
  name_prefix = "unreal-cloud-ddc-eks-node-group-role-"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}




################################################################################
# EKS Cluster
################################################################################
resource "aws_iam_role" "eks_cluster_role" {
  name_prefix = "unreal-cloud-ddc-eks-cluster-role-"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  ]
}

resource "aws_eks_cluster" "unreal_cloud_ddc_eks_cluster" {
  #checkov:skip=CKV_AWS_39:Ensure Amazon EKS public endpoint disabled
  #checkov:skip=CKV_AWS_58:Ensure EKS Cluster has Secrets Encryption Enabled
  #checkov:skip=CKV_AWS_339:Ensure EKS clusters run on a supported Kubernetes version
  #checkov:skip=CKV_AWS_38:IP restriction set in module variables
  name                      = var.name
  role_arn                  = aws_iam_role.eks_cluster_role.arn
  version                   = "1.29"
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]



  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = var.private_subnets
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.eks_cluster_access_cidr
    security_group_ids = [
      aws_security_group.system_security_group.id,
      aws_security_group.worker_security_group.id,
      aws_security_group.nvme_security_group.id
    ]
  }
}

resource "aws_cloudwatch_log_group" "unreal_cluster_cloudwatch" {
  #checkov:skip=CKV_AWS_158:Ensure that CloudWatch Log Group is encrypted by KMS
  name_prefix       = "/aws/eks/${var.name}/cluster"
  retention_in_days = 365

}

data "aws_ssm_parameter" "eks_ami_latest_release" {
  name = "/aws/service/eks/optimized-ami/${aws_eks_cluster.unreal_cloud_ddc_eks_cluster.version}/amazon-linux-2/recommended/release_version"
}

################################################################################
# Worker Node Group
################################################################################
resource "aws_eks_node_group" "worker_node_group" {
  cluster_name    = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  node_group_name = "unreal-cloud-ddc-worker-ng"
  version         = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.version
  release_version = nonsensitive(data.aws_ssm_parameter.eks_ami_latest_release.value)
  node_role_arn   = aws_iam_role.worker_node_group_role.arn
  subnet_ids      = var.private_subnets

  labels = {
    "unreal-cloud-ddc/node-type" = "worker"
  }

  taint {
    key    = "role"
    value  = "unreal-cloud-ddc"
    effect = "NO_SCHEDULE"
  }

  scaling_config {
    desired_size = var.worker_managed_node_desired_size
    max_size     = var.worker_managed_node_max_size
    min_size     = 0
  }
  launch_template {
    id      = aws_launch_template.worker_launch_template.id
    version = aws_launch_template.worker_launch_template.latest_version
  }
  tags = {
    Name = "unreal-cloud-ddc-worker-instance"
  }
}

resource "aws_launch_template" "worker_launch_template" {
  #checkov:skip=CKV_AWS_341:Ensure Launch template should not have a metadata response hop limit greater than 1
  name_prefix   = "unreal-ddc-worker-launch-template"
  instance_type = var.worker_managed_node_instance_type
  vpc_security_group_ids = [
    aws_security_group.worker_security_group.id,
    aws_eks_cluster.unreal_cloud_ddc_eks_cluster.vpc_config[0].cluster_security_group_id,
    aws_security_group.scylla_security_group.id
  ]

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
    tags = {
      Name = "unreal-ddc-worker-instance"
    }
  }
}

################################################################################
# NVME Node Group
################################################################################
resource "aws_eks_node_group" "nvme_node_group" {
  cluster_name    = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  node_group_name = "unreal-cloud-ddc-nvme-ng"
  version         = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.version
  release_version = nonsensitive(data.aws_ssm_parameter.eks_ami_latest_release.value)
  node_role_arn   = aws_iam_role.nvme_node_group_role.arn
  subnet_ids      = var.private_subnets

  labels = {
    "unreal-cloud-ddc/node-type" = "nvme"
  }

  taint {
    key    = "role"
    value  = "unreal-cloud-ddc"
    effect = "NO_SCHEDULE"
  }

  scaling_config {
    desired_size = var.nvme_managed_node_desired_size
    max_size     = var.nvme_managed_node_max_size
    min_size     = 1
  }

  launch_template {
    id      = aws_launch_template.nvme_launch_template.id
    version = aws_launch_template.nvme_launch_template.latest_version
  }

}

resource "aws_launch_template" "nvme_launch_template" {
  #checkov:skip=CKV_AWS_341:Ensure Launch template should not have a metadata response hop limit greater than 1
  name_prefix   = "unreal-ddc-nvme-launch-template"
  instance_type = var.nvme_managed_node_instance_type
  user_data     = base64encode(local.nvme-pre-bootstrap-userdata)
  vpc_security_group_ids = [
    aws_security_group.nvme_security_group.id,
    aws_eks_cluster.unreal_cloud_ddc_eks_cluster.vpc_config[0].cluster_security_group_id,
    aws_security_group.scylla_security_group.id
  ]

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
    tags = {
      Name = "unreal-ddc-nvme-instance"
    }
  }
}

################################################################################
# System Node Group
################################################################################
resource "aws_eks_node_group" "system_node_group" {
  cluster_name    = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  node_group_name = "unreal-cloud-ddc-monitoring-ng"
  version         = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.version
  release_version = nonsensitive(data.aws_ssm_parameter.eks_ami_latest_release.value)
  node_role_arn   = aws_iam_role.monitoring_node_group_role.arn
  subnet_ids      = var.private_subnets
  labels = {
    "pool" = "system-pool"
  }

  launch_template {
    id      = aws_launch_template.system_launch_template.id
    version = aws_launch_template.system_launch_template.latest_version
  }

  scaling_config {
    desired_size = var.system_managed_node_desired_size
    max_size     = var.system_managed_node_max_size
    min_size     = 1
  }
  tags = {
    Name = "unreal-cloud-ddc-system-instance"
  }
}

resource "aws_launch_template" "system_launch_template" {
  #checkov:skip=CKV_AWS_341:Ensure Launch template should not have a metadata response hop limit greater than 1
  name_prefix   = "unreal-ddc-system-launch-template"
  instance_type = var.system_managed_node_instance_type

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  vpc_security_group_ids = [
    aws_security_group.system_security_group.id,
    aws_eks_cluster.unreal_cloud_ddc_eks_cluster.vpc_config[0].cluster_security_group_id
  ]

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "unreal-ddc-system-instance"
    }
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

resource "aws_eks_identity_provider_config" "eks_cluster_oidc_association" {
  cluster_name = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name

  oidc {
    client_id                     = substr(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer, -32, -1)
    identity_provider_config_name = "unreal-ddc-oidc-provider"
    issuer_url                    = "https://${aws_iam_openid_connect_provider.unreal_cloud_ddc_oidc_provider.url}"
  }
}
