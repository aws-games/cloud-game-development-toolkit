# =============================================================================
# Connection (what clients need)
# =============================================================================

output "ca_certificate_pem" {
  description = "CA certificate PEM — add to client SSL_CERT_FILE bundle for TLS trust"
  value       = module.compute.tls_ca_cert_pem
}

# =============================================================================
# Edge Pod Wiring (pass these to modules/edge-pod)
# =============================================================================

output "vpc_id" {
  description = "VPC ID for placing edge pods"
  value       = local.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs for placing edge pods"
  value       = local.private_subnet_ids
}

output "server_security_group_id" {
  description = "Security group ID — edge pods need ingress to this group"
  value       = aws_security_group.server.id
}

output "write_tier_discovery_dns" {
  description = "Cloud Map DNS for edge pod → write tier (gRPC:41337 + QUIC:41340)"
  value       = "write-tier.${local.name_prefix}.internal"
}

# =============================================================================
# Auth (when auth_mode = "cognito")
# =============================================================================

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID (null when auth_mode != 'cognito')"
  value       = try(module.auth[0].user_pool_id, null)
}

output "cognito_client_id" {
  description = "Cognito app client ID (null when auth_mode != 'cognito')"
  value       = try(module.auth[0].client_id, null)
}

output "cognito_client_secret" {
  description = "Cognito app client secret (null when auth_mode != 'cognito')"
  value       = try(module.auth[0].client_secret, null)
  sensitive   = true
}

output "cognito_token_endpoint" {
  description = "Cognito OAuth2 token endpoint (null when auth_mode != 'cognito')"
  value       = try(module.auth[0].token_endpoint, null)
}

# =============================================================================
# Infrastructure (advanced integration, debugging, cross-module wiring)
# =============================================================================

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = local.public_subnet_ids
}

output "fragment_bucket_name" {
  description = "S3 bucket name for fragment storage"
  value       = module.data.fragment_bucket_name
}

output "fragment_bucket_arn" {
  description = "S3 bucket ARN for fragment storage"
  value       = module.data.fragment_bucket_arn
}

output "dynamodb_table_arns" {
  description = "Map of DynamoDB table ARNs"
  value = {
    fragments         = module.data.fragments_table_arn
    fragment_metadata = module.data.fragment_metadata_table_arn
    mutable_store     = module.data.mutable_store_table_arn
    locks             = module.data.locks_table_arn
  }
}

output "task_role_arn" {
  description = "ECS task IAM role ARN"
  value       = module.compute.task_role_arn
}

output "execution_role_arn" {
  description = "ECS execution IAM role ARN"
  value       = module.compute.execution_role_arn
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.compute.ecs_cluster_name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.compute.ecs_cluster_arn
}

output "cloud_map_namespace_id" {
  description = "Cloud Map namespace ID for edge pod service discovery"
  value       = aws_service_discovery_private_dns_namespace.lore.id
}

output "effective_config" {
  description = "Resolved configuration after environment-aware defaults"
  value = {
    name_prefix                = local.name_prefix
    environment                = var.environment
    instance_type              = var.instance_type
    asg                        = module.compute.effective_asg_config
    auth_mode                  = var.auth_mode
    enable_otel_sidecar        = var.enable_otel_sidecar
    enable_deletion_protection = var.enable_deletion_protection
  }
}

# =============================================================================
# Multi-region — what a tier in another region needs
# =============================================================================

output "write_tier_dns_name" {
  description = "Cloud Map DNS name of the write tier, for a regional cache's durable remote and replication peers"
  value       = "write-tier.${local.name_prefix}.internal"
}

output "service_discovery_hosted_zone_id" {
  description = "Route 53 private hosted zone behind the Cloud Map namespace. Associate it with a peered VPC (aws_route53_zone_association) so the write tier name resolves there."
  value       = aws_service_discovery_private_dns_namespace.lore.hosted_zone
}

output "vpc_cidr" {
  description = "CIDR of the VPC the write tier runs in, for peering routes (null when an existing VPC is supplied). Use private_subnet_cidrs for a regional cache's write_tier_replication_cidrs"
  value       = var.vpc_id == null ? var.vpc_cidr : null
}

output "private_route_table_id" {
  description = "Private route table of the module-created VPC, for peering routes (null when an existing VPC is supplied)"
  value       = var.vpc_id == null ? module.vpc[0].private_route_table_id : null
}

output "locks_table_name" {
  description = "DynamoDB locks table name. A regional cache uses this table so exclusive checkouts are shared across offices."
  value       = module.data.locks_table_name
}

output "locks_table_arn" {
  description = "DynamoDB locks table ARN, for a regional cache's IAM policy"
  value       = module.data.locks_table_arn
}

output "mutable_store_table_name" {
  description = "DynamoDB mutable-store table (branch pointers). A regional cache uses this table cross-region."
  value       = module.data.mutable_store_table_name
}

output "mutable_store_table_arn" {
  description = "DynamoDB mutable-store table ARN, for a regional cache's IAM policy"
  value       = module.data.mutable_store_table_arn
}

output "private_subnet_cidrs" {
  description = "CIDRs of the module-created private subnets the write tier runs in (null when an existing VPC is supplied). Give these to a regional cache as write_tier_replication_cidrs: port 41340 is protected only by network rules."
  value       = var.vpc_id == null ? module.vpc[0].private_subnet_cidrs : null
}

output "auth_jwk_endpoint" {
  description = "JWKS endpoint the write tier validates tokens against (Cognito or external; null when auth_mode = none). A regional cache uses it with auth_mode = external."
  value       = var.auth_mode == "none" ? null : (var.auth_mode == "cognito" ? module.auth[0].jwk_endpoint : var.auth_jwk_endpoint)
}

output "auth_jwt_issuer" {
  description = "JWT issuer the write tier accepts (null when auth_mode = none). A regional cache uses it with auth_mode = external."
  value       = var.auth_mode == "none" ? null : (var.auth_mode == "cognito" ? module.auth[0].issuer : var.auth_jwt_issuer)
}

output "dynamodb_interface_endpoint_url" {
  description = "Endpoint-specific HTTPS URL for the write VPC's DynamoDB interface endpoint. Pass it to regional-cache dynamodb_endpoint_url. Null when disabled."
  value       = local.dynamodb_interface_endpoint_enabled ? "https://${local.dynamodb_interface_endpoint_regional_dns_name}" : null

  # A cache task must not receive this URL before the endpoint admits its private subnet.
  depends_on = [aws_vpc_security_group_ingress_rule.dynamodb_interface_endpoint_https]
}

output "dynamodb_interface_endpoint_id" {
  description = "DynamoDB interface endpoint ID for flow and CloudTrail checks. Null when disabled."
  value       = try(aws_vpc_endpoint.dynamodb_interface[0].id, null)
}
