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

output "agent_launch_template_ids" {
  description = "Map of agent pool name to launch template ID. Useful for targeting SSM Associations by launch template."
  value       = { for k, lt in aws_launch_template.unreal_horde_agent_template : k => lt.id }
}

output "agent_instance_role_name" {
  description = "Name of the IAM role attached to Horde agent EC2 instances. Use to attach additional policies from a consuming module or sample."
  value       = length(var.agents) > 0 ? aws_iam_role.unreal_horde_agent_default_role[0].name : null
}

output "agent_instance_role_arn" {
  description = "ARN of the IAM role attached to Horde agent EC2 instances."
  value       = length(var.agents) > 0 ? aws_iam_role.unreal_horde_agent_default_role[0].arn : null
}
