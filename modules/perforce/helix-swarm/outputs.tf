output "service_security_group_id" {
  description = "Security group associated with the ECS service running swarm"
  value       = aws_security_group.swarm_service_sg.id
}

output "alb_security_group_id" {
  description = "Security group associated with the swarm load balancer"
  value       = aws_security_group.swarm_alb_sg.id
}

output "cluster_name" {
  description = "Name of the ECS cluster hosting Swarm"
  value       = var.cluster_name != null ? var.cluster_name : aws_ecs_cluster.swarm_cluster[0].name
}

output "alb_dns_name" {
  description = "The DNS name of the Swarm ALB"
  value       = aws_lb.swarm_alb.dns_name
}

output "alb_zone_id" {
  description = "The hosted zone ID of the Swarm ALB"
  value       = aws_lb.swarm_alb.zone_id
}

