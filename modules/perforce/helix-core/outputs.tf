output "helix_core_eip_private_ip" {
  value       = aws_eip.helix_core_eip[0].private_ip
  description = "The private IP of your Helix Core instance."
}

output "helix_core_eip_public_ip" {
  value       = aws_eip.helix_core_eip[0].public_ip
  description = "The public IP of your Helix Core instance."
}

output "helix_core_eip_id" {
  value       = aws_eip.helix_core_eip[0].id
  description = "The ID of the Elastic IP associated with your Helix Core instance."
}

output "security_group_id" {
  value       = var.create_default_sg ? aws_security_group.helix_core_security_group[0].id : null
  description = "The default security group of your Helix Core instance."
}

output "helix_core_super_user_username_secret_arn" {
  value       = var.helix_core_super_user_username_secret_arn == null ? awscc_secretsmanager_secret.helix_core_super_user_username[0].secret_id : var.helix_core_super_user_username_secret_arn
  description = "The ARN of the AWS Secrets Manager secret holding your Helix Core super user's username."
}

output "helix_core_super_user_password_secret_arn" {
  value       = var.helix_core_super_user_password_secret_arn == null ? awscc_secretsmanager_secret.helix_core_super_user_password[0].secret_id : var.helix_core_super_user_password_secret_arn
  description = "The ARN of the AWS Secrets Manager secret holding your Helix Core super user's password."
}

output "helix_core_instance_id" {
  value       = aws_instance.helix_core_instance.id
  description = "Instance ID for the Helix Core instance"
}