output "ddc_endpoint" {
  description = "DDC DNS endpoint"
  value = "https://${local.primary_region}.ddc.${var.route53_public_hosted_zone_name}"
}

output "ddc_endpoint_nlb" {
  description = "DDC direct NLB endpoint"
  value = "https://${module.unreal_cloud_ddc.ddc_infra.nlb_dns_name}"
}

output "bearer_token_secret_arn" {
  description = "ARN of the DDC bearer token secret in AWS Secrets Manager"
  value = module.unreal_cloud_ddc.bearer_token_secret_arn
}