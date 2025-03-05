output "external_alb_dns_name" {
  value       = var.create_external_alb ? aws_lb.teamcity_external_lb[0].dns_name : null
  description = "DNS endpoint of Application Load Balancer (ALB)"
}

output "external_alb_zone_id" {
  value       = var.create_external_alb ? aws_lb.teamcity_external_lb[0].zone_id : null
  description = "Zone ID for internet facing load balancer"
}
