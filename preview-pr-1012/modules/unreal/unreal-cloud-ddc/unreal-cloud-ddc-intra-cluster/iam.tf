################################################################################
# IAM Roles & Policies
################################################################################

resource "aws_iam_role" "ebs_csi_iam_role" {
  name_prefix = "${local.name_prefix}-ebs-csi-sa-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid    = ""
      Effect = "Allow",
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.oidc_provider.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${data.aws_iam_openid_connect_provider.oidc_provider.arn}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${data.aws_iam_openid_connect_provider.oidc_provider.arn}:aud" = "sts.amazonaws.com"
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
  depends_on = [data.aws_s3_bucket.unreal_cloud_ddc_bucket]

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
        Federated = data.aws_iam_openid_connect_provider.oidc_provider.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(data.aws_iam_openid_connect_provider.oidc_provider.arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:${var.unreal_cloud_ddc_namespace}:${var.unreal_cloud_ddc_namespace}-sa"
          "${replace(data.aws_iam_openid_connect_provider.oidc_provider.arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
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
      data.aws_s3_bucket.unreal_cloud_ddc_bucket.arn,
      "${data.aws_s3_bucket.unreal_cloud_ddc_bucket.arn}/*"
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
