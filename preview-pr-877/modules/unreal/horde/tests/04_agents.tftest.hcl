# Test: Build agent configurations
# This test validates build agent autoscaling group configurations:
# - Single agent pool
# - Multiple agent pools with different configurations
# - No agents configured

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
      arn                 = "arn:aws:ecs:us-east-1:123456789012:cluster/test"
      id                  = "test"
      name                = "test"
      status              = "ACTIVE"
      pending_tasks_count = 0
      running_tasks_count = 0
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = <<-EOT
        {
          "Version": "2012-10-17",
          "Statement": [{
            "Effect": "Allow",
            "Action": "*",
            "Resource": "*"
          }]
        }
      EOT
    }
  }
}

# Mock random provider
mock_provider "random" {}

# Test: Single agent pool configuration
run "unit_test_single_agent_pool" {
  command = plan

  variables {
    vpc_id                            = "vpc-12345678"
    unreal_horde_service_subnets      = ["subnet-123", "subnet-456"]
    unreal_horde_internal_alb_subnets = ["subnet-123", "subnet-456"]
    certificate_arn                   = "arn:aws:acm:us-east-1:123456789012:certificate/test"
    fully_qualified_domain_name       = "horde.example.com"

    create_external_alb = false
    create_internal_alb = true
    name                = "horde-ag"

    # Single agent pool
    agents = {
      "default" = {
        ami             = "ami-12345678"
        instance_type   = "c5.2xlarge"
        horde_pool_name = "default-pool"
        block_device_mappings = [
          {
            device_name = "/dev/xvda"
            ebs = {
              volume_size = 100
            }
          }
        ]
        min_size = 1
        max_size = 5
      }
    }

    enable_new_agents_by_default = true
  }

  assert {
    condition     = length(aws_autoscaling_group.unreal_horde_agent_asg) == 1
    error_message = "Should create 1 autoscaling group for single agent pool"
  }

  assert {
    condition     = aws_autoscaling_group.unreal_horde_agent_asg["default"].min_size == 1
    error_message = "ASG should have min_size of 1 as configured"
  }

  assert {
    condition     = aws_autoscaling_group.unreal_horde_agent_asg["default"].max_size == 5
    error_message = "ASG should have max_size of 5 as configured"
  }

  assert {
    condition     = length(aws_launch_template.unreal_horde_agent_template) == 1
    error_message = "Should create 1 launch template for single agent pool"
  }

  assert {
    condition     = aws_launch_template.unreal_horde_agent_template["default"].instance_type == "c5.2xlarge"
    error_message = "Launch template should use configured instance type"
  }

  assert {
    condition     = length(aws_s3_bucket.ansible_playbooks) > 0
    error_message = "Should create S3 bucket for Ansible playbooks when agents are configured"
  }

  assert {
    condition     = length(aws_iam_role.unreal_horde_agent_default_role) == 1
    error_message = "Agent IAM role should be created"
  }

  assert {
    condition     = length(aws_iam_instance_profile.unreal_horde_agent_instance_profile) == 1
    error_message = "Agent instance profile should be created"
  }
}

