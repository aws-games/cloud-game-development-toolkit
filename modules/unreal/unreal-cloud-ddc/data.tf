################################################################################
# Data Sources
################################################################################

# Read existing bearer token secret (when reusing from another region)
data "aws_secretsmanager_secret_version" "existing_token" {
  count = var.create_bearer_token == false ? 1 : 0
  
  # Dynamically replace the region in the ARN to read from local replica
  secret_id = replace(
    var.ddc_application_config.bearer_token_secret_arn,
    "/arn:aws:secretsmanager:[^:]+:/",
    "arn:aws:secretsmanager:${data.aws_region.current.region}:"
  )
}

# Current AWS caller identity
data "aws_caller_identity" "current" {}

# Current AWS region
data "aws_region" "current" {}
