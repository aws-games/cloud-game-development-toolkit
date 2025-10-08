##########################################
# Perforce Outputs
##########################################

output "p4_server_connection_string" {
  description = "The connection string for the P4 Server. Set your P4PORT environment variable to this value."
  value       = "ssl:${local.perforce_fqdn}:1666"
}

output "p4_auth_admin_url" {
  description = "The URL for the P4Auth service admin page."
  value       = "https://${local.p4_auth_fqdn}/admin"
}

output "perforce_super_user_password_secret_arn" {
  description = "ARN of the secret containing Perforce super user password"
  value       = module.perforce.p4_server_super_user_password_secret_arn
}

output "perforce_super_user_username_secret_arn" {
  description = "ARN of the secret containing Perforce super user username"
  value       = module.perforce.p4_server_super_user_username_secret_arn
}
