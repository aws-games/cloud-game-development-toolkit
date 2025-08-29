##########################################
# DDC Authentication Token
##########################################
resource "awscc_secretsmanager_secret" "unreal_cloud_ddc_token" {
  name        = "${local.project_prefix}-unreal-cloud-ddc-bearer-token-single-region"
  description = "The token to access unreal cloud ddc service."
  generate_secret_string = {
    exclude_punctuation = true
    exclude_numbers     = false
    include_space       = false
    password_length     = 64
  }
}

data "aws_secretsmanager_secret_version" "unreal_cloud_ddc_token" {
  depends_on = [awscc_secretsmanager_secret.unreal_cloud_ddc_token]
  secret_id  = awscc_secretsmanager_secret.unreal_cloud_ddc_token.id
}