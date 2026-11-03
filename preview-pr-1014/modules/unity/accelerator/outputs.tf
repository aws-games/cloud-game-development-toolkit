output "alb_dns_name" {
  value       = var.create_alb ? aws_lb.unity_accelerator_external_alb[0].dns_name : null
  description = "DNS endpoint of Application Load Balancer (ALB)"
}

output "alb_zone_id" {
  value       = var.create_alb ? aws_lb.unity_accelerator_external_alb[0].zone_id : null
  description = "Zone ID for Application Load Balancer (ALB)"
}

output "alb_security_group_id" {
  value       = var.create_alb ? aws_security_group.unity_accelerator_alb_sg[0].id : null
  description = "ID of the Application Load Balancer's (ALB) security group"
}

output "nlb_dns_name" {
  value       = var.create_nlb ? aws_lb.unity_accelerator_external_nlb[0].dns_name : null
  description = "DNS endpoint of Network Load Balancer (NLB)"
}

output "nlb_zone_id" {
  value       = var.create_nlb ? aws_lb.unity_accelerator_external_nlb[0].zone_id : null
  description = "Zone ID for Network Load Balancer (NLB)"
}

output "unity_accelerator_dashboard_username_arn" {
  value       = local.dashboard_username_secret
  description = "AWS Secrets Manager secret's ARN containing the Unity Accelerator web dashboard's password."
}

output "unity_accelerator_dashboard_password_arn" {
  value       = local.dashboard_password_secret
  description = "AWS Secrets Manager secret's ARN containing the Unity Accelerator web dashboard's username."
}
