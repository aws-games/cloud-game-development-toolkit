output "external_alb_dns_name" {
  value       = var.create_external_alb ? aws_lb.teamcity_external_lb[0].dns_name : null
  description = "DNS endpoint of Application Load Balancer (ALB)"
}

output "external_alb_zone_id" {
  value       = var.create_external_alb ? aws_lb.teamcity_external_lb[0].zone_id : null
  description = "Zone ID for internet facing load balancer"
}

output "security_group_id" {
  value       = aws_security_group.teamcity_service_sg.id
  description = "The default security group of your Teamcity service."
}

output "teamcity_cluster_id" {
  value       = var.cluster_name != null ? data.aws_ecs_cluster.teamcity_cluster[0].id : aws_ecs_cluster.teamcity_cluster[0].id
  description = "The ID of the ECS cluster"
}
