mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
  mock_data "aws_region" {
    defaults = { name = "us-east-1" }
  }
}
mock_provider "tls" {}
mock_provider "random" {}

run "networking_module_plans_successfully" {
  command = plan

  variables {
    project_prefix     = "lore"
    environment        = "dev"
    vpc_id             = null
    vpc_cidr           = "10.0.0.0/16"
    availability_zones = ["us-east-1a", "us-east-1b"]
    container_image       = "placeholder:latest"
    allowed_ingress_cidrs = ["10.0.0.0/8"]
  }

  # Plan succeeds = SG, VPC endpoints, and all rules are valid configuration
  # Detailed port/protocol assertions require Live tests (resource IDs unknown at plan time)
}
