output "service_security_group_id" {
  description = "Security group associated with the ECS service running HAS"
  value       = aws_security_group.HAS_service_sg.id
}

output "alb_security_group_id" {
  description = "Security group associated with the HAS load balancer"
  value       = aws_security_group.HAS_alb_sg.id
}

output "cluster_name" {
  description = "Name of the ECS cluster hosting HAS"
  value       = var.cluster_name != null ? var.cluster_name : aws_ecs_cluster.HAS_cluster[0].name
}

output "alb_dns_name" {
  description = "The DNS name of the HAS ALB"
  value       = aws_lb.HAS_alb.dns_name
}

output "alb_zone_id" {
  description = "The hosted zone ID of the HAS ALB"
  value       = aws_lb.HAS_alb.zone_id
}
