output "service_security_group_id" {
  description = "Security group associated with the ECS service running swarm"
  value       = aws_security_group.helix_swarm_service_sg.id
}

output "alb_security_group_id" {
  description = "Security group associated with the swarm load balancer"
  value       = var.create_application_load_balancer ? aws_security_group.helix_swarm_alb_sg[0].id : null
}

output "cluster_name" {
  description = "Name of the ECS cluster hosting Swarm"
  value       = var.cluster_name != null ? var.cluster_name : aws_ecs_cluster.helix_swarm_cluster[0].name
}

output "alb_dns_name" {
  description = "The DNS name of the Swarm ALB"
  value       = var.create_application_load_balancer ? aws_lb.helix_swarm_alb[0].dns_name : null
}

output "alb_zone_id" {
  description = "The hosted zone ID of the Swarm ALB"
  value       = var.create_application_load_balancer ? aws_lb.helix_swarm_alb[0].zone_id : null
}

output "target_group_arn" {
  value       = aws_lb_target_group.helix_swarm_alb_target_group.arn
  description = "The ARN of the Helix Swarm service target group."
}
