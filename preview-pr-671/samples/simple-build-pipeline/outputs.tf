output "p4_server_connection_string" {
  value       = "ssl:${local.p4_server_fully_qualified_domain_name}:1666"
  description = "The connection string for the P4 Server. Set your P4PORT environment variable to this value."
}

output "p4_code_review_url" {
  value       = "https://${local.p4_code_review_fully_qualified_domain_name}"
  description = "The URL for the P4 Code Review service."
}

output "p4_auth_admin_url" {
  value       = "https://${local.p4_auth_fully_qualified_domain_name}/admin"
  description = "The URL for the P4Auth service admin page."
}

output "jenkins_url" {
  value       = "https://${local.jenkins_fully_qualified_domain_name}"
  description = "The URL for the Jenkins service."
}
