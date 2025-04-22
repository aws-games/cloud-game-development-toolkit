output "service_security_group_id" {
  description = "Security group associated with the ECS service running Helix Authentication Service"
  value       = aws_security_group.helix_authentication_service_sg.id
}

output "alb_security_group_id" {
  description = "Security group associated with the Helix Authentication Service load balancer"
  value       = var.create_application_load_balancer ? aws_security_group.helix_authentication_service_alb_sg[0].id : null
}

output "cluster_name" {
  description = "Name of the ECS cluster hosting helix_authentication_service"
  value = (var.cluster_name != null ? var.cluster_name :
  aws_ecs_cluster.helix_authentication_service_cluster[0].name)
}

output "alb_dns_name" {
  description = "The DNS name of the Helix Authentication Service ALB"
  value       = var.create_application_load_balancer ? aws_lb.helix_authentication_service_alb[0].dns_name : null
}

output "alb_zone_id" {
  description = "The hosted zone ID of the Helix Authentication Service ALB"
  value       = var.create_application_load_balancer ? aws_lb.helix_authentication_service_alb[0].zone_id : null
}

output "target_group_arn" {
  value       = aws_lb_target_group.helix_authentication_service_alb_target_group.arn
  description = "The service target group for the Helix Authentication Service."
}
