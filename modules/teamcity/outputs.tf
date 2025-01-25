output "external_alb_dns_name" {
  value = aws_lb.teamcity_external_lb.dns_name
}

output "external_alb_zone_id" {
  value = aws_lb.teamcity_external_lb.zone_id
}
