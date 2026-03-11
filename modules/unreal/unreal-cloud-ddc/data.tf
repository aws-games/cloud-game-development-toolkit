################################################################################
# Data Sources
################################################################################

# Read existing bearer token secret (when reusing from another region)
# Use secret name for cross-region replica access
data "aws_secretsmanager_secret_version" "existing_token" {
  count = var.create_bearer_token == false ? 1 : 0

  region = local.region  # Use local region to target the replica endpoint
  # Use secret name instead of ARN - AWS resolves to local replica automatically
  secret_id = var.ddc_application_config != null && var.ddc_application_config.bearer_token_secret_name != null ? var.ddc_application_config.bearer_token_secret_name : "dummy-secret-name"
}

# Current AWS caller identity
data "aws_caller_identity" "current" {}

# Current AWS region
data "aws_region" "current" {}

# VPC information for security group CIDR rules
data "aws_vpc" "main" {
  region = local.region
  id     = var.vpc_id
}

# Dynamic IP detection (optional)
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

# Public hosted zone (when provided)
data "aws_route53_zone" "public" {
  count = var.route53_hosted_zone_name != null ? 1 : 0
  name  = var.route53_hosted_zone_name
}


