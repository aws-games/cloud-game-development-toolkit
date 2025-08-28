# Primary region outputs
output "primary_region" {
  description = "Primary region deployment information"
  value = {
    region           = var.regions[0]
    vpc_id           = aws_vpc.primary.id
    eks_cluster_name = module.unreal_cloud_ddc.primary_region.eks_cluster_name
    eks_endpoint     = module.unreal_cloud_ddc.primary_region.eks_endpoint
    scylla_ips       = module.unreal_cloud_ddc.primary_region.scylla_ips
    s3_bucket_id     = module.unreal_cloud_ddc.primary_region.s3_bucket_id
    ddc_endpoint     = "https://ddc-primary.${var.route53_public_hosted_zone_name}"
    monitoring_url   = "https://monitoring-primary.ddc.${var.route53_public_hosted_zone_name}"
  }
}

# Secondary region outputs
output "secondary_region" {
  description = "Secondary region deployment information"
  value = {
    region           = var.regions[1]
    vpc_id           = aws_vpc.secondary.id
    eks_cluster_name = module.unreal_cloud_ddc.secondary_region.eks_cluster_name
    eks_endpoint     = module.unreal_cloud_ddc.secondary_region.eks_endpoint
    scylla_ips       = module.unreal_cloud_ddc.secondary_region.scylla_ips
    s3_bucket_id     = module.unreal_cloud_ddc.secondary_region.s3_bucket_id
    ddc_endpoint     = "https://ddc-secondary.${var.route53_public_hosted_zone_name}"
    monitoring_url   = "https://monitoring-secondary.ddc.${var.route53_public_hosted_zone_name}"
  }
}

# Network connectivity
output "vpc_peering" {
  description = "VPC peering connection information"
  value = {
    connection_id = aws_vpc_peering_connection.primary_to_secondary.id
    status        = aws_vpc_peering_connection.primary_to_secondary.accept_status
  }
}

# kubectl commands
output "kubectl_commands" {
  description = "Commands to configure kubectl for both regions"
  value = {
    primary   = "aws eks update-kubeconfig --region ${var.regions[0]} --name ${module.unreal_cloud_ddc.primary_region.eks_cluster_name}"
    secondary = "aws eks update-kubeconfig --region ${var.regions[1]} --name ${module.unreal_cloud_ddc.secondary_region.eks_cluster_name}"
  }
}

# Deployment summary
output "deployment_summary" {
  description = "Multi-region deployment summary"
  value = {
    project_prefix = var.project_prefix
    environment    = var.environment
    regions        = var.regions
    vpc_cidrs = {
      primary   = var.vpc_cidr_region_1
      secondary = var.vpc_cidr_region_2
    }
    dns_zone = var.route53_public_hosted_zone_name
  }
}