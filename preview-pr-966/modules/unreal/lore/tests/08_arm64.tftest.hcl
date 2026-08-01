mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
  mock_data "aws_region" {
    defaults = { name = "us-west-2" }
  }
  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-arm64mock"
    }
  }
}
mock_provider "tls" {}
mock_provider "random" {}

run "c8gd_arm64_plans_successfully" {
  command = plan

  variables {
    project_prefix        = "lore"
    environment           = "dev"
    vpc_id                = null
    vpc_cidr              = "10.0.0.0/16"
    availability_zones    = ["us-west-2a", "us-west-2b"]
    container_image       = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:arm64"
    allowed_ingress_cidrs = ["10.0.0.0/8"]
    instance_type         = "c8gd.8xlarge"
  }

  assert {
    condition     = module.compute.cpu_architecture == "ARM64"
    error_message = "c8gd instances should use ARM64 architecture"
  }
}

run "i4i_x86_plans_successfully" {
  command = plan

  variables {
    project_prefix        = "lore"
    environment           = "dev"
    vpc_id                = null
    vpc_cidr              = "10.0.0.0/16"
    availability_zones    = ["us-west-2a", "us-west-2b"]
    container_image       = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:latest"
    allowed_ingress_cidrs = ["10.0.0.0/8"]
    instance_type         = "i4i.xlarge"
  }

  assert {
    condition     = module.compute.cpu_architecture == "X86_64"
    error_message = "i4i instances should use X86_64 architecture"
  }
}
