output "ddc_endpoint" {
  description = "DDC DNS endpoint"
  value = "https://${local.primary_region}.ddc.${var.route53_public_hosted_zone_name}"
}

output "ddc_endpoint_nlb" {
  description = "DDC direct NLB endpoint"
  value = "https://${module.unreal_cloud_ddc.nlb_dns_name}"
}

output "bearer_token_secret_arn" {
  description = "ARN of the DDC bearer token secret in AWS Secrets Manager"
  value = module.unreal_cloud_ddc.bearer_token_secret_arn
}

output "security_warning" {
  description = "Security warnings for the deployment"
  value = module.unreal_cloud_ddc.ddc_connection.security_warning
}



output "scylla_instance_ids" {
  description = "ScyllaDB instance IDs for SSM access"
  value = module.unreal_cloud_ddc.ddc_infra.scylla_instance_ids
}

output "scylla_ips" {
  description = "ScyllaDB instance private IPs"
  value = module.unreal_cloud_ddc.ddc_infra.scylla_ips
}