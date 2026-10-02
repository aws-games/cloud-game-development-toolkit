output "eip_public_ip" {
  value       = var.internal ? null : aws_eip.server_eip[0].public_ip
  description = "The public IP of your P4 Server instance."
}

output "eip_id" {
  value       = var.internal ? null : aws_eip.server_eip[0].id
  description = "The ID of the Elastic IP associated with your P4 Server instance."
}

output "security_group_id" {
  value       = var.create_default_sg ? aws_security_group.default_security_group[0].id : null
  description = "The default security group of your P4 Server instance."
}

output "super_password_secret_arn" {
  value       = awscc_secretsmanager_secret.super_password.secret_id
  description = "The ARN of the AWS Secrets Manager secret holding the service account (super) password."
}

output "admin_username_secret_arn" {
  value       = awscc_secretsmanager_secret.admin_username.secret_id
  description = "The ARN of the AWS Secrets Manager secret holding the admin account username."
}

output "admin_password_secret_arn" {
  value = (var.admin_password_secret_arn == null ?
    awscc_secretsmanager_secret.admin_password[0].secret_id :
  var.admin_password_secret_arn)
  description = "The ARN of the AWS Secrets Manager secret holding the admin account password."
}

output "instance_id" {
  value       = aws_instance.server_instance.id
  description = "Instance ID for the P4 Server instance"
}

output "private_ip" {
  value       = aws_instance.server_instance.private_ip
  description = "Private IP for the P4 Server instance"
}

output "lambda_link_name" {
  value = (var.storage_type == "FSxN" && var.protocol == "ISCSI" ?
  aws_lambda_function.lambda_function[0].function_name : null)
  description = "Lambda function name for the FSxN Link"
}
