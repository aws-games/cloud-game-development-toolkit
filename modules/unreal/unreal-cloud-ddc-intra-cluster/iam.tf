################################################################################
# IAM Roles & Policies
################################################################################

module "eks_service_account_iam_role" {
  #checkov:skip=CKV_AWS_111:Ensure IAM policies does not allow write access without constraints
  #checkov:skip=CKV_AWS_356:Ensure no IAM policies documents allow "*" as a statement's resource for restrictable actions
  source     = "git::https://github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-assumable-role-with-oidc?ref=ccb4f252cc340d85fd70a8a1fb1cae496a698c1f"
  depends_on = [data.aws_eks_cluster.unreal_cloud_ddc_cluster]

  create_role      = true
  role_name_prefix = "unreal-ddc-sa-role-"


  tags = {
    Role = "eks-unreal-cloud-ddc-role"
  }
  provider_url  = data.aws_eks_cluster.unreal_cloud_ddc_cluster.identity[0].oidc[0].issuer
  provider_urls = [data.aws_eks_cluster.unreal_cloud_ddc_cluster.identity[0].oidc[0].issuer]

  role_policy_arns = [
    aws_iam_policy.s3_iam_policy.arn,
    aws_iam_policy.secrets_iam_policy.arn
  ]

  oidc_fully_qualified_subjects = ["system:serviceaccount:${var.unreal_cloud_ddc_namespace}:${var.unreal_cloud_ddc_namespace}-sa"]
}

module "ebs_csi_irsa_role" {
  #checkov:skip=CKV_AWS_109:Ensure IAM policies does not allow permissions management / resource exposure without constraints
  #checkov:skip=CKV_AWS_111:Ensure IAM policies does not allow write access without constraints
  #checkov:skip=CKV_AWS_356:Ensure no IAM policies documents allow "*" as a statement's resource for restrictable actions
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-role-for-service-accounts-eks?ref=ccb4f252cc340d85fd70a8a1fb1cae496a698c1f"

  role_name_prefix      = "ebs-csi-role-"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_policy" "secrets_iam_policy" {
  name_prefix = "unreal-ddc-secrets-policy-"
  path        = "/"
  description = "Policy to grant access to oidc provider secrets"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "secretsmanager:GetSecretValue",
        ],
        "Effect" : "Allow",
        "Resource" : [
          var.oidc_credentials_secret_manager_arn
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "s3_iam_policy" {
  depends_on = [data.aws_s3_bucket.unreal_cloud_ddc_bucket]

  name_prefix = "unreal-ddc-s3-policy-"
  path        = "/"
  description = "Policy to grant access to unreal cloud ddc bucket"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:List*",
        ],
        "Effect" : "Allow",
        "Resource" : [
          data.aws_s3_bucket.unreal_cloud_ddc_bucket.arn,
          "${data.aws_s3_bucket.unreal_cloud_ddc_bucket.arn}/*"
        ]
      }
    ]
  })
}
