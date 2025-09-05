# Fetch relevant values from SSM Parameter Store for DDC module testing
# Examples CREATE: VPC, subnets, security groups, ACM certificate
# Examples EXPECT: Route53 hosted zone name, GHCR credentials

data "aws_ssm_parameter" "route53_public_hosted_zone_name" {
  name = "/cgd-toolkit/tests/unreal-cloud-ddc/route53-public-hosted-zone-name"
}

data "aws_ssm_parameter" "ghcr_credentials_secret_manager_arn" {
  name = "/cgd-toolkit/tests/unreal-cloud-ddc/ghcr-credentials-secret-manager-arn"
}

# Outputs for test consumption
output "route53_public_hosted_zone_name" {
  value = data.aws_ssm_parameter.route53_public_hosted_zone_name.value
}

output "ghcr_credentials_secret_manager_arn" {
  value = data.aws_ssm_parameter.ghcr_credentials_secret_manager_arn.value
}
