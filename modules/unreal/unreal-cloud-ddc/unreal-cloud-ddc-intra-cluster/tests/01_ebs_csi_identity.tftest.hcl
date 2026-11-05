# Offline plan tests for the EBS CSI identity switch. All providers are mocked.

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-1", name = "us-east-1" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws", dns_suffix = "amazonaws.com" }
  }
  mock_data "aws_eks_addon_version" {
    defaults = { version = "v1.0.0-eksbuild.1" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_data "aws_eks_cluster" {
    defaults = {
      name                  = "cgd-unreal-cloud-ddc-cluster"
      endpoint              = "https://ABC.gr7.us-east-1.eks.amazonaws.com"
      version               = "1.37"
      certificate_authority = [{ data = "Y2E=" }]
      identity              = [{ oidc = [{ issuer = "https://oidc.eks.us-east-1.amazonaws.com/id/ABC" }] }]
    }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock" }
  }
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::123456789012:policy/mock" }
  }
}
mock_provider "kubernetes" {}
mock_provider "helm" {}

variables {
  cluster_name                        = "cgd-unreal-cloud-ddc-cluster"
  cluster_oidc_provider_arn           = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/ABC"
  s3_bucket_id                        = "ddc-bucket"
  ghcr_credentials_secret_manager_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ecr-pullthroughcache/gh"
}

run "pod_identity" {
  command = plan
  variables {
    ebs_csi_use_pod_identity = true
  }
  assert {
    condition     = length(aws_eks_pod_identity_association.ebs_csi) == 1 && length(aws_eks_addon.ebs_csi) == 1
    error_message = "Pod Identity mode should plan the association and native addon"
  }
  assert {
    condition     = aws_eks_pod_identity_association.ebs_csi[0].service_account == "ebs-csi-controller-sa"
    error_message = "association should target ebs-csi-controller-sa"
  }
}

run "irsa" {
  command = plan
  variables {
    ebs_csi_use_pod_identity = false
  }
  assert {
    condition     = length(aws_eks_pod_identity_association.ebs_csi) == 0 && length(aws_eks_addon.ebs_csi) == 0
    error_message = "IRSA mode should not plan Pod Identity resources"
  }
}
