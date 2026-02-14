# Test: Conditional Creation of Perforce Submodules
# This test validates that the Perforce wrapper module correctly creates or skips
# submodules (P4 Server, P4 Auth, P4 Code Review) based on provided configuration

# Mock AWS provider - no actual AWS API calls
# Note: Mock providers must be duplicated in each test file (Terraform limitation)
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      name = "us-east-1"
      id   = "us-east-1"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/test"
      user_id    = "AIDACKCEVSQ6C2EXAMPLE"
    }
  }

  mock_data "aws_elb_service_account" {
    defaults = {
      arn = "arn:aws:iam::127311923021:root"
      id  = "127311923021"
    }
  }

  mock_data "aws_ecs_cluster" {
    defaults = {
      arn                 = "arn:aws:ecs:us-east-1:123456789012:cluster/existing-cluster"
      id                  = "existing-cluster"
      name                = "existing-cluster"
      status              = "ACTIVE"
      pending_tasks_count = 0
      running_tasks_count = 0
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"*\",\"Resource\":\"*\"}]}"
    }
  }

  mock_data "aws_ami" {
    defaults = {
      id           = "ami-0123456789abcdef0"
      architecture = "x86_64"
      name         = "test-ami"
    }
  }
}

mock_provider "awscc" {}
mock_provider "random" {}
mock_provider "null" {}
mock_provider "local" {}
mock_provider "netapp-ontap" {}

# Test 1: No submodules - all configs null
run "no_submodules" {
  command = plan

  variables {
    vpc_id                                 = "vpc-12345678"
    create_shared_network_load_balancer     = false
    create_shared_application_load_balancer = false
    create_route53_private_hosted_zone      = false
    # All submodule configs are null (default)
  }

  assert {
    condition     = length(module.p4_server) == 0
    error_message = "P4 Server submodule should not be created when p4_server_config is null"
  }

  assert {
    condition     = length(module.p4_auth) == 0
    error_message = "P4 Auth submodule should not be created when p4_auth_config is null"
  }

  assert {
    condition     = length(module.p4_code_review) == 0
    error_message = "P4 Code Review submodule should not be created when p4_code_review_config is null"
  }

  assert {
    condition     = length(aws_ecs_cluster.perforce_web_services_cluster) == 0
    error_message = "ECS cluster should not be created when no web services are deployed"
  }
}

# Test 2: P4 Server only
run "p4_server_only" {
  command = plan

  variables {
    vpc_id                                 = "vpc-12345678"
    shared_nlb_subnets                     = ["subnet-111", "subnet-222", "subnet-333"]
    certificate_arn                        = "arn:aws:acm:us-east-1:123456789012:certificate/test-cert"
    create_shared_application_load_balancer = false
    create_route53_private_hosted_zone      = false

    p4_server_config = {
      fully_qualified_domain_name = "p4.test.internal"
      instance_subnet_id          = "subnet-111"
      p4_server_type              = "p4d_commit"
      depot_volume_size           = 128
      metadata_volume_size        = 32
      logs_volume_size            = 32
    }
  }

  assert {
    condition     = length(module.p4_server) == 1
    error_message = "P4 Server submodule should be created when p4_server_config is provided"
  }

  assert {
    condition     = length(module.p4_auth) == 0
    error_message = "P4 Auth submodule should not be created when p4_auth_config is null"
  }

  assert {
    condition     = length(module.p4_code_review) == 0
    error_message = "P4 Code Review submodule should not be created when p4_code_review_config is null"
  }

  assert {
    condition     = length(aws_ecs_cluster.perforce_web_services_cluster) == 0
    error_message = "ECS cluster should not be created when no web services (Auth/Code Review) are deployed"
  }
}

# Test 3: P4 Auth only
run "p4_auth_only" {
  command = plan

  variables {
    vpc_id                                = "vpc-12345678"
    shared_alb_subnets                    = ["subnet-111", "subnet-222", "subnet-333"]
    certificate_arn                       = "arn:aws:acm:us-east-1:123456789012:certificate/test-cert"
    create_shared_network_load_balancer   = false
    create_route53_private_hosted_zone    = false

    p4_auth_config = {
      fully_qualified_domain_name = "auth.test.internal"
      service_subnets             = ["subnet-111", "subnet-222", "subnet-333"]
    }
  }

  assert {
    condition     = length(module.p4_server) == 0
    error_message = "P4 Server submodule should not be created when p4_server_config is null"
  }

  assert {
    condition     = length(module.p4_auth) == 1
    error_message = "P4 Auth submodule should be created when p4_auth_config is provided"
  }

  assert {
    condition     = length(module.p4_code_review) == 0
    error_message = "P4 Code Review submodule should not be created when p4_code_review_config is null"
  }

  assert {
    condition     = length(aws_ecs_cluster.perforce_web_services_cluster) == 1
    error_message = "ECS cluster should be created when P4 Auth is deployed"
  }
}

