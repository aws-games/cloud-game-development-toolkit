# Offline plan tests for the infra module. All providers are mocked.

mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_data "aws_ami" {
    defaults = { id = "ami-12345678" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
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
}
mock_provider "tls" {}

variables {
  region                                       = "us-east-1"
  vpc_id                                       = "vpc-123"
  eks_node_group_subnets                       = ["subnet-a", "subnet-b"]
  scylla_subnets                               = ["subnet-a", "subnet-b"]
  monitoring_application_load_balancer_subnets = ["subnet-c", "subnet-d"]
  alb_certificate_arn                          = "arn:aws:acm:us-east-1:123456789012:certificate/mock"
}

run "scylla_ami_default_is_current" {
  command = plan
  assert {
    condition     = var.scylla_ami_name == "ScyllaDB 2026.3.1"
    error_message = "default scylla_ami_name should be ScyllaDB 2026.3.1"
  }
}

run "public_endpoint_open" {
  command = plan
  variables {
    eks_cluster_public_access               = true
    eks_cluster_public_endpoint_access_cidr = ["198.51.100.7/32"]
  }
  assert {
    condition     = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.vpc_config[0].endpoint_public_access == true
    error_message = "public endpoint should be enabled"
  }
  assert {
    condition     = length(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.vpc_config[0].public_access_cidrs) == 1 && contains(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.vpc_config[0].public_access_cidrs, "198.51.100.7/32")
    error_message = "public CIDRs should be passed through"
  }
}

# Mirrors what the sample sends when eks_public_access = false.
run "public_endpoint_closed" {
  command = plan
  variables {
    eks_cluster_public_access               = false
    eks_cluster_public_endpoint_access_cidr = null
  }
  assert {
    condition     = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.vpc_config[0].endpoint_public_access == false
    error_message = "public endpoint should be disabled"
  }
  assert {
    condition     = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.vpc_config[0].endpoint_private_access == true
    error_message = "private endpoint must stay enabled"
  }
}
