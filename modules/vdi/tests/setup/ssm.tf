# Fetch relevant values from SSM Parameter Store
data "aws_ssm_parameter" "route53_public_hosted_zone_name" {
  name = "/cloud-game-development-toolkit/modules/vdi/route53-public-hosted-zone-name"
}

data "aws_ssm_parameter" "directory_name" {
  name = "/cloud-game-development-toolkit/modules/vdi/directory-name"
}

data "aws_ssm_parameter" "admin_password" {
  name = "/cloud-game-development-toolkit/modules/vdi/admin-password"
}

data "aws_ssm_parameter" "directory_admin_password" {
  name = "/cloud-game-development-toolkit/modules/vdi/directory-admin-password"
}

output "route53_public_hosted_zone_name" {
  value     = nonsensitive(data.aws_ssm_parameter.route53_public_hosted_zone_name.value)
  sensitive = false
}

output "directory_name" {
  value     = nonsensitive(data.aws_ssm_parameter.directory_name.value)
  sensitive = false
}

output "admin_password" {
  value     = nonsensitive(data.aws_ssm_parameter.admin_password.value)
  sensitive = false
}

output "directory_admin_password" {
  value     = nonsensitive(data.aws_ssm_parameter.directory_admin_password.value)
  sensitive = false
}
