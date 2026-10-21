output "vpc_id" {
  description = "VPC ID of the regional cache"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR, for the write region's replication_ingress_cidrs"
  value       = var.vpc_cidr
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
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
  description = "This cache's CA certificate. Give it to the write region as trusted_ca_pem so it can push fragments here over TLS."
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

