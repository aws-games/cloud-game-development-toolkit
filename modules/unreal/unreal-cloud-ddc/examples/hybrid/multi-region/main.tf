# Multi-region DDC deployment

# CRITICAL: Shared configuration must be identical across ALL regions
locals {
  # DDC logical namespaces - MUST be identical across regions (case-sensitive)
  shared_ddc_namespaces = {
    "project1" = { description = "Main project" }
    "project2" = { description = "Secondary project" }
  }
  
  # Compute configuration - consistent performance across regions
  shared_compute_config = {
    instance_type    = "i4i.xlarge"
    cpu_requests     = "2000m"
    memory_requests  = "8Gi"
    replica_count    = 2
  }
}

# Primary Region (us-east-1)
module "unreal_cloud_ddc_primary" {
  source = "../../.."
  region = local.primary_region

  # No providers needed - using local-exec with Helm CLI

  # Core Infrastructure
  project_prefix = local.project_prefix
  vpc_id         = aws_vpc.primary.id
  certificate_arn = aws_acm_certificate_validation.ddc_primary.certificate_arn
  route53_hosted_zone_name = var.route53_public_hosted_zone_name

  # Load Balancer Configuration
  load_balancers_config = {
    nlb = {
      internet_facing = true
      subnets         = aws_subnet.primary_public[*].id
    }
  }

  # Security
  allowed_external_cidrs = [local.my_ip_cidr]

  # Multi-region Configuration
  is_primary_region = true
  create_bearer_token = true
  bearer_token_replica_regions = [local.secondary_region]

  # DDC Application Configuration (using shared locals)
  ddc_application_config = {
    ddc_namespaces = local.shared_ddc_namespaces  # CRITICAL: DDC logical namespaces must be identical across regions
    
    # Compute configuration (consistent performance)
    instance_type    = local.shared_compute_config.instance_type
    cpu_requests     = local.shared_compute_config.cpu_requests
    memory_requests  = local.shared_compute_config.memory_requests
    replica_count    = local.shared_compute_config.replica_count
    
    # Multi-region testing configuration (PRIMARY REGION)
    enable_single_region_validation = true   # Test this region
    enable_multi_region_validation = false   # Skip multi-region tests (secondary region not ready yet)
    peer_region_ddc_endpoint = "https://${local.secondary_ddc_fully_qualified_domain_name}"  # Secondary endpoint for testing
  }

  # DDC Infrastructure Configuration
  ddc_infra_config = {
    region                 = local.primary_region
    eks_node_group_subnets = aws_subnet.primary_private[*].id

    # EKS API Access Configuration (hybrid)
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = [local.my_ip_cidr]

    # ScyllaDB Configuration
    scylla_config = {
      current_region = {
        datacenter_name    = local.primary_region
        replication_factor = 3
      }
      peer_regions = {
        (local.secondary_region) = {
          datacenter_name    = local.secondary_region
          replication_factor = 2
        }
      }
      enable_cross_region_replication = true
      subnets = aws_subnet.primary_private[*].id
    }
  }

  # GHCR Credentials
  ghcr_credentials_secret_arn = var.ghcr_credentials_secret_arn

  # Centralized Logging
  enable_centralized_logging = true
  log_retention_days         = 30
  
  # Tags - pass example tags to module
  tags = local.tags
}

# Secondary Region (us-west-1)
module "unreal_cloud_ddc_secondary" {
  source = "../../.."
  region = local.secondary_region

  # No providers needed - using local-exec with Helm CLI

  # Core Infrastructure
  project_prefix = local.project_prefix
  vpc_id         = aws_vpc.secondary.id
  certificate_arn = aws_acm_certificate_validation.ddc_secondary.certificate_arn
  route53_hosted_zone_name = var.route53_public_hosted_zone_name

  # Load Balancer Configuration
  load_balancers_config = {
    nlb = {
      internet_facing = true
      subnets         = aws_subnet.secondary_public[*].id
    }
  }

  # Security
  allowed_external_cidrs = [local.my_ip_cidr]

  # Multi-region Configuration
  is_primary_region = false  # Secondary region - use shared IAM roles from primary
  create_private_dns_records = false
  create_bearer_token = false  # Use replicated token from primary
  
  # Existing IAM Role ARNs from Primary Region
  existing_iam_role_arns = {
    external_dns_role_arn                    = module.unreal_cloud_ddc_primary.iam_roles.external_dns_role_arn
    aws_load_balancer_controller_role_arn    = module.unreal_cloud_ddc_primary.iam_roles.aws_load_balancer_controller_role_arn
    cert_manager_role_arn                    = module.unreal_cloud_ddc_primary.iam_roles.cert_manager_role_arn
    oidc_provider_arn                        = module.unreal_cloud_ddc_primary.iam_roles.oidc_provider_arn
    codebuild_role_arn                       = module.unreal_cloud_ddc_primary.iam_roles.codebuild_role_arn
  }

  # DDC Application Configuration (using shared locals)
  ddc_application_config = {
    ddc_namespaces = local.shared_ddc_namespaces  # CRITICAL: DDC logical namespaces must match primary exactly
    
    # Compute configuration (consistent performance across regions)
    instance_type    = local.shared_compute_config.instance_type
    cpu_requests     = local.shared_compute_config.cpu_requests
    memory_requests  = local.shared_compute_config.memory_requests
    replica_count    = local.shared_compute_config.replica_count
    
    # Use shared bearer token from primary (replicated to this region)
    bearer_token_secret_name = module.unreal_cloud_ddc_primary.bearer_token_secret_name
    
    # Multi-region testing configuration (SECONDARY REGION)
    enable_single_region_validation = false  # Skip single-region tests (comprehensive multi-region test includes local validation)
    enable_multi_region_validation = true    # Test cross-region replication (both regions available now)
    peer_region_ddc_endpoint = "https://${local.primary_ddc_fully_qualified_domain_name}"  # Primary region endpoint
  }

  # DDC Infrastructure Configuration
  ddc_infra_config = {
    region                 = local.secondary_region
    eks_node_group_subnets = aws_subnet.secondary_private[*].id

    # EKS API Access Configuration (hybrid)
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = [local.my_ip_cidr]

    # ScyllaDB Configuration
    scylla_config = {
      current_region = {
        datacenter_name    = local.secondary_region
        replication_factor = 2
      }
      peer_regions = {
        (local.primary_region) = {
          datacenter_name    = local.primary_region
          replication_factor = 3
        }
      }
      enable_cross_region_replication = true
      create_seed_node = false
      existing_scylla_seed = module.unreal_cloud_ddc_primary.ddc_infra.scylla_seed
      scylla_source_region = local.primary_region
      subnets = aws_subnet.secondary_private[*].id
    }
  }

  # GHCR Credentials
  ghcr_credentials_secret_arn = var.ghcr_credentials_secret_arn

  # Centralized Logging - enabled in both regions
  enable_centralized_logging = true
  log_retention_days         = 30
  
  # Tags - pass example tags to module
  tags = local.tags

  depends_on = [module.unreal_cloud_ddc_primary]
}
