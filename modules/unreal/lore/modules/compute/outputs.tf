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
  description = "Generated CA certificate PEM for client trust configuration. Null when using external certificates."
  value       = try(tls_self_signed_cert.ca[0].cert_pem, null)
}

output "tls_ca_secret_arn" {
  description = "Secrets Manager ARN holding the CA certificate bundle used by this tier."
  value       = local.tls_ca_secret_arn
}

output "replication_client_certificate_secret_arn" {
  description = "Secrets Manager ARN holding this tier's dedicated mTLS client certificate. Null when the tier has no outgoing replication client."
  value       = local.tls_client_cert_secret_arn
}

output "replication_client_private_key_secret_arn" {
  description = "Secrets Manager ARN holding this tier's dedicated mTLS client private key. Null when the tier has no outgoing replication client."
  value       = local.tls_client_key_secret_arn
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

output "topology_toml" {
  description = "Rendered Lore topology overlay (empty when no replication peers)"
  value       = local.topology_toml
}

output "store_env_vars" {
  description = "Store-wiring environment variables handed to loreserver (immutable, mutable, lock, DynamoDB endpoint). For tests and debugging."
  value       = concat(local.common_env_vars, local.immutable_store_env_vars, local.mutable_store_env_vars, local.lock_store_env_vars)
}

output "listener_env_vars" {
  description = "Auth and replication-listener environment variables handed to loreserver. For tests and debugging."
  value       = concat(local.auth_env_vars, local.auth_audience_env, local.replication_env_vars)
}

output "replication_client_allowed_uses" {
  description = "Extended key usages on the generated replication-client certificate. Empty with custom TLS or no outgoing replication client; exposed for tests."
  value       = try(tls_locally_signed_cert.replication_client[0].allowed_uses, [])
}

output "peer_ca_added_to_system_trust" {
  description = "Whether peer CAs are appended to SSL_CERT_FILE for the remote mutable-store client. Replication-only CAs stay scoped to port 41340."
  value       = var.trusted_ca_pem != null && var.mutable_store_mode == "remote"
}

output "tls_material_revision" {
  description = "Non-secret rollout token embedded in the ECS task definition. Generated TLS derives it from certificates; custom TLS uses tls_material_version."
  value       = local.tls_material_revision
}
