# Shared
output "shared_network_load_balancer_arn" {
  value       = var.create_shared_network_load_balancer ? aws_lb.perforce[0].arn : null
  description = "The ARN of the shared network load balancer."
}
output "shared_application_load_balancer_arn" {
  value       = var.create_shared_application_load_balancer ? aws_lb.perforce_web_services[0].arn : null
  description = "The ARN of the shared application load balancer."
}

# P4 Server
output "p4_server_eip_public_ip" {
  value       = var.p4_server_config != null ? module.p4_server[0].eip_public_ip : null
  description = "The public IP of your P4 Server instance."
}

output "p4_server_eip_id" {
  value       = var.p4_server_config != null ? module.p4_server[0].eip_id : null
  description = "The ID of the Elastic IP associated with your P4 Server instance."
}

output "p4_server_security_group_id" {
  value       = var.p4_server_config != null ? module.p4_server[0].security_group_id : null
  description = "The default security group of your P4 Server instance."
}

output "p4_server_super_user_password_secret_arn" {
  value       = var.p4_server_config != null ? module.p4_server[0].super_user_password_secret_arn : null
  description = "The ARN of the AWS Secrets Manager secret holding your P4 Server super user's username."
}

output "p4_server_super_user_username_secret_arn" {
  value       = var.p4_server_config != null ? module.p4_server[0].super_user_username_secret_arn : null
  description = "The ARN of the AWS Secrets Manager secret holding your P4 Server super user's password."
}

output "p4_server_instance_id" {
  value       = var.p4_server_config != null ? module.p4_server[0].instance_id : null
  description = "Instance ID for the P4 Server instance"
}

output "p4_server_private_ip" {
  value       = var.p4_server_config != null ? module.p4_server[0].private_ip : null
  description = "Private IP for the P4 Server instance"
}

# P4Auth
output "p4_auth_service_security_group_id" {
  value       = var.p4_auth_config != null ? module.p4_auth[0].service_security_group_id : null
  description = "Security group associated with the ECS service running P4Auth."
}

output "p4_auth_alb_security_group_id" {
  value       = var.p4_auth_config != null ? module.p4_auth[0].alb_security_group_id : null
  description = "Security group associated with the P4Auth load balancer."
}

output "p4_auth_perforce_cluster_name" {
  value       = var.p4_auth_config != null ? module.p4_auth[0].cluster_name : null
  description = "Name of the ECS cluster hosting P4Auth."
}

output "p4_auth_alb_dns_name" {
  value       = var.p4_auth_config != null ? module.p4_auth[0].alb_dns_name : null
  description = "The DNS name of the P4Auth ALB."
}

output "p4_auth_alb_zone_id" {
  value       = var.p4_auth_config != null ? module.p4_auth[0].alb_zone_id : null
  description = "The hosted zone ID of the P4Auth ALB."
}

output "p4_auth_target_group_arn" {
  value       = var.p4_auth_config != null ? module.p4_auth[0].target_group_arn : null
  description = "The service target group for the P4Auth."
}


# P4 Code Review
output "p4_code_review_service_security_group_id" {
  value       = var.p4_code_review_config != null ? module.p4_code_review[0].service_security_group_id : null
  description = "Security group associated with the ECS service running P4 Code Review."
}

output "p4_code_review_alb_security_group_id" {
  value       = var.p4_code_review_config != null ? module.p4_code_review[0].alb_security_group_id : null
  description = "Security group associated with the P4 Code Review load balancer."
}

output "p4_code_review_perforce_cluster_name" {
  value       = var.p4_code_review_config != null ? module.p4_code_review[0].cluster_name : null
  description = "Name of the ECS cluster hosting P4 Code Review."
}

output "p4_code_review_alb_dns_name" {
  value       = var.p4_code_review_config != null ? module.p4_code_review[0].alb_dns_name : null
  description = "The DNS name of the P4 Code Review ALB."
}

output "p4_code_review_alb_zone_id" {
  value       = var.p4_code_review_config != null ? module.p4_code_review[0].alb_zone_id : null
  description = "The hosted zone ID of the P4 Code Review ALB."
}

output "p4_code_review_target_group_arn" {
  value       = var.p4_code_review_config != null ? module.p4_code_review[0].target_group_arn : null
  description = "The service target group for the P4 Code Review."
}

output "p4_code_review_default_role_id" {
  value       = var.p4_code_review_config != null ? module.p4_code_review[0].default_role_id : null
  description = "The default role for the P4 Code Review service task"
}

output "p4_code_review_execution_role_id" {
  value       = var.p4_code_review_config != null ? module.p4_code_review[0].execution_role_id : null
  description = "The default role for the P4 Code Review service task"
}

output "p4_server_lambda_link_name" {
  value = (var.p4_server_config.storage_type == "FSxN" && var.p4_server_config.protocol == "ISCSI" ?
  module.p4_server[0].lambda_link_name : null)
  description = "The name of the Lambda link for the P4 Server instance to use with FSxN."
}
