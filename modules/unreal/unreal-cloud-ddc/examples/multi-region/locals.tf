locals {
  project_prefix = "cgd"
  environment    = "dev"
  
  # Regions
  primary_region = "us-east-1"
  secondary_region = "us-west-1"
  
  # Kubernetes version - ensure consistency across regions
  kubernetes_version = "1.33"
  
  # Common configuration
  unreal_cloud_ddc_version = "1.2.0"
  scylla_instance_type = "i4i.xlarge"
  
  # Network access
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
  
  # VPC Configuration
  vpc_cidr = "10.0.0.0/16"
  azs_primary = ["us-east-1a", "us-east-1b", "us-east-1c"]
  azs_secondary = ["us-west-1a", "us-west-1b", "us-west-1c"]
  
  # Primary region subnets
  public_subnet_cidrs_primary = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs_primary = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  
  # Secondary region subnets
  public_subnet_cidrs_secondary = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  private_subnet_cidrs_secondary = ["10.1.4.0/24", "10.1.5.0/24", "10.1.6.0/24"]
  
  # DDC Domain
  ddc_subdomain = "ddc"
  ddc_fully_qualified_domain_name = "${local.primary_region}.${local.ddc_subdomain}.${var.route53_public_hosted_zone_name}"
  
  # Common tags
  tags = {
    Environment = local.environment
    Project     = local.project_prefix
    ManagedBy   = "Terraform"
  }
}