module "unreal_cloud_ddc" {
  source = "../../.."

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  # TIER 1: Core Infrastructure
  vpc_id = aws_vpc.unreal_cloud_ddc_vpc.id
  
  load_balancers_config = {
    nlb = {
      internet_facing = true
      subnets         = aws_subnet.public_subnets[*].id
      security_groups = [aws_security_group.allow_my_ip.id, aws_security_group.client_vpn.id]
    }
  }

  # TIER 2: Optional Configuration
  route53_hosted_zone_name = var.route53_public_hosted_zone_name
  certificate_arn          = aws_acm_certificate.ddc.arn
  allowed_external_cidrs   = [local.my_ip_cidr]

  # TIER 3: Advanced Configuration
  ddc_infra_config = {
    region                 = local.region
    eks_node_group_subnets = aws_subnet.private_subnets[*].id
    
    eks_access_config = {
      mode = "private"
      private = {
        security_groups = [aws_security_group.allow_my_ip.id, aws_security_group.client_vpn.id]
      }
    }
    
    scylla_config = {
      current_region = {
        replication_factor = 3
        node_count         = 3
      }
      subnets = aws_subnet.private_subnets[*].id
      enable_cross_region_replication = false
    }
  }

  ddc_app_config = {
    region                              = local.region
    ghcr_credentials_secret_manager_arn = var.ghcr_credentials_secret_manager_arn
  }
}