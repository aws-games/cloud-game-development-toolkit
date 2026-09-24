################################################################################
# EBS CSI Driver via EKS Pod Identity
################################################################################
# These resources are only created when var.ebs_csi_use_pod_identity is true.
# In that mode the EBS CSI driver addon is managed natively (rather than via the
# blueprints module) so it can be paired with a Pod Identity association. Pod
# Identity uses eks-auth:AssumeRoleForPodIdentity with the pods.eks.amazonaws.com
# trust principal, bypassing Org RCP/SCP denies on sts:AssumeRoleWithWebIdentity.

resource "aws_eks_pod_identity_association" "ebs_csi" {
  count           = var.ebs_csi_use_pod_identity ? 1 : 0
  cluster_name    = data.aws_eks_cluster.unreal_cloud_ddc_cluster.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi_iam_role.arn
  depends_on      = [module.eks_blueprints_all_other_addons]
}

resource "aws_eks_addon" "ebs_csi" {
  count                       = var.ebs_csi_use_pod_identity ? 1 : 0
  cluster_name                = data.aws_eks_cluster.unreal_cloud_ddc_cluster.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_pod_identity_association.ebs_csi, module.eks_blueprints_all_other_addons]
  tags                        = var.tags
}
