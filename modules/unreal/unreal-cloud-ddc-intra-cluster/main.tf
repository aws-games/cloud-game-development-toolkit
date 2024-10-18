locals {
  partition = data.aws_partition.current.partition
}

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

################################################################################
# Cert Manager
################################################################################

module "cert_manager" {
  source = "git::https://github.com/aws-ia/terraform-aws-eks-blueprints-addon.git?ref=327207ad17f3069fdd0a76c14d3e07936eff4582"

  name             = "cert-manager"
  description      = "A Helm chart to deploy cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  chart            = "cert-manager"
  chart_version    = "v1.14.3"
  repository       = "https://charts.jetstack.io"
  values           = []

  create         = true
  create_release = true

  postrender = []
  set = concat([
    {
      name  = "installCRDs"
      value = true
    },
    {
      name  = "serviceAccount.name"
      value = "cert-manager"
    }
    ]
  )

  # IAM role for service account (IRSA)
  set_irsa_names       = ["serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"]
  create_role          = true
  role_name            = "cert-manager"
  role_name_use_prefix = true
  role_path            = "/"
  role_description     = "IRSA for cert-manger project"

  allow_self_assume_role  = true
  create_policy           = true
  source_policy_documents = data.aws_iam_policy_document.cert_manager[*].json
  policy_name             = "cert-manager-policy"
  policy_name_use_prefix  = true
  policy_description      = "IAM Policy for cert-manager"

  oidc_providers = {
    this = {
      provider_arn    = var.oidc_provider_arn
      service_account = "cert-manager"
    }
  }

}

module "eks_blueprints_all_other_addons" {
  #checkov:skip=CKV_TF_1:Ensure Terraform module sources use a commit hash
  #checkov:skip=CKV_AWS_109:Ensure IAM policies does not allow permissions management / resource exposure without constraints
  #checkov:skip=CKV_AWS_111:Ensure IAM policies does not allow write access without constraints
  #checkov:skip=CKV_AWS_356:Ensure no IAM policies documents allow "*" as a statement's resource for restrictable actions
  source = "git::https://github.com/aws-ia/terraform-aws-eks-blueprints-addons.git?ref=a9963f4a0e168f73adb033be594ac35868696a91"
  depends_on = [
    module.cert_manager
  ]

  eks_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
  }


  cluster_name      = data.aws_eks_cluster.unreal_cloud_ddc_cluster.name
  cluster_endpoint  = data.aws_eks_cluster.unreal_cloud_ddc_cluster.endpoint
  cluster_version   = data.aws_eks_cluster.unreal_cloud_ddc_cluster.version
  oidc_provider_arn = var.oidc_provider_arn

  enable_aws_load_balancer_controller   = true
  enable_external_secrets               = true
  enable_aws_cloudwatch_metrics         = true
  external_secrets_secrets_manager_arns = var.external_secrets_secret_manager_arn_list
  enable_external_dns                   = true

  tags = {
    Environment = var.cluster_name
  }
}

resource "kubernetes_namespace" "unreal_cloud_ddc" {
  depends_on = [module.eks_blueprints_all_other_addons]
  metadata {
    name = var.unreal_cloud_ddc_namespace
  }
}

resource "kubernetes_service_account" "unreal_cloud_ddc_service_account" {
  depends_on = [kubernetes_namespace.unreal_cloud_ddc]
  metadata {
    name        = "${var.unreal_cloud_ddc_namespace}-sa"
    namespace   = var.unreal_cloud_ddc_namespace
    labels      = { aws-usage : "application" }
    annotations = { "eks.amazonaws.com/role-arn" : module.eks_service_account_iam_role.iam_role_arn }
  }
  automount_service_account_token = true
}



################################################################################
# Helm
################################################################################

resource "helm_release" "unreal_cloud_ddc" {
  name       = "unreal-cloud-ddc"
  chart      = "unreal-cloud-ddc"
  repository = "oci://ghcr.io/epicgames"
  namespace  = var.unreal_cloud_ddc_namespace
  version    = "1.1.1+helm"
  depends_on = [
    kubernetes_service_account.unreal_cloud_ddc_service_account,
    kubernetes_namespace.unreal_cloud_ddc
  ]

  values = var.unreal_cloud_ddc_helm_values
}
