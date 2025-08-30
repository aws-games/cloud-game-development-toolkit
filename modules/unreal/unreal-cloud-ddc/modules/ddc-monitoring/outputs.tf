################################################################################
# DDC Monitoring Module Outputs
################################################################################

output "scylla_monitoring_instance_id" {
  description = "ID of the ScyllaDB monitoring instance"
  value       = var.create_scylla_monitoring_stack ? aws_instance.scylla_monitoring[0].id : null
}

output "scylla_monitoring_instance_private_ip" {
  description = "Private IP of the ScyllaDB monitoring instance"
  value       = var.create_scylla_monitoring_stack ? aws_instance.scylla_monitoring[0].private_ip : null
}

output "scylla_monitoring_alb_arn" {
  description = "ARN of the ScyllaDB monitoring Application Load Balancer"
  value       = var.create_scylla_monitoring_stack && var.create_application_load_balancer ? aws_lb.scylla_monitoring_alb[0].arn : null
}

output "scylla_monitoring_alb_dns_name" {
  description = "DNS name of the ScyllaDB monitoring Application Load Balancer"
  value       = var.create_scylla_monitoring_stack && var.create_application_load_balancer ? aws_lb.scylla_monitoring_alb[0].dns_name : null
}

output "scylla_monitoring_alb_zone_id" {
  description = "Zone ID of the ScyllaDB monitoring Application Load Balancer"
  value       = var.create_scylla_monitoring_stack && var.create_application_load_balancer ? aws_lb.scylla_monitoring_alb[0].zone_id : null
}

output "scylla_monitoring_security_group_id" {
  description = "ID of the ScyllaDB monitoring security group"
  value       = var.create_scylla_monitoring_stack ? aws_security_group.scylla_monitoring_sg[0].id : null
}

output "scylla_monitoring_lb_security_group_id" {
  description = "ID of the ScyllaDB monitoring load balancer security group"
  value       = var.create_scylla_monitoring_stack && var.create_application_load_balancer ? aws_security_group.scylla_monitoring_lb_sg[0].id : null
}