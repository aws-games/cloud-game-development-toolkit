data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "unreal_cloud_ddc_cluster" {
  name = var.cluster_name
}

data "aws_s3_bucket" "unreal_cloud_ddc_bucket" {
  bucket = var.s3_bucket_id
}

data "aws_iam_openid_connect_provider" "oidc_provider" {
  arn = var.oidc_provider_arn
}
