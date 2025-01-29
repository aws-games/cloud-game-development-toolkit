

output "amazon_fsxn_filesystem" {
  value       = aws_fsx_ontap_file_system.helix_core_fs.id
  description = "FSxN filesystem ID"
}
