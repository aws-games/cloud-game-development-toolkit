locals {
  project_prefix = "cgd"
  environment    = "dev"

  # Regions configuration
  regions          = var.regions
  primary_region   = var.regions[0]
  secondary_region = length(var.regions) > 1 ? var.regions[1] : null
  is_multi_region  = length(var.regions) > 1

  # Kubernetes version
  kubernetes_version = "1.31"

  # Common configuration
  unreal_cloud_ddc_version        = "1.2.0"
  scylla_instance_type            = "i4i.xlarge"


  # Network access
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"

  # VPC Configuration
  vpc_cidr             = "10.0.0.0/16"
  azs                  = ["${local.primary_region}a", "${local.primary_region}b", "${local.primary_region}c"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  # Regional DNS endpoints (following design standards)
  ddc_subdomain = "ddc"

  # Fully Qualified Domain Names with regional prefix
  ddc_fully_qualified_domain_name = "${local.primary_region}.${local.ddc_subdomain}.${var.route53_public_hosted_zone_name}"

  # Common tags
  tags = {
    ProjectPrefix = local.project_prefix
    Environment   = local.environment
    IaC           = "Terraform"
    ModuleBy      = "CGD-Toolkit"
  }
}
