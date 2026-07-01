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
}
mock_provider "tls" {}
mock_provider "random" {}

run "creates_vpc_when_vpc_id_is_null" {
  command = plan

  variables {
    project_prefix        = "lore"
    environment           = "dev"
    vpc_id                = null
    vpc_cidr              = "10.0.0.0/16"
    availability_zones    = ["us-east-1a", "us-east-1b"]
    container_image       = "placeholder:latest"
    allowed_ingress_cidrs = ["10.0.0.0/8"]
  }

  assert {
    condition     = length(module.vpc) == 1
    error_message = "VPC module should be created when vpc_id is null"
  }
}

run "skips_vpc_when_vpc_id_provided" {
  command = plan

  variables {
    project_prefix        = "lore"
    environment           = "dev"
    vpc_id                = "vpc-12345678"
    private_subnet_ids    = ["subnet-aaa", "subnet-bbb"]
    public_subnet_ids     = ["subnet-ccc", "subnet-ddd"]
    container_image       = "placeholder:latest"
    allowed_ingress_cidrs = ["10.0.0.0/8"]
  }

  assert {
    condition     = length(module.vpc) == 0
    error_message = "VPC module should be skipped when vpc_id is provided"
  }
}

run "name_prefix_uses_project_and_environment" {
  command = plan

  variables {
    project_prefix        = "mystudio"
    environment           = "prod"
    vpc_id                = null
    vpc_cidr              = "10.0.0.0/16"
    availability_zones    = ["us-east-1a", "us-east-1b"]
    container_image       = "placeholder:latest"
    allowed_ingress_cidrs = ["10.0.0.0/8"]
  }

  assert {
    condition     = local.name_prefix == "mystudio-prod"
    error_message = "name_prefix should be project_prefix-environment"
  }
}
