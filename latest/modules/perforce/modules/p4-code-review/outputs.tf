output "service_security_group_id" {
  value       = aws_security_group.ecs_service.id
  description = "Security group associated with the ECS service running P4 Code Review"
}

output "alb_security_group_id" {
  value       = var.create_application_load_balancer ? aws_security_group.alb[0].id : null
  description = "Security group associated with the P4 Code Review load balancer"
}

output "cluster_name" {
  value       = var.cluster_name != null ? var.cluster_name : aws_ecs_cluster.cluster[0].name
  description = "Name of the ECS cluster hosting P4 Code Review"
}

output "alb_dns_name" {
  value       = var.create_application_load_balancer ? aws_lb.alb[0].dns_name : null
  description = "The DNS name of the P4 Code Review ALB"
}

output "alb_zone_id" {
  value       = var.create_application_load_balancer ? aws_lb.alb[0].zone_id : null
  description = "The hosted zone ID of the P4 Code Review ALB"
}

output "target_group_arn" {
  value       = aws_lb_target_group.alb_target_group.arn
  description = "The service target group for P4 Code Review"
}

output "default_role_id" {
  value       = var.create_default_role ? aws_iam_role.default_role[0].id : null
  description = "The default role for the service task"
}

output "execution_role_id" {
  value       = aws_iam_role.task_execution_role.id
  description = "The default role for the service task"
}
