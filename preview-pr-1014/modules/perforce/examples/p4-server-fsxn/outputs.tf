output "amazon_fsxn_filesystem" {
  value       = aws_fsx_ontap_file_system.p4_server_fs.id
  description = "FSxN filesystem ID"
}

output "p4_server_connection_string" {
  value       = "ssl:perforce.${var.route53_public_hosted_zone_name}:1666"
  description = "The connection string for the Helix Core server. Set your P4PORT environment variable to this value."
}
