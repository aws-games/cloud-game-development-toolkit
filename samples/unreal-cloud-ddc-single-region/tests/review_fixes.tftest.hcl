# Offline plan tests for the sample's root variables. All providers are mocked.

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
  mock_data "aws_ami" {
    defaults = { id = "ami-12345678" }
  }
  mock_data "aws_availability_zones" {
    defaults = { names = ["us-east-1a", "us-east-1b"] }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_data "aws_eks_cluster" {
    defaults = {
      endpoint              = "https://ABC.gr7.us-east-1.eks.amazonaws.com"
      certificate_authority = [{ data = "Y2E=" }]
      identity              = [{ oidc = [{ issuer = "https://oidc.eks.us-east-1.amazonaws.com/id/ABC" }] }]
    }
  }
  mock_resource "aws_eks_cluster" {
    defaults = {
      endpoint              = "https://ABC.gr7.us-east-1.eks.amazonaws.com"
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
  mock_resource "aws_iam_openid_connect_provider" {
    defaults = { arn = "arn:aws:iam::123456789012:oidc-provider/mock" }
  }
  mock_resource "aws_instance" {
    defaults = { private_ip = "10.0.0.10" }
  }
}
mock_provider "awscc" {}

# The cert's validation records are only known after apply; pin them for plan.
override_resource {
  target          = aws_acm_certificate.scylla_monitoring
  override_during = plan
  values = {
    arn = "arn:aws:acm:us-east-1:123456789012:certificate/mock"
    domain_validation_options = [{
      domain_name           = "monitoring.unreal-cloud-ddc.example.com"
      resource_record_name  = "_x.monitoring.unreal-cloud-ddc.example.com."
      resource_record_value = "_y.acm-validations.aws."
      resource_record_type  = "CNAME"
    }]
  }
}
mock_provider "http" {
  mock_data "http" {
    defaults = { response_body = "198.51.100.7\n" }
  }
}
mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "random" {}
mock_provider "tls" {}

variables {
  github_credential_arn           = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ecr-pullthroughcache/gh"
  route53_public_hosted_zone_name = "example.com"
}

run "defaults" {
  command = plan
  assert {
    condition     = var.ebs_csi_use_pod_identity == true && var.eks_public_access == true
    error_message = "Pod Identity and public access should both default to true"
  }
}

# Before the fix this failed with "Value for undeclared variable".
run "irsa_and_closed_endpoint_accepted" {
  command = plan
  variables {
    ebs_csi_use_pod_identity = false
    eks_public_access        = false
    eks_api_local_port       = 9443
  }
  assert {
    condition     = var.ebs_csi_use_pod_identity == false && var.eks_public_access == false
    error_message = "root variables should accept the README overrides"
  }
}
