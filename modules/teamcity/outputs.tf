output "external_alb_dns_name" {
  value       = aws_lb.teamcity_external_lb.dns_name
  description = "DNS endpoint of Application Load Balancer (ALB)"
}

output "external_alb_zone_id" {
  value       = aws_lb.teamcity_external_lb.zone_id
  description = "Zone ID for internet facing load balancer"
}
