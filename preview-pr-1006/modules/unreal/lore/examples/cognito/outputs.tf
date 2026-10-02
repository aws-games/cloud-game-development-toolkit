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

output "cognito_token_endpoint" {
  value = module.lore.cognito_token_endpoint
}

output "cognito_client_id" {
  value = module.lore.cognito_client_id
}

output "cognito_client_secret" {
  value     = module.lore.cognito_client_secret
  sensitive = true
}
