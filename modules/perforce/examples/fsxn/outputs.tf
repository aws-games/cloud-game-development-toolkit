output "amazon_fsxn_filesystem" {
  value       = aws_fsx_ontap_file_system.helix_core_fs.id
  description = "FSxN filesystem ID"
}

output "helix_core_connection_string" {
  value       = "ssl:perforce.${var.root_domain_name}:1666"
  description = "The connection string for the Helix Core server. Set your P4PORT environment variable to this value."
}
