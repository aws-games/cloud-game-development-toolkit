################################################################################
# EKS Addons (Moved from applications module to fix circular dependency)
################################################################################

module "eks_blueprints_addons" {
  #checkov:skip=CKV_TF_1:Using forked version with AWS Provider v6 region parameter support
  source = "git::https://github.com/novekm/terraform-aws-eks-blueprints-addons.git?ref=main"

  # EKS Addons configuration (keep existing functionality)
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

  # Cluster configuration
  cluster_name      = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  cluster_endpoint  = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.endpoint
  cluster_version   = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.version
  oidc_provider_arn = aws_iam_openid_connect_provider.unreal_cloud_ddc_oidc_provider.arn
  
  # AWS Provider v6 region parameter support
  region = var.region

  # KEY CHANGE: Disable load balancer controller (FIXES circular dependency)
  enable_aws_load_balancer_controller = false
  
  # Keep existing addons
  enable_aws_cloudwatch_metrics = true
  enable_cert_manager           = var.enable_certificate_manager
  cert_manager_route53_hosted_zone_arns = var.certificate_manager_hosted_zone_arn

  tags = {
    Environment = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  }

  depends_on = [
    aws_eks_cluster.unreal_cloud_ddc_eks_cluster,
    aws_eks_node_group.system_node_group
  ]
}

################################################################################
# Kubernetes Resources (Moved from applications module)
################################################################################

resource "kubernetes_namespace" "unreal_cloud_ddc" {
  depends_on = [module.eks_blueprints_addons]
  
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