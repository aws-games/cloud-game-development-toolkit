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
      security_groups = [aws_security_group.allow_my_ip.id]
    }
  }

  # TIER 2: Optional Configuration
  service_subnets          = aws_subnet.private_subnets[*].id
  route53_hosted_zone_name = var.route53_public_hosted_zone_name
  certificate_arn          = aws_acm_certificate.ddc.arn
  allowed_external_cidrs   = ["${chomp(data.http.my_ip.response_body)}/32"]

  centralized_logging = {
    infrastructure = {
      nlb = { retention_days = 90 }
      eks = { retention_days = 90 }
    }
    application = {
      ddc = { retention_days = 30 }
    }
    service = {
      scylla = { retention_days = 60 }
    }
  }

  # TIER 3: Advanced Configuration
  ddc_application_config = {
    namespaces = {
      "civ" = {
        description = "The Civilization series"
        prevent_deletion = true
      }
      "dev-sandbox" = {
        description = "Development testing"
        deletion_policy = "delete"
      }
    }
  }

  ddc_infra_config = {
    region                 = local.region
    eks_node_group_subnets = aws_subnet.private_subnets[*].id
    
    eks_access_config = {
      mode = "hybrid"
      public = {
        allowed_cidrs = ["${chomp(data.http.my_ip.response_body)}/32"]
      }
      private = {
        security_groups  = [aws_security_group.allow_my_ip.id]
        create_proxy_nlb = true
        proxy_dns_name   = "eks.ddc"
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