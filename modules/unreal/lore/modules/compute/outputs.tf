output "task_role_arn" {
  description = "ARN of the ECS task IAM role"
  value       = aws_iam_role.task.arn
}

output "execution_role_arn" {
  description = "ARN of the ECS execution IAM role"
  value       = aws_iam_role.execution.arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "capacity_provider_name" {
  description = "Name of the EC2 capacity provider"
  value       = aws_ecs_capacity_provider.ec2.name
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.loreserver.name
}

output "task_definition_arn" {
  description = "ARN of the loreserver task definition"
  value       = aws_ecs_task_definition.loreserver.arn
}

# =============================================================================
# Phase 6: Security & Observability
# =============================================================================

output "tls_ca_cert_pem" {
  description = "CA certificate PEM for client trust configuration. Null when using external certs."
  value       = try(tls_self_signed_cert.ca[0].cert_pem, null)
}

output "effective_asg_config" {
  description = "Resolved ASG sizing after environment-aware defaults"
  value = {
    min_size     = aws_autoscaling_group.ecs.min_size
    max_size     = aws_autoscaling_group.ecs.max_size
    desired_size = aws_autoscaling_group.ecs.desired_capacity
  }
}

output "cpu_architecture" {
  description = "CPU architecture for ECS tasks (ARM64 or X86_64)"
  value       = local.is_arm64 ? "ARM64" : "X86_64"
}

output "cache_max_size_bytes" {
  description = "Auto-calculated NVMe cache size in bytes (80% of instance store)"
  value       = local.cache_max_size
}
