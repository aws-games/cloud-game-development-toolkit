################################################################################
# EKS Node IAM Roles
################################################################################

################################################################################
# System Role
################################################################################
resource "aws_iam_role" "system_node_group_role" {
  name_prefix = "${local.name_prefix}-system-ng-role-"

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
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-system-role"
    }
  )
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
  name_prefix = "${local.name_prefix}-nvme-ng-role-"

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
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-nvme-role"
    }
  )
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
  name_prefix = "${local.name_prefix}-eks-ng-role-"

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
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-eks-ng-role"
    }
  )
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
  name_prefix = "${local.name_prefix}-eks-cluster-role-"

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
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-eks-cluster-role"
    }
  )
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
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-scylla-role"
    }
  )
}

resource "aws_iam_role_policy_attachments_exclusive" "scylla_policy_attachement" {
  role_name = aws_iam_role.scylla_role.name
  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
}





################################################################################
# Application IAM Roles (Moved from applications module)
################################################################################

resource "aws_iam_role" "ebs_csi_iam_role" {
  name_prefix = "${local.name_prefix}-ebs-csi-sa-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid    = ""
      Effect = "Allow",
      Principal = {
        Federated = aws_iam_openid_connect_provider.unreal_cloud_ddc_oidc_provider.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${aws_iam_openid_connect_provider.unreal_cloud_ddc_oidc_provider.arn}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${aws_iam_openid_connect_provider.unreal_cloud_ddc_oidc_provider.arn}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-ebs-csi-sa-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy_attacment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_iam_role.name
}

resource "aws_iam_policy" "s3_secrets_manager_iam_policy" {
  name_prefix = "${local.name_prefix}-s3-secrets-manager-policy-"
  path        = "/"
  description = "Policy to grant access to unreal cloud ddc bucket"

  policy = data.aws_iam_policy_document.unreal_cloud_ddc_policy.json
}

resource "aws_iam_role" "unreal_cloud_ddc_sa_iam_role" {
  name_prefix = "${local.name_prefix}-sa-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid    = ""
      Effect = "Allow",
      Principal = {
        Federated = aws_iam_openid_connect_provider.unreal_cloud_ddc_oidc_provider.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.unreal_cloud_ddc_oidc_provider.arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:${var.unreal_cloud_ddc_namespace}:${var.unreal_cloud_ddc_service_account_name}"
          "${replace(aws_iam_openid_connect_provider.unreal_cloud_ddc_oidc_provider.arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-sa-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "unreal_cloud_ddc_sa_iam_role_s3_secrets_policy_attachment" {
  role       = aws_iam_role.unreal_cloud_ddc_sa_iam_role.name
  policy_arn = aws_iam_policy.s3_secrets_manager_iam_policy.arn
}

data "aws_iam_policy_document" "unreal_cloud_ddc_policy" {
  # S3 for Service Account
  statement {
    sid    = "S3Allow"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectAttributes",
      "s3:GetObjectTagging",
      "s3:PutObjectTagging",
      "s3:DeleteObjectTagging",
      "s3:DeleteObject",
      "s3:List*",
    ]
    resources = [
      aws_s3_bucket.unreal_ddc_s3_bucket.arn,
      "${aws_s3_bucket.unreal_ddc_s3_bucket.arn}/*"
    ]
  }
  # Secrets Manager for Service account
  dynamic "statement" {
    for_each = compact([var.oidc_credentials_secret_manager_arn])
    content {
      sid    = "SecretsManagerGet"
      effect = "Allow"
      actions = [
        "secretsmanager:GetSecretValue"
      ]
      resources = [
        statement.value,
      ]
    }
  }
}
