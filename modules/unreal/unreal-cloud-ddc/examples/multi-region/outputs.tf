# Multi-region DDC deployment outputs

# Primary Region Outputs
output "ddc_primary_nlb_dns" {
  value = module.unreal_cloud_ddc_primary.ddc_infra.nlb_dns_name
  description = "DNS name of the primary region DDC Network Load Balancer"
}

output "ddc_secondary_nlb_dns" {
  value = module.unreal_cloud_ddc_secondary.ddc_infra.nlb_dns_name
  description = "DNS name of the secondary region DDC Network Load Balancer"
}

# ScyllaDB Seed IP (for reference)
output "scylla_seed_ip" {
  value = module.unreal_cloud_ddc_primary.ddc_infra.scylla_seed
  description = "IP address of the ScyllaDB seed node (primary region)"
}

# Combined DDC Connection Information
output "ddc_connection" {
  description = "Complete DDC connection information for both regions"
  value = {
    primary = module.unreal_cloud_ddc_primary.ddc_connection.primary
    secondary = module.unreal_cloud_ddc_secondary.ddc_connection.secondary
    bearer_token_secret = module.unreal_cloud_ddc_primary.bearer_token_secret_arn
  }
}

# Individual region connections for reference
output "ddc_connection_primary" {
  description = "DDC connection information for primary region only"
  value = module.unreal_cloud_ddc_primary.ddc_connection
}

output "ddc_connection_secondary" {
  description = "DDC connection information for secondary region only"
  value = module.unreal_cloud_ddc_secondary.ddc_connection
}