module "eks_blueprints_all_other_addons" {
  #checkov:skip=CKV_TF_1:Upstream commit hash not being checked. This will be broken out in the future.
  #checkov:skip=CKV_AWS_356:Upstream requirement for Load Balancer Controller
  #checkov:skip=CKV_AWS_111:Upstream requirement for Load Balancer Controller
  source = "git::https://github.com/aws-ia/terraform-aws-eks-blueprints-addons.git?ref=a9963f4a0e168f73adb033be594ac35868696a91"

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
      service_account_role_arn = aws_iam_role.ebs_csi_iam_role.arn
    }
  }


  cluster_name      = data.aws_eks_cluster.unreal_cloud_ddc_cluster.name
  cluster_endpoint  = data.aws_eks_cluster.unreal_cloud_ddc_cluster.endpoint
  cluster_version   = data.aws_eks_cluster.unreal_cloud_ddc_cluster.version
  oidc_provider_arn = data.aws_iam_openid_connect_provider.oidc_provider.arn

  enable_aws_load_balancer_controller = true
  enable_aws_cloudwatch_metrics       = true
  enable_cert_manager                 = var.enable_certificate_manager

  cert_manager_route53_hosted_zone_arns = var.certificate_manager_hosted_zone_arn


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
    name        = var.unreal_cloud_ddc_service_account_name
    namespace   = var.unreal_cloud_ddc_namespace
    labels      = { aws-usage : "application" }
    annotations = { "eks.amazonaws.com/role-arn" : aws_iam_role.unreal_cloud_ddc_sa_iam_role.arn }
  }
  automount_service_account_token = true
}



################################################################################
# Helm
################################################################################
resource "aws_ecr_pull_through_cache_rule" "unreal_cloud_ddc_ecr_pull_through_cache_rule" {
  ecr_repository_prefix = "github"
  upstream_registry_url = "ghcr.io"
  credential_arn        = var.ghcr_credentials_secret_manager_arn
}

resource "helm_release" "unreal_cloud_ddc" {
  name         = "unreal-cloud-ddc"
  chart        = "unreal-cloud-ddc"
  repository   = "oci://${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/github/epicgames"
  namespace    = var.unreal_cloud_ddc_namespace
  version      = "${var.unreal_cloud_ddc_version}+helm"
  reset_values = true
  depends_on = [
    kubernetes_service_account.unreal_cloud_ddc_service_account,
    kubernetes_namespace.unreal_cloud_ddc,
    aws_ecr_pull_through_cache_rule.unreal_cloud_ddc_ecr_pull_through_cache_rule
  ]
  values = var.unreal_cloud_ddc_helm_values
}
