# VDI Module v2.0.0 Example Outputs

output "connection_info" {
  description = "VDI connection information"
  value       = module.vdi.connection_info
}

output "password_retrieval_commands" {
  description = "Commands to retrieve passwords"
  value       = module.vdi.password_retrieval_commands
  sensitive   = true
}

output "private_keys" {
  description = "Private keys for emergency access"
  value       = module.vdi.private_keys
  sensitive   = true
}

output "secrets_manager_arns" {
  description = "Secrets Manager ARNs for user passwords"
  value       = module.vdi.secrets_manager_arns
}