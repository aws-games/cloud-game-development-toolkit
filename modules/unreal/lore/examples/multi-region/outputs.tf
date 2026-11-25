output "write_tier_dns" {
  description = "Write tier name (resolves inside both VPCs)"
  value       = module.lore.write_tier_dns_name
}

output "regional_cache_dns" {
  description = "Regional cache name (resolves inside both VPCs)"
  value       = module.regional_cache.cache_dns_name
}

output "fragment_bucket" {
  description = "The only fragment store (write region)"
  value       = module.lore.fragment_bucket_name
}

output "peering_connection_id" {
  value = aws_vpc_peering_connection.regions.id
}
