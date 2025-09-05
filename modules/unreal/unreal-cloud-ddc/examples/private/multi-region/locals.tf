locals {
  project_prefix = "cgd"
  environment    = "dev"
  
  # Multi-region configuration - extensible for additional regions
  regions = {
    "us-east-1" = {
      type = "primary"
      vpc_cidr = "10.0.0.0/16"
      azs = ["us-east-1a", "us-east-1b", "us-east-1c"]
      public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
      private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
    }
    "us-west-1" = {
      type = "secondary"
      vpc_cidr = "10.1.0.0/16"
      azs = ["us-west-1a", "us-west-1b", "us-west-1c"]
      public_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
      private_subnet_cidrs = ["10.1.4.0/24", "10.1.5.0/24", "10.1.6.0/24"]
    }
    # Future regions can be added here with type = "additional"
  }
  
  # Derive primary and secondary regions from configuration
  primary_region = [for region, config in local.regions : region if config.type == "primary"][0]
  secondary_region = [for region, config in local.regions : region if config.type == "secondary"][0]
  
  # Kubernetes version - ensure consistency across regions
  kubernetes_version = "1.33"
  
  # Common configuration
  unreal_cloud_ddc_version = "1.2.0"
  scylla_instance_type = "i4i.xlarge"
  
  # Network access
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
  

  
  # DDC Domain
  ddc_subdomain = "ddc"
  primary_ddc_fully_qualified_domain_name = "${local.primary_region}.${local.environment}.${local.ddc_subdomain}.${var.route53_public_hosted_zone_name}"
  secondary_ddc_fully_qualified_domain_name = "${local.secondary_region}.${local.environment}.${local.ddc_subdomain}.${var.route53_public_hosted_zone_name}"
  
  # Common tags
  tags = {
    Environment = local.environment
    Project     = local.project_prefix
    ManagedBy   = "Terraform"
  }
}