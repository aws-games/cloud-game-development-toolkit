output "ddc_endpoint" {
  description = "DDC DNS endpoint"
  value = module.unreal_cloud_ddc.ddc_connection.endpoint
}

output "bearer_token_secret_arn" {
  description = "ARN of the DDC bearer token secret in AWS Secrets Manager"
  value = module.unreal_cloud_ddc.bearer_token_secret_arn
}

output "scylla_instance_ids" {
  description = "ScyllaDB instance IDs for SSM access"
  value = module.unreal_cloud_ddc.ddc_connection.scylla_instance_ids
}

output "scylla_ips" {
  description = "ScyllaDB instance private IPs"
  value = module.unreal_cloud_ddc.ddc_connection.scylla_ips
}

output "ddc_connection" {
  description = "DDC connection information for scripts"
  value = module.unreal_cloud_ddc.ddc_connection
}
