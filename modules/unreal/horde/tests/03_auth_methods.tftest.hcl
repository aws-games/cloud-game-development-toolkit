# Test: Authentication method configurations
# This test validates different authentication configurations:
# - Anonymous authentication
# - OIDC authentication with required parameters
# - Variable validation for authentication methods

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

# Test: Anonymous authentication
run "unit_test_anonymous_auth" {
  command = plan

  variables {
    vpc_id                            = "vpc-12345678"
    unreal_horde_service_subnets      = ["subnet-123", "subnet-456"]
    unreal_horde_internal_alb_subnets = ["subnet-123", "subnet-456"]
    certificate_arn                   = "arn:aws:acm:us-east-1:123456789012:certificate/test"
    fully_qualified_domain_name       = "horde.example.com"

    create_external_alb = false
    create_internal_alb = true
    name                = "horde-anon"

    # Anonymous authentication
    auth_method = "Anonymous"
  }

  assert {
    condition     = length(aws_ecs_service.unreal_horde) > 0
    error_message = "ECS service should be created with anonymous auth"
  }
}

# Test: OIDC authentication with all required parameters
run "unit_test_oidc_auth" {
  command = plan

  variables {
    vpc_id                            = "vpc-12345678"
    unreal_horde_service_subnets      = ["subnet-123", "subnet-456"]
    unreal_horde_internal_alb_subnets = ["subnet-123", "subnet-456"]
    certificate_arn                   = "arn:aws:acm:us-east-1:123456789012:certificate/test"
    fully_qualified_domain_name       = "horde.example.com"

    create_external_alb = false
    create_internal_alb = true
    name                = "horde-oidc"

    # OIDC authentication
    auth_method          = "OpenIdConnect"
    oidc_authority       = "https://auth.example.com"
    oidc_audience        = "horde-api"
    oidc_client_id       = "test-client-id"
    oidc_client_secret   = "test-client-secret"
    oidc_signin_redirect = "https://horde.example.com/signin-oidc"
    admin_claim_type     = "groups"
    admin_claim_value    = "horde-admins"
  }

  assert {
    condition     = length(aws_ecs_service.unreal_horde) > 0
    error_message = "ECS service should be created with OIDC auth"
  }
}

# Test: Okta authentication
run "unit_test_okta_auth" {
  command = plan

  variables {
    vpc_id                            = "vpc-12345678"
    unreal_horde_service_subnets      = ["subnet-123", "subnet-456"]
    unreal_horde_internal_alb_subnets = ["subnet-123", "subnet-456"]
    certificate_arn                   = "arn:aws:acm:us-east-1:123456789012:certificate/test"
    fully_qualified_domain_name       = "horde.example.com"

    create_external_alb = false
    create_internal_alb = true
    name                = "horde-okta"

    # Okta authentication
    auth_method          = "Okta"
    oidc_authority       = "https://dev-12345.okta.com"
    oidc_audience        = "horde-api"
    oidc_client_id       = "okta-client-id"
    oidc_client_secret   = "okta-client-secret"
    oidc_signin_redirect = "https://horde.example.com/signin-okta"
  }

  assert {
    condition     = length(aws_ecs_service.unreal_horde) > 0
    error_message = "ECS service should be created with Okta auth"
  }
}

# Test: Invalid authentication method should fail validation
run "unit_test_invalid_auth_method" {
  command = plan

  variables {
    vpc_id                            = "vpc-12345678"
    unreal_horde_service_subnets      = ["subnet-123", "subnet-456"]
    unreal_horde_internal_alb_subnets = ["subnet-123", "subnet-456"]
    certificate_arn                   = "arn:aws:acm:us-east-1:123456789012:certificate/test"
    fully_qualified_domain_name       = "horde.example.com"

    create_external_alb = false
    create_internal_alb = true

    # Invalid authentication method
    auth_method = "InvalidMethod"
  }

  expect_failures = [
    var.auth_method
  ]
}

# Test: OIDC without required parameters should fail validation
run "unit_test_oidc_missing_params" {
  command = plan

  variables {
    vpc_id                            = "vpc-12345678"
    unreal_horde_service_subnets      = ["subnet-123", "subnet-456"]
    unreal_horde_internal_alb_subnets = ["subnet-123", "subnet-456"]
    certificate_arn                   = "arn:aws:acm:us-east-1:123456789012:certificate/test"
    fully_qualified_domain_name       = "horde.example.com"

    create_external_alb = false
    create_internal_alb = true

    # OIDC without required parameters
    auth_method = "OpenIdConnect"
    # Missing: oidc_authority, oidc_audience, oidc_client_id, etc.
  }

  expect_failures = [
    var.oidc_authority,
    var.oidc_audience,
    var.oidc_client_id,
    var.oidc_client_secret,
    var.oidc_signin_redirect
  ]
}

# Test: Perforce integration
run "unit_test_perforce_integration" {
  command = plan

  variables {
    vpc_id                            = "vpc-12345678"
    unreal_horde_service_subnets      = ["subnet-123", "subnet-456"]
    unreal_horde_internal_alb_subnets = ["subnet-123", "subnet-456"]
    certificate_arn                   = "arn:aws:acm:us-east-1:123456789012:certificate/test"
    fully_qualified_domain_name       = "horde.example.com"

    create_external_alb = false
    create_internal_alb = true
    name                = "horde-p4"

    # Perforce configuration
    p4_port                           = "ssl:perforce.example.com:1666"
    p4_super_user_username_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:p4-user"
    p4_super_user_password_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:p4-pass"
  }

  assert {
    condition     = length(aws_ecs_service.unreal_horde) > 0
    error_message = "ECS service should be created with Perforce integration"
  }
}
