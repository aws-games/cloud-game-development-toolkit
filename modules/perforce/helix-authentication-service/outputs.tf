output "service_security_group_id" {
  description = "Security group associated with the ECS service running Helix Authentication Service"
  value       = aws_security_group.helix_authentication_service_sg.id
}

output "alb_security_group_id" {
  description = "Security group associated with the Helix Authentication Service load balancer"
  value       = aws_security_group.helix_authentication_service_alb_sg.id
}

output "cluster_name" {
  description = "Name of the ECS cluster hosting helix_authentication_service"
  value = (var.cluster_name != null ? var.cluster_name :
  aws_ecs_cluster.helix_authentication_service_cluster[0].name)
}

output "alb_dns_name" {
  description = "The DNS name of the Helix Authentication Service ALB"
  value       = aws_lb.helix_authentication_service_alb.dns_name
}

output "alb_zone_id" {
  description = "The hosted zone ID of the Helix Authentication Service ALB"
  value       = aws_lb.helix_authentication_service_alb.zone_id
}

output "alb_arn" {
  value       = aws_lb.helix_authentication_service_alb.arn
  description = "The ARN of the Helix Authentication Service application load balancer."
}
