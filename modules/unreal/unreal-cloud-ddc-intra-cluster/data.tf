data "aws_partition" "current" {}

data "aws_eks_cluster" "unreal_cloud_ddc_cluster" {
  name = var.cluster_name
}

data "aws_s3_bucket" "unreal_cloud_ddc_bucket" {
  bucket = var.s3_bucket_id
}

data "aws_iam_policy_document" "cert_manager" {


  statement {
    actions   = ["route53:GetChange", ]
    resources = ["arn:${local.partition}:route53:::change/*"]
  }

  statement {
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
    ]
    resources = [
      "arn:${local.partition}:route53:::*",
      "arn:${local.partition}:route53:::change/*"
    ]
  }

  statement {
    actions   = ["route53:ListHostedZonesByName"]
    resources = ["*"]
  }
}
