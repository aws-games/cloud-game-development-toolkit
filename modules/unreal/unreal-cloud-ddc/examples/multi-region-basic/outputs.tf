# Multi-region DDC deployment outputs grouped by region

output "us-east-1" {
  description = "All outputs for us-east-1 region"
  value = {
    region = local.primary_region
    region_type = local.regions[local.primary_region].type
    ddc_endpoint = "https://${aws_route53_record.primary_ddc_service.name}"
    ddc_endpoint_nlb = "https://${module.unreal_cloud_ddc_primary.nlb_dns_name}"
    bearer_token_secret_arn = module.unreal_cloud_ddc_primary.bearer_token_secret_arn
    security_warning = module.unreal_cloud_ddc_primary.ddc_connection.security_warning
    scylla_instance_ids = module.unreal_cloud_ddc_primary.ddc_infra.scylla_instance_ids
    scylla_ips = module.unreal_cloud_ddc_primary.ddc_infra.scylla_ips
  }
}

output "us-west-1" {
  description = "All outputs for us-west-1 region"
  value = {
    region = local.secondary_region
    region_type = local.regions[local.secondary_region].type
    ddc_endpoint = "https://${aws_route53_record.secondary_ddc_service.name}"
    ddc_endpoint_nlb = "https://${module.unreal_cloud_ddc_secondary.nlb_dns_name}"
    security_warning = module.unreal_cloud_ddc_secondary.ddc_connection.security_warning
    scylla_instance_ids = module.unreal_cloud_ddc_secondary.ddc_infra.scylla_instance_ids
    scylla_ips = module.unreal_cloud_ddc_secondary.ddc_infra.scylla_ips
  }
}



