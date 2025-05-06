# Shared
output "shared_network_load_balancer_arn" {
  value       = aws_lb.perforce[0].arn
  description = "The ARN of the shared network load balancer."
}
output "shared_application_load_balancer_arn" {
  value       = aws_lb.perforce[0].arn
  description = "The ARN of the shared application load balancer."
}

# P4 Server
output "p4_server_eip_public_ip" {
  value       = module.p4_server[0].eip_public_ip
  description = "The public IP of your P4 Server instance."
}

output "p4_server_eip_id" {
  value       = module.p4_server[0].eip_id
  description = "The ID of the Elastic IP associated with your P4 Server instance."
}

output "security_group_id" {
  value       = module.p4_server[0].security_group_id
  description = "The default security group of your P4 Server instance."
}

output "p4_server_super_user_password_secret_arn" {
  value       = module.p4_server[0].super_user_password_secret_arn
  description = "The ARN of the AWS Secrets Manager secret holding your P4 Server super user's username."
}

output "p4_server_super_user_username_secret_arn" {
  value       = module.p4_server[0].super_user_username_secret_arn
  description = "The ARN of the AWS Secrets Manager secret holding your P4 Server super user's password."
}

output "p4_server_instance_id" {
  value       = module.p4_server[0].instance_id
  description = "Instance ID for the P4 Server instance"
}

output "p4_server_private_ip" {
  value       = module.p4_server[0].private_ip
  description = "Private IP for the P4 Server instance"
}


# P4Auth
output "p4_auth_service_security_group_id" {
  value       = module.p4_auth[0].service_security_group_id
  description = "Security group associated with the ECS service running P4Auth."
}

output "p4_auth_alb_security_group_id" {
  value       = module.p4_auth[0].alb_security_group_id
  description = "Security group associated with the P4Auth load balancer."
}

output "p4_auth_perforce_cluster_name" {
  value       = module.p4_auth[0].cluster_name
  description = "Name of the ECS cluster hosting P4Auth."
}

output "p4_auth_alb_dns_name" {
  value       = module.p4_auth[0].alb_dns_name
  description = "The DNS name of the P4Auth ALB."
}

output "p4_auth_alb_zone_id" {
  value       = module.p4_auth[0].alb_zone_id
  description = "The hosted zone ID of the P4Auth ALB."
}

output "p4_auth_target_group_arn" {
  value       = module.p4_auth[0].target_group_arn
  description = "The service target group for the P4Auth."
}


# P4 Code Review
output "p4_code_review_service_security_group_id" {
  value       = module.p4_code_review[0].service_security_group_id
  description = "Security group associated with the ECS service running P4 Code Review."
}

output "p4_code_review_alb_security_group_id" {
  value       = module.p4_code_review[0].alb_security_group_id
  description = "Security group associated with the P4 Code Review load balancer."
}

output "p4_code_review_perforce_cluster_name" {
  value       = module.p4_code_review[0].cluster_name
  description = "Name of the ECS cluster hosting P4 Code Review."
}

output "p4_code_review_alb_dns_name" {
  value       = module.p4_code_review[0].alb_dns_name
  description = "The DNS name of the P4 Code Review ALB."
}

output "p4_code_review_alb_zone_id" {
  value       = module.p4_code_review[0].alb_zone_id
  description = "The hosted zone ID of the P4 Code Review ALB."
}

output "p4_code_review_target_group_arn" {
  value       = module.p4_code_review[0].target_group_arn
  description = "The service target group for the P4 Code Review."
}

output "p4_server_lambda_link_name" {
  value = (var.p4_server_config.storage_type == "FSxN" && var.p4_server_config.protocol == "ISCSI" ?
  module.p4_server.lambda_link_name : null)
  description = "The name of the Lambda link for the P4 Server instance to use with FSxN."
}
