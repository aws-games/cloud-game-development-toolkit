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
