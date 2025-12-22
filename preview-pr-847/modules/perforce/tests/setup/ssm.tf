# Fetch relevant values from SSM Parameter Store
data "aws_ssm_parameter" "route53_public_hosted_zone_name" {
  name = "/cloud-game-development-toolkit/modules/perforce/route53-public-hosted-zone-name"
}
data "aws_ssm_parameter" "fsxn_password" {
  name = "/cloud-game-development-toolkit/modules/perforce/fsxn-password"
}
data "aws_ssm_parameter" "fsxn_aws_profile" {
  name = "/cloud-game-development-toolkit/modules/perforce/fsxn-aws-profile"
}


output "route53_public_hosted_zone_name" {
  value     = nonsensitive(data.aws_ssm_parameter.route53_public_hosted_zone_name.value)
  sensitive = false
}
output "fsxn_password" {
  value     = nonsensitive(data.aws_ssm_parameter.fsxn_password.value)
  sensitive = false
}
output "fsxn_aws_profile" {
  value     = nonsensitive(data.aws_ssm_parameter.fsxn_aws_profile.value)
  sensitive = false
}
