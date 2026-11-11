output "vpc_id" {
  description = "VPC ID of the regional cache"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR, for peering routes. Use private_subnet_cidrs, not this, for replication_ingress_cidrs"
  value       = var.vpc_cidr
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "private_subnet_cidrs" {
  description = "CIDRs of the private subnets the cache runs in. Give these to the write region as replication_ingress_cidrs; mTLS authenticates port 41340 peers and these CIDRs provide network defense in depth."
  value       = module.vpc.private_subnet_cidrs
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_route_table_id" {
  description = "Private route table, for the peering route to the write region"
  value       = module.vpc.private_route_table_id
}

output "cache_security_group_id" {
  description = "Security group of the cache tasks"
  value       = aws_security_group.tier.id
}

output "cache_dns_name" {
  description = "Cloud Map DNS name of this cache. Give it to the write region as a replication peer (OtherRegion) and to this office's clients."
  value       = local.tier_dns_name
}

output "service_discovery_hosted_zone_id" {
  description = "Route 53 private hosted zone behind this tier's Cloud Map namespace. Associate it with the write region's VPC so the write tier can resolve cache_dns_name."
  value       = aws_service_discovery_private_dns_namespace.tier.hosted_zone
}

output "ca_certificate_pem" {
  description = "Generated CA certificate for this cache's server and replication-client identities. Give it to the write region as trusted_ca_pem for mutual authentication. Null when custom TLS secrets are used."
  value       = module.compute.tls_ca_cert_pem
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.compute.ecs_cluster_name
}

output "task_role_arn" {
  description = "ECS task role ARN"
  value       = module.compute.task_role_arn
}


output "execution_role_arn" {
  description = "ECS task execution role ARN. Attach scoped kms:Decrypt permission here when custom TLS secrets use a customer-managed KMS key."
  value       = module.compute.execution_role_arn
}
