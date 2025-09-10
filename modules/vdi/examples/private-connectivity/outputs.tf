# VDI Module outputs
output "instance_ids" {
  description = "VDI instance IDs"
  value       = module.vdi.instance_ids
}

output "connection_info" {
  description = "VDI connection information"
  value       = module.vdi.connection_info
}

output "secrets_manager_arns" {
  description = "Secrets Manager ARNs for user passwords"
  value       = module.vdi.secrets_manager_arns
  sensitive   = true
}

output "password_retrieval_commands" {
  description = "Commands to retrieve user passwords"
  value       = module.vdi.password_retrieval_commands
  sensitive   = true
}