# Test: Multiple agent pools with different configurations
run "unit_test_multiple_agent_pools" {
  command = plan

  variables {
    vpc_id                            = "vpc-12345678"
    unreal_horde_service_subnets      = ["subnet-123", "subnet-456"]
    unreal_horde_internal_alb_subnets = ["subnet-123", "subnet-456"]
    certificate_arn                   = "arn:aws:acm:us-east-1:123456789012:certificate/test"
    fully_qualified_domain_name       = "horde.example.com"

    create_external_alb = false
    create_internal_alb = true
    name                = "horde-multi"

    # Multiple agent pools
    agents = {
      "build-pool" = {
        ami             = "ami-12345678"
        instance_type   = "c5.4xlarge"
        horde_pool_name = "build-agents"
        block_device_mappings = [
          {
            device_name = "/dev/xvda"
            ebs = {
              volume_size = 200
            }
          }
        ]
        min_size = 2
        max_size = 10
      }
      "test-pool" = {
        ami             = "ami-87654321"
        instance_type   = "c5.2xlarge"
        horde_pool_name = "test-agents"
        block_device_mappings = [
          {
            device_name = "/dev/xvda"
            ebs = {
              volume_size = 100
            }
          }
        ]
        min_size = 1
        max_size = 5
      }
    }

    agent_dotnet_runtime_version = "8.0"
    enable_new_agents_by_default = false
  }

  assert {
    condition     = length(aws_autoscaling_group.unreal_horde_agent_asg) == 2
    error_message = "Should create 2 autoscaling groups for multiple agent pools"
  }

  assert {
    condition     = aws_autoscaling_group.unreal_horde_agent_asg["build-pool"].min_size == 2
    error_message = "Build pool ASG should have min_size of 2 as configured"
  }

  assert {
    condition     = aws_autoscaling_group.unreal_horde_agent_asg["test-pool"].min_size == 1
    error_message = "Test pool ASG should have min_size of 1 as configured"
  }

  assert {
    condition     = length(aws_launch_template.unreal_horde_agent_template) == 2
    error_message = "Should create 2 launch templates for multiple agent pools"
  }

  assert {
    condition     = aws_launch_template.unreal_horde_agent_template["build-pool"].instance_type == "c5.4xlarge"
    error_message = "Build pool should use c5.4xlarge instance type"
  }

  assert {
    condition     = aws_launch_template.unreal_horde_agent_template["test-pool"].instance_type == "c5.2xlarge"
    error_message = "Test pool should use c5.2xlarge instance type"
  }

  assert {
    condition     = length(aws_s3_bucket.ansible_playbooks) > 0
    error_message = "Should create S3 bucket for Ansible playbooks when agents are configured"
  }
}

# Test: No agents configured (empty map)
run "unit_test_no_agents" {
  command = plan

  variables {
    vpc_id                            = "vpc-12345678"
    unreal_horde_service_subnets      = ["subnet-123", "subnet-456"]
    unreal_horde_internal_alb_subnets = ["subnet-123", "subnet-456"]
    certificate_arn                   = "arn:aws:acm:us-east-1:123456789012:certificate/test"
    fully_qualified_domain_name       = "horde.example.com"

    create_external_alb = false
    create_internal_alb = true
    name                = "horde-none"

    # No agents
    agents = {}
  }

  assert {
    condition     = length(aws_autoscaling_group.unreal_horde_agent_asg) == 0
    error_message = "Should not create autoscaling groups when no agents configured"
  }

  assert {
    condition     = length(aws_launch_template.unreal_horde_agent_template) == 0
    error_message = "Should not create launch templates when no agents configured"
  }
}

# Test: Agent with custom dotnet runtime version
run "unit_test_custom_dotnet_version" {
  command = plan

  variables {
    vpc_id                            = "vpc-12345678"
    unreal_horde_service_subnets      = ["subnet-123", "subnet-456"]
    unreal_horde_internal_alb_subnets = ["subnet-123", "subnet-456"]
    certificate_arn                   = "arn:aws:acm:us-east-1:123456789012:certificate/test"
    fully_qualified_domain_name       = "horde.example.com"

    create_external_alb = false
    create_internal_alb = true

    agents = {
      "dotnet8" = {
        ami           = "ami-12345678"
        instance_type = "c5.xlarge"
        block_device_mappings = [
          {
            device_name = "/dev/xvda"
            ebs = {
              volume_size = 50
            }
          }
        ]
      }
    }

    agent_dotnet_runtime_version = "8.0"
  }

  assert {
    condition     = length(aws_autoscaling_group.unreal_horde_agent_asg) == 1
    error_message = "Should create agent with custom dotnet version"
  }
}
