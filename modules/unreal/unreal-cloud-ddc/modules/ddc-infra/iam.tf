

################################################################################
# Scylla Role
################################################################################
data "aws_iam_policy_document" "scylla_assume_role" {
  count = var.scylla_config != null ? 1 : 0
  
  statement {
    sid    = "ScyllaDbRole"
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scylla_role" {
  count = var.scylla_config != null ? 1 : 0
  
  assume_role_policy = data.aws_iam_policy_document.scylla_assume_role[0].json
  name_prefix = "scylla-db-"
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-scylla-role"
    }
  )
}

resource "aws_iam_role_policy_attachments_exclusive" "scylla_policy_attachement" {
  count = var.scylla_config != null ? 1 : 0
  
  role_name = aws_iam_role.scylla_role[0].name
  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
}





################################################################################
# EKS OIDC Provider for IRSA
################################################################################

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer
}



resource "aws_iam_openid_connect_provider" "eks_oidc" {
  count = var.is_primary_region ? 1 : 0
  
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-eks-oidc-provider"
  })
}

################################################################################
# Application IAM Roles (Moved from applications module)
################################################################################

# EBS CSI driver role eliminated - EKS Auto handles EBS CSI automatically

resource "aws_iam_policy" "s3_secrets_manager_iam_policy" {
  count       = var.is_primary_region ? 1 : 0
  name_prefix = "${local.name_prefix}-s3-policy-"
  path        = "/"
  description = "Policy to grant access to unreal cloud ddc bucket"

  policy = data.aws_iam_policy_document.unreal_cloud_ddc_policy.json
}

data "aws_iam_policy_document" "ddc_sa_assume_role" {
  count = var.is_primary_region ? 1 : 0
  
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks_oidc[0].arn]
    }
    
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.unreal_cloud_ddc_namespace}:${var.unreal_cloud_ddc_service_account_name}"]
    }
    
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# DDC service account role - uses EKS OIDC Provider
resource "aws_iam_role" "unreal_cloud_ddc_sa_iam_role" {
  count       = var.is_primary_region ? 1 : 0
  name_prefix = "${local.name_prefix}-sa-"

  assume_role_policy = data.aws_iam_policy_document.ddc_sa_assume_role[0].json
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-sa-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "unreal_cloud_ddc_sa_iam_role_s3_secrets_policy_attachment" {
  count      = var.is_primary_region ? 1 : 0
  role       = aws_iam_role.unreal_cloud_ddc_sa_iam_role[0].name
  policy_arn = aws_iam_policy.s3_secrets_manager_iam_policy[0].arn
}

################################################################################
# FluentBit IAM Role (EKS Auto + Direct Helm)
################################################################################
resource "aws_iam_role" "fluent_bit_role" {
  count       = var.is_primary_region ? 1 : 0
  name_prefix = "${local.name_prefix}-fluentbit-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks_oidc[0].arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-for-fluent-bit"
          "${replace(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-fluent-bit-role"
  })
}

resource "aws_iam_policy" "fluent_bit_policy" {
  count       = var.is_primary_region ? 1 : 0
  name_prefix = "${local.name_prefix}-fluentbit-policy-"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.region}:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fluent_bit_policy_attachment" {
  count      = var.is_primary_region ? 1 : 0
  role       = aws_iam_role.fluent_bit_role[0].name
  policy_arn = aws_iam_policy.fluent_bit_policy[0].arn
}

################################################################################
# AWS Load Balancer Controller IAM Role (EKS Auto + Direct Helm)
################################################################################
resource "aws_iam_role" "aws_load_balancer_controller_role" {
  count       = var.is_primary_region ? 1 : 0
  name_prefix = "${local.name_prefix}-lbc-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks_oidc[0].arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${replace(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-aws-load-balancer-controller-role"
  })
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_policy" {
  count      = var.is_primary_region ? 1 : 0
  role       = aws_iam_role.aws_load_balancer_controller_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_ec2_policy" {
  count      = var.is_primary_region ? 1 : 0
  role       = aws_iam_role.aws_load_balancer_controller_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

# Custom policy for AWS Load Balancer Controller security group management
resource "aws_iam_policy" "aws_load_balancer_controller_security_groups" {
  count       = var.is_primary_region ? 1 : 0
  name_prefix = "${local.name_prefix}-lbc-sg-"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_security_groups" {
  count      = var.is_primary_region ? 1 : 0
  role       = aws_iam_role.aws_load_balancer_controller_role[0].name
  policy_arn = aws_iam_policy.aws_load_balancer_controller_security_groups[0].arn
}

################################################################################
# Cert Manager IAM Role (EKS Auto + Direct Helm)
################################################################################
resource "aws_iam_role" "cert_manager_role" {
  count       = var.is_primary_region && var.enable_certificate_manager ? 1 : 0
  name_prefix = "${local.name_prefix}-cert-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks_oidc[0].arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:cert-manager:cert-manager"
          "${replace(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-cert-manager-role"
  })
}

resource "aws_iam_policy" "cert_manager_policy" {
  count       = var.is_primary_region && var.enable_certificate_manager ? 1 : 0
  name_prefix = "${local.name_prefix}-cert-policy-"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:GetChange",
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZonesByName",
          "route53:ListHostedZones"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cert_manager_policy_attachment" {
  count      = var.is_primary_region && var.enable_certificate_manager ? 1 : 0
  role       = aws_iam_role.cert_manager_role[0].name
  policy_arn = aws_iam_policy.cert_manager_policy[0].arn
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
