# Test: Complete Horde deployment with all features enabled
# This test validates a full-featured Horde deployment with:
# - Both external and internal ALBs
# - Custom DocumentDB and ElastiCache configurations
# - ALB access logging enabled
# - GitHub credentials configured
# - All optional features enabled

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

# Unit test: Validate complete configuration
run "unit_test_complete" {
  command = plan

  variables {
    # Test values - no SSM needed
    vpc_id                            = "vpc-12345678"
    unreal_horde_service_subnets      = ["subnet-123", "subnet-456", "subnet-789"]
    unreal_horde_external_alb_subnets = ["subnet-abc", "subnet-def", "subnet-ghi"]
    unreal_horde_internal_alb_subnets = ["subnet-123", "subnet-456", "subnet-789"]
    certificate_arn                   = "arn:aws:acm:us-east-1:123456789012:certificate/test-cert-123"
    fully_qualified_domain_name       = "horde.example.com"
    github_credentials_secret_arn     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:github-creds-abc123"

    # Complete configuration
    create_external_alb = true
    create_internal_alb = true
    name                = "horde-full"
    environment         = "test"

    # Custom database settings
    docdb_instance_count = 3
    docdb_instance_class = "db.t4g.medium"

    # Custom cache settings
    elasticache_engine        = "valkey"
    elasticache_cluster_count = 3
    elasticache_node_type     = "cache.t4g.small"

    # Enable logging
    enable_unreal_horde_alb_access_logs = true

    # Enable deletion protection for testing
    enable_unreal_horde_alb_deletion_protection = true
  }

  # Assertions for complete deployment
  assert {
    condition     = length(aws_lb.unreal_horde_external_alb) == 1
    error_message = "External ALB should be created when create_external_alb is true"
  }

  assert {
    condition     = length(aws_lb.unreal_horde_external_alb) == 1
    error_message = "External ALB should be created when create_external_alb is true"
  }

  assert {
    condition     = length(aws_lb.unreal_horde_internal_alb) == 1
    error_message = "Internal ALB should be created when create_internal_alb is true"
  }

  assert {
    condition     = length(aws_lb_target_group.unreal_horde_api_target_group_external) == 1
    error_message = "External API target group should be created"
  }

  assert {
    condition     = aws_lb_target_group.unreal_horde_api_target_group_external[0].target_type == "ip"
    error_message = "External API target group should use IP target type for Fargate"
  }

  assert {
    condition     = length(aws_lb_target_group.unreal_horde_grpc_target_group_external) == 1
    error_message = "External GRPC target group should be created"
  }

  assert {
    condition     = aws_lb_target_group.unreal_horde_grpc_target_group_external[0].protocol_version == "HTTP2"
    error_message = "External GRPC target group should use HTTP2 protocol version for gRPC"
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
    condition     = length(aws_docdb_cluster_instance.horde) == 3
    error_message = "Should create 3 DocumentDB instances as configured"
  }

  assert {
    condition     = aws_docdb_cluster_instance.horde[0].instance_class == "db.t4g.medium"
    error_message = "DocumentDB instances should use configured instance class"
  }

  assert {
    condition     = length(aws_elasticache_replication_group.horde) == 1
    error_message = "ElastiCache replication group should be created for valkey"
  }

  assert {
    condition     = aws_elasticache_replication_group.horde[0].engine == "valkey"
    error_message = "ElastiCache should use valkey engine as configured"
  }

  assert {
    condition     = aws_elasticache_replication_group.horde[0].num_cache_clusters == 3
    error_message = "ElastiCache should have 3 nodes as configured"
  }

  assert {
    condition     = length(aws_s3_bucket.unreal_horde_alb_access_logs_bucket) > 0
    error_message = "ALB access logs bucket should be created when logging is enabled"
  }

  assert {
    condition     = length(aws_security_group.unreal_horde_external_alb_sg) == 1
    error_message = "External ALB security group should be created"
  }

  assert {
    condition     = length(aws_security_group.unreal_horde_internal_alb_sg) == 1
    error_message = "Internal ALB security group should be created"
  }

  assert {
    condition     = length(aws_iam_policy.unreal_horde_secrets_manager_policy) == 1
    error_message = "Secrets Manager policy should be created when GitHub credentials are configured"
  }
}
