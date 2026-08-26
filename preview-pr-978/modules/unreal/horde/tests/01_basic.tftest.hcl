# Test: Basic Horde deployment with minimal configuration
# This test validates a minimal Horde deployment with:
# - Internal ALB only (no external ALB)
# - Default DocumentDB and ElastiCache settings
# - No authentication configured
# - No build agents

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

# Unit test: Validate basic configuration
run "unit_test_basic" {
  command = plan

  variables {
    # Test values - no SSM needed
    vpc_id                            = "vpc-12345678"
    unreal_horde_service_subnets      = ["subnet-123", "subnet-456", "subnet-789"]
    unreal_horde_internal_alb_subnets = ["subnet-123", "subnet-456", "subnet-789"]
    certificate_arn                   = "arn:aws:acm:us-east-1:123456789012:certificate/test-cert-123"
    fully_qualified_domain_name       = "horde.example.com"

    # Basic configuration
    create_external_alb = false
    create_internal_alb = true
    name                = "horde-basic"
    environment         = "test"
  }

  # Assertions for basic deployment
  assert {
    condition     = length(aws_ecs_cluster.unreal_horde_cluster) > 0
    error_message = "ECS cluster should be created"
  }

  assert {
    condition     = length(aws_ecs_service.unreal_horde) > 0
    error_message = "ECS service should be created"
  }

  assert {
    condition     = aws_ecs_service.unreal_horde.launch_type == "FARGATE"
    error_message = "ECS service should use FARGATE launch type"
  }

  assert {
    condition     = length(aws_lb.unreal_horde_internal_alb) == 1
    error_message = "Internal ALB should be created when create_internal_alb is true"
  }

  assert {
    condition     = aws_lb.unreal_horde_internal_alb[0].internal == true
    error_message = "Internal ALB should be marked as internal"
  }

  assert {
    condition     = length(aws_lb.unreal_horde_external_alb) == 0
    error_message = "External ALB should not be created when create_external_alb is false"
  }

  assert {
    condition     = length(aws_lb_target_group.unreal_horde_api_target_group_internal) == 1
    error_message = "Internal API target group should be created"
  }

  assert {
    condition     = length(aws_lb_target_group.unreal_horde_grpc_target_group_internal) == 1
    error_message = "Internal GRPC target group should be created"
  }

  assert {
    condition     = length(aws_docdb_cluster.horde) > 0
    error_message = "DocumentDB cluster should be created"
  }

  assert {
    condition     = aws_docdb_cluster.horde[0].engine == "docdb"
    error_message = "DocumentDB cluster should use docdb engine"
  }

  assert {
    condition     = length(aws_elasticache_cluster.horde) > 0 || length(aws_elasticache_replication_group.horde) > 0
    error_message = "ElastiCache cluster should be created"
  }

  assert {
    condition     = length(aws_security_group.unreal_horde_sg) > 0
    error_message = "Horde security group should be created"
  }

  assert {
    condition     = aws_security_group.unreal_horde_sg.vpc_id == "vpc-12345678"
    error_message = "Horde security group should be in the correct VPC"
  }

  assert {
    condition     = length(aws_iam_role.unreal_horde_default_role) > 0
    error_message = "Horde IAM role should be created"
  }

  assert {
    condition     = length(aws_iam_role.unreal_horde_task_execution_role) > 0
    error_message = "Task execution IAM role should be created"
  }

  assert {
    condition     = contains(keys(aws_ecs_cluster.unreal_horde_cluster[0].tags), "environment")
    error_message = "ECS cluster should have environment tag"
  }
}
