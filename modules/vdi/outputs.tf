# ===================
# CORE MODULE OUTPUTS
# ===================

# Essential instance data for integration
output "instance_ids" {
  description = "Map of VDI instance IDs"
  value = {
    for user, instance in aws_instance.vdi_instances : user => instance.id
  }
}

output "public_ips" {
  description = "Map of VDI public IP addresses"
  value = {
    for user, instance in aws_instance.vdi_instances : user => instance.public_ip
  }
}

output "private_ips" {
  description = "Map of VDI private IP addresses"
  value = {
    for user, instance in aws_instance.vdi_instances : user => instance.private_ip
  }
}

# Essential credentials for access
output "private_keys" {
  description = "Map of private keys for created key pairs (sensitive)"
  value = {
    for user, key in tls_private_key.vdi_keys : user => key.private_key_pem
  }
  sensitive = true
}

# Essential IAM for integrations
output "iam_instance_profile" {
  description = "The IAM instance profile name"
  value       = aws_iam_instance_profile.vdi_instance_profile.name
}
