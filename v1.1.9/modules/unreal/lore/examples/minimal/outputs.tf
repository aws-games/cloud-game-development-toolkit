output "write_tier_dns" {
  description = "Cloud Map DNS for the write tier (connect via VPN/DirectConnect to private subnet)"
  value       = module.lore.write_tier_discovery_dns
}

output "ca_certificate_pem" {
  description = "CA cert for client trust bundle"
  value       = module.lore.ca_certificate_pem
  sensitive   = true
}

output "vpc_id" {
  description = "VPC ID (for adding edge pods later)"
  value       = module.lore.vpc_id
}
