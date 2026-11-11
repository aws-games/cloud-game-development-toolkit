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

# =============================================================================
# Public catch-all ingress must fail, even in auth_mode=none
# =============================================================================

run "open_client_ingress_is_rejected" {
  command = plan

  variables {
    project_prefix        = "lore"
    environment           = "dev"
    container_image       = "placeholder:latest"
    allowed_ingress_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.allowed_ingress_cidrs]
}

# =============================================================================
# Custom TLS must be complete before an internal replication listener can start
# =============================================================================

run "custom_server_tls_requires_ca_secret" {
  command = plan

  variables {
    project_prefix                = "lore"
    environment                   = "dev"
    container_image               = "placeholder:latest"
    allowed_ingress_cidrs         = ["10.0.0.0/8"]
    tls_certificate_secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:server-cert"
    tls_private_key_secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:server-key"
    tls_ca_certificate_secret_arn = null
  }

  expect_failures = [var.tls_certificate_secret_arn]
}

run "custom_replication_tls_requires_client_identity" {
  command = plan

  variables {
    project_prefix        = "lore"
    environment           = "dev"
    container_image       = "placeholder:latest"
    allowed_ingress_cidrs = ["10.0.0.0/8"]
    replication_peers = [{
      address  = "same-tier.lore-dev.internal"
      locality = "SameRegion"
    }]
    tls_certificate_secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:server-cert"
    tls_private_key_secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:server-key"
    tls_ca_certificate_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ca-cert"
  }

  expect_failures = [var.tls_client_certificate_secret_arn]
}

run "complete_custom_replication_tls_plans" {
  command = plan

  variables {
    project_prefix        = "lore"
    environment           = "dev"
    container_image       = "placeholder:latest"
    allowed_ingress_cidrs = ["10.0.0.0/8"]
    replication_peers = [{
      address  = "same-tier.lore-dev.internal"
      locality = "SameRegion"
    }]
    tls_certificate_secret_arn        = "arn:aws:secretsmanager:us-east-1:123456789012:secret:server-cert"
    tls_private_key_secret_arn        = "arn:aws:secretsmanager:us-east-1:123456789012:secret:server-key"
    tls_ca_certificate_secret_arn     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ca-cert"
    tls_client_certificate_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:client-cert"
    tls_client_private_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:client-key"
    tls_material_version              = "rotation-2"
  }

  assert {
    condition     = one([for e in module.compute.listener_env_vars : e.value if e.name == "LORE__SERVER__QUIC_INTERNAL__VERIFY_CLIENT_CERTS"]) == "true"
    error_message = "Complete custom TLS must still enforce client-certificate verification"
  }
  assert {
    condition     = module.compute.tls_material_revision == "rotation-2"
    error_message = "Custom TLS rotation token must force a new ECS task definition"
  }
}

run "generated_server_tls_rejects_custom_client_identity" {
  command = plan

  variables {
    project_prefix                    = "lore"
    environment                       = "dev"
    container_image                   = "placeholder:latest"
    allowed_ingress_cidrs             = ["10.0.0.0/8"]
    tls_client_certificate_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:client-cert"
    tls_client_private_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:client-key"
  }

  expect_failures = [var.tls_client_certificate_secret_arn]
}
