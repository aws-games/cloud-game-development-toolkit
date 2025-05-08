################################################################################
# EKS Node IAM Roles
################################################################################

################################################################################
# System Role
################################################################################
resource "aws_iam_role" "system_node_group_role" {
  name_prefix = "system-node-group-role-"

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
}

resource "aws_iam_role_policy_attachments_exclusive" "system_policy_attachement" {
  role_name = aws_iam_role.system_node_group_role.name
  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

################################################################################
# NVME Role
################################################################################
resource "aws_iam_role" "nvme_node_group_role" {
  name_prefix = "nvme-node-group-role-"

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
}

#checkov:skip=CKV_AWS_290: Permissions are needed for NVME policy
resource "aws_iam_role_policy_attachments_exclusive" "nvme_policy_attachement" {
  role_name = aws_iam_role.nvme_node_group_role.name
  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

################################################################################
# Worker Node Role
################################################################################
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
}

resource "aws_iam_role_policy_attachments_exclusive" "worker_policy_attachement" {
  role_name = aws_iam_role.worker_node_group_role.name
  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}
################################################################################
# EKS Role
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
}

resource "aws_iam_role_policy_attachments_exclusive" "eks_cluster_policy_attachement" {
  role_name = aws_iam_role.eks_cluster_role.name
  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  ]
}

################################################################################
# Scylla Role
################################################################################
resource "aws_iam_role" "scylla_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "ScyllaDbRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  name_prefix = "scylla-db-"
}

resource "aws_iam_role_policy_attachments_exclusive" "scylla_policy_attachement" {
  role_name = aws_iam_role.scylla_role.name
  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

################################################################################
# Scylla Monitoring Role
################################################################################

resource "aws_iam_role" "scylla_monitoring_role" {
  count = var.create_scylla_monitoring_stack ? 1 : 0
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  name_prefix = "scylla-monitoring-"
}

resource "aws_iam_role_policy" "scylla_monitoring_policy" {
  count = var.create_scylla_monitoring_stack ? 1 : 0
  name  = "scylla-monitoring-policy"
  role  = aws_iam_role.scylla_monitoring_role[count.index].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Name" : "scylla-node*" # Adjust this tag to match your Scylla node naming
          }

        }
      }
    ]
  })
}

################################################################################
# Scylla Monitoring ALB Access Logs Bucket Policy
################################################################################

data "aws_iam_policy_document" "access_logs_bucket_alb_write" {
  count = var.enable_scylla_monitoring_lb_access_logs && var.scylla_monitoring_lb_access_logs_bucket == null ? 1 : 0
  statement {
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
    resources = ["${var.scylla_monitoring_lb_access_logs_bucket != null ? var.scylla_monitoring_lb_access_logs_bucket : aws_s3_bucket.scylla_monitoring_lb_access_logs_bucket[0].arn}/${var.scylla_monitoring_lb_access_logs_prefix != null ? var.scylla_monitoring_lb_access_logs_prefix : "${var.name}-alb"}/*"
    ]
  }
}
