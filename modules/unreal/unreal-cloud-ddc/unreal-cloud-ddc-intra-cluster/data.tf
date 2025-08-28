data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "unreal_cloud_ddc_cluster" {
  region = var.region
  name   = var.cluster_name
}

data "aws_s3_bucket" "unreal_cloud_ddc_bucket" {
  region = var.region
  bucket = var.s3_bucket_id
}

data "aws_iam_openid_connect_provider" "oidc_provider" {
  arn = var.cluster_oidc_provider_arn
}

data "aws_lb" "unreal_cloud_ddc_load_balancer" {
  depends_on = [helm_release.unreal_cloud_ddc_initialization]
  name       = "cgd-unreal-cloud-ddc"
  region     = var.region
}
