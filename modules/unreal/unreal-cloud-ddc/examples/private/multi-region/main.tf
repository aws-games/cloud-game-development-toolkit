# Multi-region DDC deployment - Private Access Mode

# Primary Region (us-east-1)
module "unreal_cloud_ddc_primary" {
  source = "../../.."
  
  providers = {
    kubernetes = kubernetes.primary
    helm       = helm.primary
  }
  
  # TIER 1: Core Infrastructure
  vpc_id = aws_vpc.primary.id
  
  load_balancers_config = {
    nlb = {
      internet_facing = true
      subnets         = aws_subnet.primary_public[*].id
      security_groups = [aws_security_group.allow_my_ip_primary.id]
    }
  }

  # TIER 2: Optional Configuration
  route53_hosted_zone_name = var.route53_public_hosted_zone_name
  certificate_arn          = aws_acm_certificate_validation.ddc.certificate_arn

  # TIER 3: Advanced Configuration
  is_primary_region = true
  create_bearer_token = true
  bearer_token_replica_regions = [local.secondary_region]

  ddc_infra_config = {
    region                 = local.primary_region
    eks_node_group_subnets = aws_subnet.primary_private[*].id
    
    eks_access_config = {
      mode = "private"
      private = {
        security_groups  = [aws_security_group.allow_my_ip_primary.id]
        create_proxy_nlb = true
        proxy_dns_name   = "eks.ddc"
      }
    }
    
    scylla_config = {
      current_region = {
        replication_factor = 3
        node_count         = 3
      }
      peer_regions = {
        "us-west-1" = {
          replication_factor = 2
        }
      }
      subnets = aws_subnet.primary_private[*].id
      enable_cross_region_replication = true
    }
  }

  ddc_app_config = {
    region                              = local.primary_region
    ghcr_credentials_secret_manager_arn = var.ghcr_credentials_secret_manager_arn
  }
}

# Secondary Region (us-west-1)
module "unreal_cloud_ddc_secondary" {
  source = "../../.."
  
  providers = {
    kubernetes = kubernetes.secondary
    helm       = helm.secondary
  }
  
  # TIER 1: Core Infrastructure
  vpc_id = aws_vpc.secondary.id
  
  load_balancers_config = {
    nlb = {
      internet_facing = true
      subnets         = aws_subnet.secondary_public[*].id
      security_groups = [aws_security_group.allow_my_ip_secondary.id]
    }
  }

  # TIER 2: Optional Configuration
  route53_hosted_zone_name = var.route53_public_hosted_zone_name
  certificate_arn          = aws_acm_certificate_validation.ddc.certificate_arn

  # TIER 3: Advanced Configuration
  is_primary_region = false
  create_private_dns_records = false
  create_bearer_token = false

  ddc_application_config = {
    namespaces = {
      "civ" = { description = "The Civilization series" }
    }
    bearer_token_secret_arn = module.unreal_cloud_ddc_primary.bearer_token_secret_arn
  }

  ddc_infra_config = {
    region                 = local.secondary_region
    eks_node_group_subnets = aws_subnet.secondary_private[*].id
    
    eks_access_config = {
      mode = "private"
      private = {
        security_groups  = [aws_security_group.allow_my_ip_secondary.id]
        create_proxy_nlb = true
        proxy_dns_name   = "eks.ddc"
      }
    }
    
    scylla_config = {
      current_region = {
        replication_factor = 2
        node_count         = 2
      }
      peer_regions = {
        "us-east-1" = {
          replication_factor = 3
        }
      }
      subnets = aws_subnet.secondary_private[*].id
      enable_cross_region_replication = true
      create_seed_node = false
      existing_scylla_seed = module.unreal_cloud_ddc_primary.ddc_infra.scylla_seed
      scylla_source_region = local.primary_region
    }
  }

  ddc_app_config = {
    region                              = local.secondary_region
    ddc_replication_region_url         = module.unreal_cloud_ddc_primary.ddc_connection.endpoint_nlb
    ghcr_credentials_secret_manager_arn = var.ghcr_credentials_secret_manager_arn
  }
  
  depends_on = [module.unreal_cloud_ddc_primary]
}