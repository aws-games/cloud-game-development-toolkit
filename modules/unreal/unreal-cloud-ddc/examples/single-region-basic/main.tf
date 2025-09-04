module "unreal_cloud_ddc" {
  source = "../../"

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  scylla_config = {
    current_region = {
      replication_factor = 3
      node_count = 3
    }
    enable_cross_region_replication = false  # Single region
  }

  # - Shared -
  region = local.primary_region
  existing_vpc_id = aws_vpc.unreal_cloud_ddc_vpc.id
  existing_load_balancer_subnets = aws_subnet.public_subnets[*].id
  existing_service_subnets = aws_subnet.private_subnets[*].id
  existing_security_groups = [aws_security_group.allow_my_ip.id]

  # DNS Configuration
  existing_route53_public_hosted_zone_name = var.route53_public_hosted_zone_name
  existing_certificate_arn = aws_acm_certificate.ddc.arn

  # - DDC Infra Configuration -
  ddc_infra_config = {
    region = local.primary_region
    eks_node_group_subnets = aws_subnet.private_subnets[*].id
    eks_api_access_cidrs   = ["${chomp(data.http.my_ip.response_body)}/32"]
    scylla_subnets = aws_subnet.private_subnets[*].id
    scylla_replication_factor = 3
  }

  # - DDC Services Configuration -
  ddc_services_config = {
    region = local.primary_region
    ghcr_credentials_secret_manager_arn = var.ghcr_credentials_secret_manager_arn
  }
}
