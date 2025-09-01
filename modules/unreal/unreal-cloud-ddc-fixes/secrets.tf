################################################################################
# DDC Bearer Token Management
################################################################################

# Random suffix to prevent name conflicts during recreation
resource "random_string" "bearer_token_suffix" {
  count   = var.ddc_bearer_token_secret_arn == null && var.ddc_infra_config != null ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

# Bearer token secret - create if no existing ARN provided
resource "aws_secretsmanager_secret" "unreal_cloud_ddc_token" {
  count       = var.ddc_bearer_token_secret_arn == null && var.ddc_infra_config != null ? 1 : 0
  name        = "${local.name_prefix}-bearer-token-${random_string.bearer_token_suffix[0].result}"
  description = "The bearer token to access Unreal Cloud DDC service"
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-bearer-token"
  })
}

resource "random_password" "ddc_token" {
  count   = var.ddc_bearer_token_secret_arn == null && var.ddc_infra_config != null ? 1 : 0
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret_version" "unreal_cloud_ddc_token" {
  count         = var.ddc_bearer_token_secret_arn == null && var.ddc_infra_config != null ? 1 : 0
  secret_id     = aws_secretsmanager_secret.unreal_cloud_ddc_token[0].id
  secret_string = random_password.ddc_token[0].result
}