# Test 4: P4 Code Review only (should fail - depends on P4 Server for credentials)
# This test validates that the module handles the dependency correctly
run "p4_code_review_only" {
  command = plan

  variables {
    vpc_id                                = "vpc-12345678"
    shared_alb_subnets                    = ["subnet-111", "subnet-222", "subnet-333"]
    certificate_arn                       = "arn:aws:acm:us-east-1:123456789012:certificate/test-cert"
    create_shared_network_load_balancer   = false
    create_route53_private_hosted_zone    = false

    p4_code_review_config = {
      fully_qualified_domain_name = "swarm.test.internal"
      service_subnets             = ["subnet-111", "subnet-222", "subnet-333"]
    }
  }

  # Note: This will likely fail during apply because Code Review needs P4 Server credentials
  # But the plan should succeed, showing the module allows this configuration
  assert {
    condition     = length(module.p4_server) == 0
    error_message = "P4 Server submodule should not be created when p4_server_config is null"
  }

  assert {
    condition     = length(module.p4_auth) == 0
    error_message = "P4 Auth submodule should not be created when p4_auth_config is null"
  }

  assert {
    condition     = length(module.p4_code_review) == 1
    error_message = "P4 Code Review submodule should be created when p4_code_review_config is provided"
  }

  assert {
    condition     = length(aws_ecs_cluster.perforce_web_services_cluster) == 1
    error_message = "ECS cluster should be created when P4 Code Review is deployed"
  }
}

# Test 5: P4 Server + P4 Auth
run "server_and_auth" {
  command = plan

  variables {
    vpc_id                             = "vpc-12345678"
    shared_nlb_subnets                 = ["subnet-111", "subnet-222", "subnet-333"]
    shared_alb_subnets                 = ["subnet-111", "subnet-222", "subnet-333"]
    certificate_arn                    = "arn:aws:acm:us-east-1:123456789012:certificate/test-cert"
    create_route53_private_hosted_zone = false

    p4_server_config = {
      fully_qualified_domain_name = "p4.test.internal"
      instance_subnet_id          = "subnet-111"
      p4_server_type              = "p4d_commit"
      depot_volume_size           = 128
      metadata_volume_size        = 32
      logs_volume_size            = 32
    }

    p4_auth_config = {
      fully_qualified_domain_name = "auth.test.internal"
      service_subnets             = ["subnet-111", "subnet-222", "subnet-333"]
    }
  }

  assert {
    condition     = length(module.p4_server) == 1
    error_message = "P4 Server submodule should be created when p4_server_config is provided"
  }

  assert {
    condition     = length(module.p4_auth) == 1
    error_message = "P4 Auth submodule should be created when p4_auth_config is provided"
  }

  assert {
    condition     = length(module.p4_code_review) == 0
    error_message = "P4 Code Review submodule should not be created when p4_code_review_config is null"
  }

  assert {
    condition     = length(aws_ecs_cluster.perforce_web_services_cluster) == 1
    error_message = "ECS cluster should be created when P4 Auth is deployed"
  }
}

# Test 6: P4 Server + P4 Code Review (typical deployment without SSO)
run "server_and_code_review" {
  command = plan

  variables {
    vpc_id                             = "vpc-12345678"
    shared_nlb_subnets                 = ["subnet-111", "subnet-222", "subnet-333"]
    shared_alb_subnets                 = ["subnet-111", "subnet-222", "subnet-333"]
    certificate_arn                    = "arn:aws:acm:us-east-1:123456789012:certificate/test-cert"
    create_route53_private_hosted_zone = false

    p4_server_config = {
      fully_qualified_domain_name = "p4.test.internal"
      instance_subnet_id          = "subnet-111"
      p4_server_type              = "p4d_commit"
      depot_volume_size           = 128
      metadata_volume_size        = 32
      logs_volume_size            = 32
    }

    p4_code_review_config = {
      fully_qualified_domain_name = "swarm.test.internal"
      service_subnets             = ["subnet-111", "subnet-222", "subnet-333"]
    }
  }

  assert {
    condition     = length(module.p4_server) == 1
    error_message = "P4 Server submodule should be created when p4_server_config is provided"
  }

  assert {
    condition     = length(module.p4_auth) == 0
    error_message = "P4 Auth submodule should not be created when p4_auth_config is null"
  }

  assert {
    condition     = length(module.p4_code_review) == 1
    error_message = "P4 Code Review submodule should be created when p4_code_review_config is provided"
  }

  assert {
    condition     = length(aws_ecs_cluster.perforce_web_services_cluster) == 1
    error_message = "ECS cluster should be created when P4 Code Review is deployed"
  }
}

