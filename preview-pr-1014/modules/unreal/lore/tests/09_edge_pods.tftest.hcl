mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
  mock_data "aws_region" {
    defaults = { name = "us-west-2" }
  }
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-west-2a", "us-west-2b"]
    }
  }
  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-arm64mock"
    }
  }
}
mock_provider "tls" {}
mock_provider "random" {}
mock_provider "archive" {}

run "edge_pods_service_discovery_plans" {
  command = plan

  variables {
    project_prefix        = "lore"
    environment           = "dev"
    container_image       = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:arm64"
    allowed_ingress_cidrs = ["10.0.0.0/8"]
    instance_type         = "c8gd.8xlarge"
  }

  assert {
    condition     = output.write_tier_discovery_dns == "write-tier.lore-dev.internal"
    error_message = "write_tier_discovery_dns must resolve to Cloud Map DNS name"
  }
}
