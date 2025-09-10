# VDI Module outputs
output "instance_ids" {
  description = "VDI instance IDs"
  value       = module.vdi.instance_ids
}

output "private_ips" {
  description = "VDI private IP addresses"
  value       = module.vdi.private_ips
}

output "user_secrets" {
  description = "User secrets in Secrets Manager"
  value       = module.vdi.user_secrets
  sensitive   = true
}

# Client VPN outputs (from main module)
output "client_vpn_endpoint_id" {
  description = "Client VPN endpoint ID"
  value       = module.vdi.client_vpn_endpoint_id
}

output "vpn_configs_s3_bucket" {
  description = "S3 bucket containing VPN client configurations"
  value       = module.vdi.vpn_configs_s3_bucket
}

output "internal_dns_zone" {
  description = "Internal DNS zone for private access"
  value       = module.vdi.internal_dns_zone
}