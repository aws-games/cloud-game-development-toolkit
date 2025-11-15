module "unreal_cloud_ddc" {
  source = "../../.."

  # Core Infrastructure
  name           = local.name
  project_prefix = local.project_prefix
  environment    = local.environment


  # Development & Debugging
  debug = true # Enable verbose logging and debugging output for troubleshooting

  vpc_id         = aws_vpc.main.id
  certificate_arn = aws_acm_certificate.ddc.arn
  route53_hosted_zone_name = var.route53_public_hosted_zone_name

  # Load Balancer Configuration
  load_balancers_config = {
    nlb = {
      internet_facing = true
      subnets         = aws_subnet.public[*].id
    }
  }

  # Security
  allowed_external_cidrs = [local.my_ip_cidr]

  # DDC Application Configuration
  ddc_application_config = {
    enable_single_region_validation = true # Validate single-region deployment constraints (disable for production)
    ddc_namespaces = {
      "project1" = {
        description = "Main project"
      }
      "project2" = {
        description = "Secondary project"
      }
    }
  }



  # DDC Infrastructure Configuration
  ddc_infra_config = {
    region                 = local.region
    eks_node_group_subnets = aws_subnet.private[*].id

    # EKS API Access Configuration (hybrid)
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = [local.my_ip_cidr]

    # ScyllaDB Configuration
    scylla_config = {
      current_region = {
        replication_factor = 3
      }
      subnets = aws_subnet.private[*].id
    }

    # NO custom_nodepool_config specified = uses defaults:
    # custom_nodepool_config = {
    #   enabled = true                    # Always creates custom nodepool
    #   instance_categories = ["i"]       # Always targets i-family instances
    #   capacity_type = "on-demand"       # Always uses on-demand instances
    #   architecture = "amd64"            # Always uses x86_64
    #   os = "linux"                      # Always uses Linux
    # }
  }

  # GHCR Credentials
  ghcr_credentials_secret_arn = var.ghcr_credentials_secret_arn

  # Centralized Logging
  enable_centralized_logging = true
  log_retention_days         = 30

  # Tags - pass example tags to module
  tags = local.tags
}
