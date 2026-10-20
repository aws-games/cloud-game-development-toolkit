output "vpc_id" {
  description = "VPC ID of the regional tier"
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

output "tier_security_group_id" {
  description = "Security group of the tier tasks (attach edge pods to it with server_security_group_id)"
  value       = aws_security_group.tier.id
}

output "tier_dns_name" {
  description = "Cloud Map DNS name of this tier. Give it to the write region as a replication peer, and to this office's clients and edge pods."
  value       = local.tier_dns_name
}

output "service_discovery_hosted_zone_id" {
  description = "Route 53 private hosted zone behind this tier's Cloud Map namespace. Associate it with the write region's VPC so the write tier can resolve tier_dns_name."
  value       = aws_service_discovery_private_dns_namespace.tier.hosted_zone
}

output "ca_certificate_pem" {
  description = "This tier's CA certificate. Give it to the write region as trusted_ca_pem so it can replicate here over TLS."
  value       = module.compute.tls_ca_cert_pem
}

output "fragment_bucket_name" {
  description = "This region's fragments bucket"
  value       = module.data.fragment_bucket_name
}

output "fragment_bucket_arn" {
  description = "This region's fragments bucket ARN, for the write region's fragment_replication.destination_bucket_arn"
  value       = module.data.fragment_bucket_arn
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.compute.ecs_cluster_name
}

output "task_role_arn" {
  description = "ECS task role ARN"
  value       = module.compute.task_role_arn
}
