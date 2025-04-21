output "helix_core_connection_string" {
  value       = "ssl:perforce.${var.root_domain_name}:1666"
  description = "The connection string for the Helix Core server. Set your P4PORT environment variable to this value."
}

output "helix_swarm_url" {
  value       = "https://swarm.perforce.${var.root_domain_name}"
  description = "The URL for the Helix Swarm server."
}

output "helix_authentication_service_admin_url" {
  value       = "https://auth.perforce.${var.root_domain_name}/admin"
  description = "The URL for the Helix Authentication Service admin page."
}
