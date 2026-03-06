data "aws_caller_identity" "current" {}

# GHCR credentials from Secrets Manager
data "aws_secretsmanager_secret_version" "ghcr_credentials" {
  secret_id = var.ghcr_credentials_secret_arn
}