# Test 7: Full stack - all three submodules
run "full_stack" {
  command = plan

  variables {
    vpc_id             = "vpc-12345678"
    shared_nlb_subnets = ["subnet-111", "subnet-222", "subnet-333"]
    shared_alb_subnets = ["subnet-111", "subnet-222", "subnet-333"]
    certificate_arn    = "arn:aws:acm:us-east-1:123456789012:certificate/test-cert"

    create_route53_private_hosted_zone = true
    route53_private_hosted_zone_name   = "perforce.internal"

    p4_server_config = {
      fully_qualified_domain_name = "perforce.internal"
      instance_subnet_id          = "subnet-111"
      p4_server_type              = "p4d_commit"
      depot_volume_size           = 128
      metadata_volume_size        = 32
      logs_volume_size            = 32
    }

    p4_auth_config = {
      fully_qualified_domain_name = "auth.perforce.internal"
      service_subnets             = ["subnet-111", "subnet-222", "subnet-333"]
    }

    p4_code_review_config = {
      fully_qualified_domain_name = "swarm.perforce.internal"
      service_subnets             = ["subnet-111", "subnet-222", "subnet-333"]
      enable_sso                  = true
    }
  }

  assert {
    condition     = length(module.p4_server) == 1
    error_message = "P4 Server submodule should be created when p4_server_config is provided"
  }

  assert {
    condition     = length(module.p4_auth) == 1
    error_message = "P4 Auth submodule should be created when p4_auth_config is provided"
  }

  assert {
    condition     = length(module.p4_code_review) == 1
    error_message = "P4 Code Review submodule should be created when p4_code_review_config is provided"
  }

  assert {
    condition     = length(aws_ecs_cluster.perforce_web_services_cluster) == 1
    error_message = "ECS cluster should be created when web services are deployed"
  }

  assert {
    condition     = length(aws_route53_zone.perforce_private_hosted_zone) == 1
    error_message = "Route53 private hosted zone should be created when enabled"
  }
}

# Test 8: Full stack with existing ECS cluster
run "full_stack_existing_ecs_cluster" {
  command = plan

  variables {
    vpc_id                             = "vpc-12345678"
    shared_nlb_subnets                 = ["subnet-111", "subnet-222", "subnet-333"]
    shared_alb_subnets                 = ["subnet-111", "subnet-222", "subnet-333"]
    certificate_arn                    = "arn:aws:acm:us-east-1:123456789012:certificate/test-cert"
    existing_ecs_cluster_name          = "my-existing-cluster"
    create_route53_private_hosted_zone = false

    p4_server_config = {
      fully_qualified_domain_name = "p4.test.internal"
      instance_subnet_id          = "subnet-111"
      p4_server_type              = "p4d_commit"
      depot_volume_size           = 128
      metadata_volume_size        = 32
      logs_volume_size            = 32
    }

    p4_auth_config = {
      fully_qualified_domain_name = "auth.test.internal"
      service_subnets             = ["subnet-111", "subnet-222", "subnet-333"]
    }

    p4_code_review_config = {
      fully_qualified_domain_name = "swarm.test.internal"
      service_subnets             = ["subnet-111", "subnet-222", "subnet-333"]
    }
  }

  assert {
    condition     = length(module.p4_server) == 1
    error_message = "P4 Server submodule should be created when p4_server_config is provided"
  }

  assert {
    condition     = length(module.p4_auth) == 1
    error_message = "P4 Auth submodule should be created when p4_auth_config is provided"
  }

  assert {
    condition     = length(module.p4_code_review) == 1
    error_message = "P4 Code Review submodule should be created when p4_code_review_config is provided"
  }

  assert {
    condition     = length(aws_ecs_cluster.perforce_web_services_cluster) == 0
    error_message = "ECS cluster should not be created when existing_ecs_cluster_name is provided"
  }

  assert {
    condition     = local.create_shared_ecs_cluster == false
    error_message = "create_shared_ecs_cluster local should be false when existing cluster is provided"
  }
}
