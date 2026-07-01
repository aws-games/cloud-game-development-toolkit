mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
  mock_data "aws_region" {
    defaults = { name = "us-east-1" }
  }
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b"]
    }
  }
}
mock_provider "tls" {}
mock_provider "random" {}
mock_provider "archive" {}

# =============================================================================
# Default mode: auth_mode=none, ADOT enabled
# =============================================================================

run "default_mode_plans_successfully" {
  command = plan

  variables {
    project_prefix        = "lore"
    environment           = "dev"
    container_image       = "placeholder:latest"
    allowed_ingress_cidrs = ["10.0.0.0/8"]
  }

  assert {
    condition     = output.cognito_user_pool_id == null
    error_message = "Cognito should not be provisioned when auth_mode=none"
  }

  assert {
    condition     = output.cognito_client_id == null
    error_message = "Cognito client should not exist when auth_mode=none"
  }
}

# =============================================================================
# Cognito mode
# =============================================================================

run "cognito_mode_plans_successfully" {
  command = plan

  variables {
    project_prefix        = "lore"
    environment           = "dev"
    container_image       = "placeholder:latest"
    allowed_ingress_cidrs = ["10.0.0.0/8"]
    auth_mode             = "cognito"
  }
}

# =============================================================================
# External mode — with required endpoints
# =============================================================================

run "external_mode_plans_successfully" {
  command = plan

  variables {
    project_prefix        = "lore"
    environment           = "dev"
    container_image       = "placeholder:latest"
    allowed_ingress_cidrs = ["10.0.0.0/8"]
    auth_mode             = "external"
    auth_jwk_endpoint     = "https://example.com/.well-known/jwks.json"
    auth_jwt_issuer       = "https://example.com"
  }

  assert {
    condition     = output.cognito_user_pool_id == null
    error_message = "Cognito should not be provisioned when auth_mode=external"
  }
}

# =============================================================================
# External mode — missing endpoint fails validation
# =============================================================================

run "external_mode_requires_jwk_endpoint" {
  command = plan

  variables {
    project_prefix        = "lore"
    environment           = "dev"
    container_image       = "placeholder:latest"
    allowed_ingress_cidrs = ["10.0.0.0/8"]
    auth_mode             = "external"
    auth_jwt_issuer       = "https://example.com"
  }

  expect_failures = [var.auth_jwk_endpoint]
}

run "external_mode_requires_jwt_issuer" {
  command = plan

  variables {
    project_prefix        = "lore"
    environment           = "dev"
    container_image       = "placeholder:latest"
    allowed_ingress_cidrs = ["10.0.0.0/8"]
    auth_mode             = "external"
    auth_jwk_endpoint     = "https://example.com/.well-known/jwks.json"
  }

  expect_failures = [var.auth_jwt_issuer]
}

# =============================================================================
# ADOT disabled
# =============================================================================

run "otel_disabled_plans_successfully" {
  command = plan

  variables {
    project_prefix        = "lore"
    environment           = "dev"
    container_image       = "placeholder:latest"
    allowed_ingress_cidrs = ["10.0.0.0/8"]
    enable_otel_sidecar   = false
  }
}
