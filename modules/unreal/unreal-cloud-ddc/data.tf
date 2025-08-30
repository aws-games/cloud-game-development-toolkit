################################################################################
# Data Sources
################################################################################

data "aws_secretsmanager_secret_version" "unreal_cloud_ddc_token" {
  secret_id = var.ddc_bearer_token_secret_arn != null ? var.ddc_bearer_token_secret_arn : aws_secretsmanager_secret.unreal_cloud_ddc_token[0].arn
}