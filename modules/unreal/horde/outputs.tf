output "external_alb_dns_name" {
  value = aws_lb.unreal_horde_external_alb[0].dns_name
}

output "external_alb_zone_id" {
  value = aws_lb.unreal_horde_external_alb[0].zone_id
}

output "external_alb_sg_id" {
  value = aws_security_group.unreal_horde_external_alb_sg[0].id
}

output "internal_alb_dns_name" {
  value = aws_lb.unreal_horde_internal_alb[0].dns_name
}

output "internal_alb_zone_id" {
  value = aws_lb.unreal_horde_internal_alb[0].zone_id
}

output "internal_alb_sg_id" {
  value = aws_security_group.unreal_horde_internal_alb_sg[0].id
}

output "service_security_group_id" {
  value = aws_security_group.unreal_horde_sg.id
}

output "agent_security_group_id" {
  value = aws_security_group.unreal_horde_agent_sg[0].id
}
