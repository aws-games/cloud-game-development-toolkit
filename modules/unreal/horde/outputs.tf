output "external_alb_dns_name" {
  value = var.create_external_alb ? aws_lb.unreal_horde_external_alb[0].dns_name : null
}

output "external_alb_zone_id" {
  value = var.create_external_alb ? aws_lb.unreal_horde_external_alb[0].zone_id : null
}

output "external_alb_sg_id" {
  value = var.create_external_alb ? aws_security_group.unreal_horde_external_alb_sg[0].id : null
}

output "internal_alb_dns_name" {
  value = var.create_internal_alb ? aws_lb.unreal_horde_internal_alb[0].dns_name : null
}

output "internal_alb_zone_id" {
  value = var.create_internal_alb ? aws_lb.unreal_horde_internal_alb[0].zone_id : null
}

output "internal_alb_sg_id" {
  value = var.create_internal_alb ? aws_security_group.unreal_horde_internal_alb_sg[0].id : null
}

output "service_security_group_id" {
  value = aws_security_group.unreal_horde_sg.id
}

output "agent_security_group_id" {
  value = length(var.agents) > 0 ? aws_security_group.unreal_horde_agent_sg[0].id : null
}
