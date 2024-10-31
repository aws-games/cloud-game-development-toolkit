output "helix_core_eip_private_ips" {
  value       = { for k, v in aws_eip.helix_core_eip : k => v.private_ip }
  description = "Map of server types to their private IPs (for EIPs)."
}

output "helix_core_eip_public_ips" {
  value       = { for k, v in aws_eip.helix_core_eip : k => v.public_ip }
  description = "Map of server types to their public IPs."
}

output "helix_core_eip_ids" {
  value       = { for k, v in aws_eip.helix_core_eip : k => v.id }
  description = "Map of server types to their Elastic IP IDs."
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

output "helix_core_instance_ids" {
  value       = { for k, v in aws_instance.helix_core_instance : k => v.id }
  description = "Map of server types to their EC2 instance IDs."
}

output "helix_core_private_ips" {
  value       = { for k, v in aws_instance.helix_core_instance : k => v.private_ip }
  description = "Map of server types to their private IP addresses."
}

output "ebs_volume_ids" {
  value = {
    logs     = { for k, v in aws_ebs_volume.logs : k => v.id }
    metadata = { for k, v in aws_ebs_volume.metadata : k => v.id }
    depot    = { for k, v in aws_ebs_volume.depot : k => v.id }
  }
  description = "Map of EBS volume types and server types to their volume IDs."
}
