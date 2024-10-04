output "external_alb_dns_name" {
  value = var.create_external_alb ? aws_lb.helix_authentication_service_external_alb[0].dns_name : null
}

output "internal_alb_dns_name" {
  value = var.create_internal_alb ? aws_lb.helix_authentication_service_internal_alb[0].dns_name : null
}

output "external_alb_zone_id" {
  value = var.create_external_alb ? aws_lb.helix_authentication_service_external_alb[0].zone_id : null
}

output "internal_alb_zone_id" {
  value = var.create_internal_alb ? aws_lb.helix_authentication_service_internal_alb[0].zone_id : null
}

output "external_alb_security_group_id" {
  value = var.create_external_alb ? aws_security_group.helix_authentication_service_external_alb_sg[0].id : null
}

output "internal_alb_security_group_id" {
  value = var.create_internal_alb ? aws_security_group.helix_authentication_service_internal_alb_sg[0].id : null
}

output "service_security_group_id" {
  description = "Security group associated with the ECS service running Helix Authentication Service"
  value       = aws_security_group.helix_authentication_service_sg.id
}
