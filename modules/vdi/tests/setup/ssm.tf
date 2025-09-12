# # Fetch relevant values from SSM Parameter Store for VDI local-only testing
# data "aws_ssm_parameter" "route53_public_hosted_zone_name" {
#   name = "/cloud-game-development-toolkit/modules/vdi/route53-public-hosted-zone-name"
# }

# output "route53_public_hosted_zone_name" {
#   value     = nonsensitive(data.aws_ssm_parameter.route53_public_hosted_zone_name.value)
#   sensitive = false
# }
