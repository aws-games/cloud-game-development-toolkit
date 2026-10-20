output "write_tier_dns" {
  description = "Write tier name (resolves inside both VPCs)"
  value       = module.lore.write_tier_dns_name
}

output "regional_tier_dns" {
  description = "Regional tier name (resolves inside both VPCs)"
  value       = module.regional_tier.tier_dns_name
}

output "write_fragment_bucket" {
  value = module.lore.fragment_bucket_name
}

output "replica_fragment_bucket" {
  value = module.regional_tier.fragment_bucket_name
}

output "peering_connection_id" {
  value = aws_vpc_peering_connection.regions.id
}
