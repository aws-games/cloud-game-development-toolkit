################################################################################
# Data Sources
################################################################################

# Read existing bearer token secret (when reusing from another region)
data "aws_secretsmanager_secret_version" "existing_token" {
  count     = var.ddc_bearer_token_secret_arn != null ? 1 : 0
  secret_id = var.ddc_bearer_token_secret_arn
}

# Current AWS caller identity
data "aws_caller_identity" "current" {}

# Current AWS region
data "aws_region" "current" {}