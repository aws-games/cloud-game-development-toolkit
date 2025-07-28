output "vdi_instance_id" {
  description = "The ID of the VDI EC2 instance"
  value       = var.create_instance ? aws_instance.vdi_instance[0].id : null
}

output "vdi_instance_private_ip" {
  description = "The private IP address of the VDI instance"
  value       = var.create_instance ? aws_instance.vdi_instance[0].private_ip : null
}

output "vdi_instance_public_ip" {
  description = "The public IP address of the VDI instance (if assigned)"
  value       = var.create_instance ? aws_instance.vdi_instance[0].public_ip : null
}

output "vdi_instance_private_dns" {
  description = "The private DNS name of the VDI instance"
  value       = var.create_instance ? aws_instance.vdi_instance[0].private_dns : null
}

output "vdi_instance_public_dns" {
  description = "The public DNS name of the VDI instance (if assigned)"
  value       = var.create_instance ? aws_instance.vdi_instance[0].public_dns : null
}

output "vdi_security_group_id" {
  description = "The ID of the security group associated with the VDI instance"
  value       = aws_security_group.vdi_sg.id
}

output "vdi_launch_template_id" {
  description = "The ID of the launch template for the VDI instance"
  value       = aws_launch_template.vdi_launch_template.id
}

output "vdi_launch_template_latest_version" {
  description = "The latest version of the launch template"
  value       = aws_launch_template.vdi_launch_template.latest_version
}

output "vdi_iam_role_arn" {
  description = "The ARN of the IAM role associated with the VDI instance"
  value       = aws_iam_role.vdi_instance_role.arn
}

output "vdi_iam_instance_profile_name" {
  description = "The name of the IAM instance profile associated with the VDI instance"
  value       = aws_iam_instance_profile.vdi_instance_profile.name
}

output "key_pair_name" {
  description = "The name of the key pair used for the VDI instance"
  value       = var.key_pair_name != null ? var.key_pair_name : (var.create_key_pair ? aws_key_pair.vdi_key_pair[0].key_name : null)
}

output "secrets_manager_secret_id" {
  description = "The ID of the AWS Secrets Manager secret containing credentials (if enabled)"
  value       = var.store_passwords_in_secrets_manager ? aws_secretsmanager_secret.vdi_secrets[0].id : null
}

output "admin_password_set" {
  description = "Indicates if an administrator password was set (either provided or generated)"
  value       = local.admin_password != null
}

output "ami_id" {
  description = "The ID of the AMI used for the VDI instance"
  value       = local.ami_id
}

output "ami_name" {
  description = "The name of the AMI used for the VDI instance"
  value       = var.ami_id != null ? null : (length(data.aws_ami.windows_server_2025_vdi) > 0 ? data.aws_ami.windows_server_2025_vdi[0].name : null)
}

output "ami_creation_date" {
  description = "The creation date of the AMI used for the VDI instance"
  value       = var.ami_id != null ? null : (length(data.aws_ami.windows_server_2025_vdi) > 0 ? data.aws_ami.windows_server_2025_vdi[0].creation_date : null)
}

output "ami_source" {
  description = "The source of the AMI (custom or auto-discovered)"
  value       = var.ami_id != null ? "custom" : "auto-discovered"
}
