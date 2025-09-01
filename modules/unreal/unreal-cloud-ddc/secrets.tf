################################################################################
# DDC Bearer Token Management
################################################################################

# Bearer token secret - created per region for independence
resource "aws_secretsmanager_secret" "unreal_cloud_ddc_token" {
  count       = var.ddc_bearer_token_secret_arn == null && var.ddc_infra_config != null ? 1 : 0
  name        = "${local.name_prefix}-bearer-token"
  description = "The bearer token to access Unreal Cloud DDC service"
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-bearer-token"
  })
}

ephemeral "random_password" "ddc_token" {
  count   = var.ddc_bearer_token_secret_arn == null && var.ddc_infra_config != null ? 1 : 0
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret_version" "unreal_cloud_ddc_token" {
  count                    = var.ddc_bearer_token_secret_arn == null && var.ddc_infra_config != null ? 1 : 0
  secret_id                = aws_secretsmanager_secret.unreal_cloud_ddc_token[0].id
  secret_string_wo         = ephemeral.random_password.ddc_token[0].result
  secret_string_wo_version = 1
}

# Ephemeral resource for reading created secrets (maximum security)
ephemeral "aws_secretsmanager_secret_version" "ddc_token" {
  count     = var.ddc_infra_config != null ? 1 : 0
  secret_id = aws_secretsmanager_secret_version.unreal_cloud_ddc_token[0].secret_id
}