mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
  mock_data "aws_region" {
    defaults = {
      name = "us-east-1"
    }
  }
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b"]
    }
  }
  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-12345678"
    }
  }
}
mock_provider "tls" {}
mock_provider "random" {}
mock_provider "archive" {}

# Validates that the root module exposes outputs required by operational
# tooling (deploy-validate-runbook.md, test-client, scripts).
#
# Strategy: assert on module.compute and module.networking outputs that
# are known at plan time (derived from name_prefix, not AWS API calls).
# If a sub-module output is removed, the root output breaks, and this
# test catches it.

run "root_module_exposes_operational_outputs" {
  command = plan

  variables {
    project_prefix        = "lore"
    environment           = "dev"
    container_image       = "123456789012.dkr.ecr.us-east-1.amazonaws.com/loreserver:latest"
    allowed_ingress_cidrs = ["10.0.0.0/8"]
  }

  # ECS cluster name is derived from name_prefix (known at plan time)
  assert {
    condition     = output.ecs_cluster_name == "lore-dev-cluster"
    error_message = "ecs_cluster_name output must be exposed and match expected value"
  }

  # VPC is created (module count = 1)
  assert {
    condition     = length(module.vpc) == 1
    error_message = "VPC module must be created for output test"
  }
}
