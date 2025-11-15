# IP check for security group configuration
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

# EKS cluster authentication
data "aws_eks_cluster_auth" "main" {
  name = module.unreal_cloud_ddc.ddc_infra != null ? module.unreal_cloud_ddc.ddc_infra.cluster_name : ""
}