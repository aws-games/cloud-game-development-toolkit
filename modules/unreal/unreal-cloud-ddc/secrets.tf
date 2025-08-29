##########################################
# DDC Authentication Token (Conditional)
##########################################
resource "awscc_secretsmanager_secret" "unreal_cloud_ddc_token" {
  count       = var.ddc_bearer_token_secret_arn == null ? 1 : 0
  name        = "${local.name_prefix}-bearer-token-single-region"
  description = "The bearer token to access Unreal Cloud DDC service."
  generate_secret_string = {
    exclude_punctuation = true
    exclude_numbers     = false
    include_space       = false
    password_length     = 64
  }
  
  # Replicate to secondary region if multi-region
  replica_regions = local.is_multi_region ? [{
    region = local.secondary_region
  }] : []
  
  provider = awscc.primary
}

data "aws_secretsmanager_secret_version" "unreal_cloud_ddc_token" {
  secret_id = var.ddc_bearer_token_secret_arn != null ? var.ddc_bearer_token_secret_arn : awscc_secretsmanager_secret.unreal_cloud_ddc_token[0].id
  region    = local.primary_region
}