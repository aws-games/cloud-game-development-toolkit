output "write_tier_dns" {
  value = module.lore.write_tier_discovery_dns
}

output "edge_1_ip" {
  value = module.edge_1.private_ip
}

output "edge_2_ip" {
  value = module.edge_2.private_ip
}

output "ca_certificate_pem" {
  value     = module.lore.ca_certificate_pem
  sensitive = true
}
